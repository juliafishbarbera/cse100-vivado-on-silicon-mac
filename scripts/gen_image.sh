#!/bin/zsh

# Generate the Docker image

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/header.sh"
validate_macos

start_docker || exit 1

if docker image inspect "$container_image" > /dev/null 2>&1 && [[ "${1:-}" != "--rebuild" ]]; then
    f_echo "The Vivado support image is already available."
    exit 0
fi

# Build the Docker image according to the Dockerfile
f_echo "Building Docker image..."
if ! docker build --platform linux/amd64 -t "$container_image" "$script_dir"
then
	f_echo "Docker image generation failed!"
	exit 1
fi

f_echo "The Docker image was successfully generated."
