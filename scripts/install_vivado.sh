#!/bin/bash

# Runs inside the container and installs Vivado in batch mode.

set -o pipefail
script_dir=$(dirname -- "$(readlink -nf "$0")")
source "$script_dir/header.sh"
validate_linux

install_bin_path="${INSTALLER_PATH:-/opt/vivado-installer.bin}"
vivado_version="${VIVADO_VERSION:-}"

if [[ ! -f "$install_bin_path" ]]; then
    f_echo "The Vivado installer is not mounted in the container."
    exit 1
fi

if [[ -z "$vivado_version" ]]; then
    file_hash=$(md5sum "$install_bin_path" | awk '{print $1}')
    if ! set_vivado_version_from_hash "$file_hash"; then
        f_echo "The Vivado installer is not recognized."
        exit 1
    fi
fi

install_config="/home/user/scripts/install_configs/${vivado_version}.txt"
if [[ ! -f "$install_config" ]]; then
    f_echo "Missing installation configuration: $install_config"
    exit 1
fi

if [[ ! -x /home/user/installer/xsetup ]]; then
    f_echo "Extracting installer..."
    mkdir -p /home/user/installer
    if ! bash "$install_bin_path" --target /home/user/installer --noexec; then
        f_echo "Installer extraction failed."
        exit 1
    fi
else
    f_echo "Using the previously extracted installer."
fi

f_echo "Log in to your AMD/Xilinx account to authorize the download."
until /home/user/installer/xsetup -b AuthTokenGen; do
    f_echo "Login was unsuccessful. Please try again."
done

eula_args="XilinxEULA,3rdPartyEULA"
if [[ "$vivado_version" == "202110" ]]; then
    eula_args="${eula_args},WebTalkTerms"
fi

f_echo "Installing Vivado..."
if ! /home/user/installer/xsetup -c "$install_config" -b Install -a "$eula_args"; then
    f_echo "Installation stopped. Re-run './vivado install' to retry with the extracted installer."
    exit 1
fi

f_echo "Installing Basys 3 board files..."
archive=/home/user/digilent-board-files.zip
board_ref=36f34ab687b7fa9c778b779d027f3bce63b3ace9
board_sha256=4ddb7bc0351522763b2958a0412dac37f9b6f28a5fd6cb513f71e85d4808b745
board_dir="/home/user/vivado-boards-$board_ref"
if curl --fail --location --retry 3 \
    --output "$archive" \
    "https://github.com/Digilent/vivado-boards/archive/${board_ref}.zip" && \
    echo "$board_sha256  $archive" | sha256sum --check --status; then
    rm -rf "$board_dir"
    unzip -q "$archive" -d /home/user
    vivado_dir=$(find /home/user/Xilinx/Vivado -mindepth 1 -maxdepth 1 -type d -print -quit)
    mkdir -p "$vivado_dir/data/boards/board_files"
    cp -R "$board_dir/new/board_files/." "$vivado_dir/data/boards/board_files/"
    rm -f "$archive"
    rm -rf "$board_dir"
    f_echo "Basys 3 board files installed."
else
    rm -f "$archive"
    f_echo "Vivado is installed, but verified board files could not be downloaded. You can retry later."
fi

printf '%s\n' "$vivado_version" > /home/user/.vivado-version
f_echo "Installation complete. Run './vivado start' on the Mac."
