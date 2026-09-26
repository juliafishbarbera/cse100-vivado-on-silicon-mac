# Vivado on Apple Silicon Mac

This project runs the Linux version of AMD Vivado in an x86-64 Docker container on Apple Silicon. Rosetta accelerates the container, TigerVNC provides the desktop, and the built-in macOS Screen Sharing app displays it.

This project is not associated with AMD or Xilinx.

## Supported Vivado versions

- 2021.1
- 2022.2
- 2023.1
- 2023.2
- 2024.1
- 2025.2

The Linux **Self Extracting Web Installer** is required. The full offline installer has not been tested.

The project has been tested on macOS 15. Rosetta behavior in macOS 14, including 14.5, has caused Vivado failures and remains unsupported.

## Install

You need:

- an Apple Silicon Mac with Rosetta;
- Docker Desktop for Apple Silicon;
- approximately 50 GiB of free disk space;
- a supported Vivado Linux web installer.

Download and extract this project, open Terminal in its folder, and run:

```sh
./vivado doctor
./vivado install /path/to/FPGAs_AdaptiveSoCs_Unified_Installer.bin
```

The installer may be anywhere on the Mac. You can also put one `.bin` installer in the project folder and run `./vivado install`; it will be selected automatically.

Setup checks the installer before doing expensive work. It builds the Linux support image, asks you to log in to AMD/Xilinx, installs Vivado, and adds Basys 3 board files. Expect the AMD download and installation to take one to two hours.

The supplied configurations install only Artix-7 device support, which is sufficient for the Basys 3 and avoids downloading unrelated device families.
The Digilent board definitions are pinned to a known revision and checksum so repeated installations use the same files.

If installation is interrupted, run the same command again. The extracted installer is reused when possible.

## Start Vivado

```sh
./vivado start
```

Screen Sharing opens after the container's VNC server is ready. Stop Vivado by logging out of the Linux desktop or pressing `Control-C` in Terminal.

Files in this project folder appear at `/home/user` inside Vivado. Store projects in a subfolder such as `workspace/` or `labs/`.

The default desktop resolution is `1920x1080`. To change it, edit `scripts/vnc_resolution` using the format `WIDTHxHEIGHT` before starting Vivado.

## Optional USB forwarding

Start with USB forwarding only when programming a compatible FT2232C-based board:

```sh
./vivado start --usb
```

USB forwarding uses the bundled `xvcd` server and Xilinx Virtual Cable. It is intentionally disabled by default because the helper supports only a limited set of boards.

## Maintenance and troubleshooting

Check the environment at any time:

```sh
./vivado doctor
```

Rebuild the support image after changing the Dockerfile:

```sh
./vivado build-image --rebuild
```

Remove the installed Vivado files and generated Linux home-directory files:

```sh
./vivado clean
```

Cleaning does not remove the downloaded Vivado installer or ordinary project folders.

Common problems:

- If Docker is installed but not running, launch Docker Desktop and repeat the command.
- If the amd64 image cannot run, enable Rosetta/x86-64 emulation in Docker Desktop settings.
- If Vivado exits during synthesis, give Docker more memory and swap.
- On external drives, use a filesystem that supports Unix permissions. FAT32, exFAT, and NTFS can cause installation failures.
- Run `./vivado doctor` to detect missing configuration, low disk space, or a conflicting VNC port.

The older script entry points under `scripts/` remain available, but the top-level `vivado` command is the supported interface.

## How it works

The support image is based on Ubuntu 22.04 for `linux/amd64`. Vivado is installed into the project folder so it persists when the temporary container stops. Only VNC port 5901 is published, and it is bound to the Mac's loopback interface.

Version checksums and labels live in `scripts/hashes.sh`. Every listed version must have a corresponding file under `scripts/install_configs/`; `scripts/check.sh` and the repository workflow verify this automatically.

## License and trademarks

The repository is licensed under the Creative Commons Zero v1.0 Universal license. Running setup requires acceptance of applicable AMD/Xilinx, third-party, and Apple license agreements. Vivado 2021.1 additionally requires its WebTalk terms.

This repository contains modified source and a compiled copy of [xvcd](https://github.com/tmbinc/xvcd), along with software associated with libusb and libftdi licensing. See the included license files for details.

Vivado and Xilinx are trademarks of Xilinx, Inc. AMD, Arm, Apple, Docker, Intel, Linux, and other names are trademarks of their respective owners.
