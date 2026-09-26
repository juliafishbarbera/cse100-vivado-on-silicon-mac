#!/bin/zsh

# Initial setup on the macOS host. The friendly entry point is:
# ./vivado install [installer.bin]

script_dir=$(dirname -- "$(readlink -nf "$0")")
source "$script_dir/header.sh"
validate_macos

if [[ "$current_user" == "root" ]]; then
    f_echo "Do not execute this script as root."
    exit 1
fi

parent_dir=$(dirname "$script_dir")
installation_binary="${1:-}"

installed_vivado=("$parent_dir"/Xilinx/Vivado/*/bin/vivado(N))
if [[ -f "$parent_dir/.vivado-version" ]] && (( ${#installed_vivado[@]} > 0 )); then
    f_echo "Vivado is already installed. Run './vivado start' to launch it."
    exit 0
fi

if [[ -z "$installation_binary" ]]; then
    installers=("$parent_dir"/*.bin(N))
    if (( ${#installers[@]} == 1 )); then
        installation_binary="${installers[1]}"
        f_echo "Found installer: ${installation_binary:t}"
    fi
fi

while true; do
    if [[ -z "$installation_binary" ]]; then
        f_echo "Drag the Linux Self Extracting Web Installer here, then press Enter:"
        if ! read installation_binary; then
            f_echo "No installer was provided."
            exit 1
        fi
    fi

    installation_binary="${installation_binary:A}"
    if [[ ! -f "$installation_binary" ]]; then
        f_echo "That installer file does not exist."
        installation_binary=""
        continue
    fi

    file_hash=$(md5 -q "$installation_binary")
    if ! set_vivado_version_from_hash "$file_hash"; then
        f_echo "That installer is not recognized. Supported versions are:"
        print_supported_versions
        installation_binary=""
        continue
    fi

    install_config="$script_dir/install_configs/${vivado_version}.txt"
    if [[ ! -f "$install_config" ]]; then
        f_echo "The installer was recognized, but its installation configuration is missing."
        exit 1
    fi
    break
done

version_label=$(vivado_version_label "$vivado_version")
f_echo "Detected Vivado $version_label."

validate_internet

available_kb=$(df -Pk "$parent_dir" | awk 'NR==2 {print $4}')
available_gb=$(( available_kb / 1024 / 1024 ))
if (( available_gb < 40 )); then
    f_echo "Warning: only about ${available_gb} GiB is free; installation may require 40–50 GiB."
fi

f_echo "Continuing means that you agree to AMD/Xilinx and third-party EULAs."
if [[ "$vivado_version" == "202110" ]]; then
    f_echo "Vivado 2021.1 also requires acceptance of its WebTalk terms."
fi
f_echo "Rosetta installation, if needed, requires acceptance of Apple's license."
f_echo "Proceed [Y/n]?"
if ! read user_consent; then
    f_echo "Setup requires explicit confirmation."
    exit 1
fi
case "$user_consent" in
    ""|[yY]|[yY][eE][sS]) ;;
    [nN]|[nN][oO]) f_echo "Setup cancelled."; exit 1 ;;
    *) f_echo "Please answer yes or no."; exit 1 ;;
esac

if [[ "$(uname -m)" != "x86_64" ]]; then
    if arch -arch x86_64 /usr/bin/true > /dev/null 2>&1; then
        f_echo "Rosetta is installed."
    else
        f_echo "Installing Rosetta..."
        softwareupdate --install-rosetta --agree-to-license || exit 1
    fi
fi

"$script_dir/configure_docker.sh" || exit 1

image_args=()
if [[ "${VIVADO_REBUILD_IMAGE:-0}" == "1" ]]; then
    image_args=(--rebuild)
fi
"$script_dir/gen_image.sh" "${image_args[@]}" || exit 1

if [[ ! -f "$script_dir/vnc_resolution" ]]; then
    echo "$vnc_default_resolution" > "$script_dir/vnc_resolution"
fi

mkdir -p "$parent_dir/.config/autostart" "$parent_dir/Desktop"
cp "$script_dir/de_start.desktop" "$parent_dir/.config/autostart/de_start.desktop"

f_echo "Starting the Vivado installer. This can take one to two hours."
docker run --init -it --rm \
    --name "$container_name" \
    --mount "type=bind,source=$parent_dir,target=/home/user" \
    --mount "type=bind,source=$installation_binary,target=/opt/vivado-installer.bin,readonly" \
    --platform linux/amd64 \
    -e INSTALLER_PATH=/opt/vivado-installer.bin \
    -e VIVADO_VERSION="$vivado_version" \
    "$container_image" sudo -H -u user bash /home/user/scripts/install_vivado.sh
