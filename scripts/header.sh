# general functions and definitions used by the other scripts

# This script needs to be sourced into other scripts or
# be run explicitly with an interpreter since it has no shebang

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/hashes.sh"

container_image="vivado-on-silicon:ubuntu22.04"
container_name="vivado-on-silicon"

# echo with color
function f_echo {
	echo -e "\e[1m\e[33m$1\e[0m"
}

# aborts the script if it isn't run on macOS
function validate_macos {
    if [[ $(uname) == *Darwin* ]]
    then
        :
    else
        f_echo "Make sure to run this script on macOS."
        exit 1
    fi
}

# aborts the script if it isn't run inside the Docker container
function validate_linux {
    if [[ $(uname) == *Linux* ]]
    then
        :
    else
        f_echo "Make sure to run this script on Linux."
        exit 1
    fi
}

function validate_internet {
    if ! curl --silent --head --fail --max-time 10 https://github.com/ > /dev/null
    then
        f_echo "Internet connection required."
        exit 1
    fi
}

function wait_for_user_input {
    f_echo "Press Enter to continue..."
    read
}

function start_docker {
    # check if Docker is installed
    if ! command -v docker &> /dev/null
    then
        f_echo "You need to install Docker Desktop first."
        exit 1
    fi

    # Launch Docker daemon
    f_echo "Launching Docker daemon..."
    if docker info &> /dev/null; then
        return 0
    fi

    open -a Docker
    for _ in {1..24}; do
        if docker info &> /dev/null; then
            return 0
        fi
        sleep 5
    done

    f_echo "Docker did not become ready within two minutes."
    return 1
}

vivado_version=""

function set_vivado_version_from_hash {
    if [[ -n "${web_hashes[$1]:-}" ]]
    then
        vivado_version=${web_hashes[$1]}
    elif [[ -n "${sfd_hashes[$1]:-}" ]]
    then
        vivado_version=${sfd_hashes[$1]}
    else
        return 1
    fi
    return 0
}

function vivado_version_label {
    echo "${version_labels[$1]:-$1}"
}

function print_supported_versions {
    local code
    for code in "${supported_version_codes[@]}"; do
        printf '%s ' "${version_labels[$code]}"
    done
    echo
}

# The actual resolution is stored in the file vnc_resolution
vnc_default_resolution="1920x1080"

current_user=$(whoami)
