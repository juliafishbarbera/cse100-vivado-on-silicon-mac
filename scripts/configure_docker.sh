#!/bin/zsh

# Checks Docker without changing global Docker Desktop settings.

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/header.sh"
validate_macos

if ! start_docker; then
    exit 1
fi

if docker image inspect "$container_image" > /dev/null 2>&1; then
    if docker run --rm --platform linux/amd64 "$container_image" /bin/true > /dev/null 2>&1; then
        f_echo "Docker can run amd64 Linux containers."
        exit 0
    fi
    f_echo "Docker could not run the local amd64 image."
    f_echo "Enable Rosetta for x86/amd64 emulation in Docker Desktop settings."
    exit 1
else
    f_echo "Docker is ready. amd64 execution will be verified while building the image."
fi

f_echo "If the build fails, enable Rosetta for x86/amd64 emulation in Docker Desktop settings."
