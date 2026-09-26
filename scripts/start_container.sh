#!/bin/zsh

# Starts Vivado and, when requested, USB forwarding.

script_dir=$(dirname -- "$(readlink -nf "$0")")
source "$script_dir/header.sh"
validate_macos

enable_usb=0
if [[ "${1:-}" == "--usb" ]]; then
    enable_usb=1
elif [[ -n "${1:-}" ]]; then
    f_echo "Usage: $0 [--usb]"
    exit 2
fi

container_started=0
xvcd_pid=""
function stop_container {
    if (( container_started )); then
        docker kill "$container_name" > /dev/null 2>&1 || true
    fi
    if [[ -n "$xvcd_pid" ]]; then
        kill "$xvcd_pid" > /dev/null 2>&1 || true
    fi
}
trap stop_container EXIT
trap 'exit 130' INT TERM HUP

start_docker || exit 1

if ! docker image inspect "$container_image" > /dev/null 2>&1; then
    f_echo "The support image is missing. Run './vivado install' first."
    exit 1
fi

if [[ -z "$(find "$script_dir/../Xilinx/Vivado" -path '*/bin/vivado' -type f -print -quit 2>/dev/null)" ]]; then
    f_echo "Vivado is not installed. Run './vivado install' first."
    exit 1
fi

if docker container inspect "$container_name" > /dev/null 2>&1; then
    f_echo "A Vivado container is already running."
    exit 1
fi

docker_env=()
if (( enable_usb )); then
    if [[ ! -x "$script_dir/xvcd/bin/xvcd" ]]; then
        f_echo "USB forwarding is unavailable: the xvcd helper is missing."
        exit 1
    fi
    if xattr -p com.apple.quarantine "$script_dir/xvcd/bin/xvcd" > /dev/null 2>&1; then
        if ! xattr -d com.apple.quarantine "$script_dir/xvcd/bin/xvcd"; then
            f_echo "USB forwarding is unavailable because macOS quarantined the helper."
            exit 1
        fi
    fi
    docker_env=(-e ENABLE_XVC=1)
fi

docker run --init --rm --name "$container_name" \
    --mount "type=bind,source=$script_dir/..,target=/home/user" \
    -p 127.0.0.1:5901:5901 \
    --platform linux/amd64 \
    "${docker_env[@]}" \
    "$container_image" sudo -H -u user bash /home/user/scripts/linux_start.sh &
container_started=1

f_echo "Waiting for the Vivado desktop..."
ready=0
for _ in {1..45}; do
    if nc -z 127.0.0.1 5901 > /dev/null 2>&1; then
        ready=1
        break
    fi
    if ! docker container inspect "$container_name" > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

if (( ! ready )); then
    f_echo "The Vivado desktop did not become ready."
    docker logs "$container_name" 2>&1 | tail -n 20
    exit 1
fi

vncpass=$(tr -d "\n\r\t " < "$script_dir/vncpasswd")
open "vnc://user:$vncpass@localhost:5901"
f_echo "Vivado is starting in Screen Sharing."

if (( enable_usb )); then
    "$script_dir/xvcd/bin/xvcd" > /dev/null 2>&1 &
    xvcd_pid=$!
    f_echo "USB forwarding is enabled."
fi

while docker container inspect "$container_name" > /dev/null 2>&1; do
    if [[ -n "$xvcd_pid" ]] && ! kill -0 "$xvcd_pid" > /dev/null 2>&1; then
        f_echo "USB forwarding stopped unexpectedly."
        xvcd_pid=""
    fi
    sleep 2
done
container_started=0
