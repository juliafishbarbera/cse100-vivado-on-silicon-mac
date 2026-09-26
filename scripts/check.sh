#!/bin/bash

set -euo pipefail
script_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
project_dir=$(dirname "$script_dir")
source "$script_dir/hashes.sh"

declare -A known_codes=()
for code in "${supported_version_codes[@]}"; do
    known_codes[$code]=1
    config="$script_dir/install_configs/${code}.txt"
    if [[ ! -f "$config" ]]; then
        echo "Missing installation configuration for ${version_labels[$code]}" >&2
        exit 1
    fi
    if ! grep -F -- "- ${version_labels[$code]}" "$project_dir/README.md" > /dev/null; then
        echo "README does not list supported version ${version_labels[$code]}" >&2
        exit 1
    fi

    modules=$(grep '^Modules=' "$config")
    if [[ "$modules" != *"Artix-7:1"* ]]; then
        echo "Artix-7 support is not enabled for ${version_labels[$code]}" >&2
        exit 1
    fi
    IFS=',' read -r -a module_entries <<< "${modules#Modules=}"
    for module in "${module_entries[@]}"; do
        if [[ "$module" == *:1 && "$module" != "Artix-7:1" ]]; then
            echo "Unexpected device family enabled for ${version_labels[$code]}: $module" >&2
            exit 1
        fi
    done
done

for code in "${web_hashes[@]}" "${sfd_hashes[@]}"; do
    if [[ -z "${known_codes[$code]:-}" ]]; then
        echo "Installer hash references unknown version code: $code" >&2
        exit 1
    fi
done

for file in "$project_dir/vivado" \
    "$script_dir/setup.sh" \
    "$script_dir/start_container.sh" \
    "$script_dir/configure_docker.sh" \
    "$script_dir/gen_image.sh" \
    "$script_dir/cleanup.sh"; do
    zsh -n "$file"
done

if [[ ! -x "$project_dir/vivado" ]]; then
    echo "The top-level vivado launcher is not executable" >&2
    exit 1
fi

for file in "$script_dir/install_vivado.sh" \
    "$script_dir/linux_start.sh" \
    "$script_dir/de_start.sh"; do
    bash -n "$file"
done

echo "Version metadata and script syntax are valid."
