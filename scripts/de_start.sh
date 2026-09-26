#!/bin/bash

# This script is run whenever the desktop environment has started.
# (with normal user privileges).

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/header.sh"
validate_linux

export LD_PRELOAD="/lib/x86_64-linux-gnu/libudev.so.1 /lib/x86_64-linux-gnu/libselinux.so.1 /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0"

# if Vivado is installed
vivado_dir=$(find /home/user/Xilinx/Vivado -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [[ -n "$vivado_dir" && -x "$vivado_dir/bin/vivado" ]]
then
	if [[ "${ENABLE_XVC:-0}" == "1" ]]; then
		"$vivado_dir/bin/hw_server" -e "set auto-open-servers xilinx-xvc:host.docker.internal:2542" &
	fi
	# shellcheck disable=SC1090
	source "$vivado_dir/settings64.sh"
	exec "$vivado_dir/bin/vivado"
else
	f_echo "The installation is incomplete."
	wait_for_user_input
fi
