#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/provision_handler/envroot.sh
# Created 2/9/26 - 8:15 AM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs

# Sourcing base file
. "${cli_scripts_dir_abs}/base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
function install_envroot() {
    local dir compression dest_tar download_url host_platform platform host_arch arch opt_dir envroot_version
    local -a root_tree

    echo -e "We need to briefly run as root (through sudo) to execute some commands."
    echo -e "If prompted, please enter your user password."
    sudo -v

    host_platform="$(uname -s)"
    if [[ "${host_platform}" == "Darwin" ]]; then
        platform="macos"
    elif [[ "${host_platform}" == "Linux" ]]; then
        platform="linux"
    else
        echo_error "Unsupported platform: ${host_platform}" "errexit"
    fi

    host_arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
    if [[ "${host_arch}" == "x86_64" || "${host_arch}" == "amd64" ]]; then
        arch="x86_64"
    elif [[ "${host_arch}" == "arm64" || "${host_arch}" == "aarch64" ]]; then
        arch="arm64"
    else
        echo_error "Unsupported architecture: ${host_arch}" "errexit"
    fi

    opt_dir="/opt/${cli_name}"
    envroot_version="1.0.0"
    download_url="https://github.com/64rl0/Envroot/archive/refs/tags/v${envroot_version}.tar.gz"
    dest_tar="${opt_dir}/Envroot/Envroot-v${envroot_version}.tar.gz"

    # Create icarus opt dir
    sudo mkdir -p "${opt_dir}" || {
        echo_error "Failed to create '${opt_dir}'." "errexit"
    }
    sudo chown -R "${USER}" "${opt_dir}" || {
        sudo rm -rf "${opt_dir}"
        echo_error "Failed to change ownership of '${opt_dir}'." "errexit"
    }

    # Create icarus opt dir tree
    root_tree=(
        "${opt_dir}/bin"
        "${opt_dir}/sbin"
        "${opt_dir}/include"
        "${opt_dir}/lib"
        "${opt_dir}/private"
        "${opt_dir}/share"
    )
    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'." "errexit"
        }
    done

    # Create Envroot dir
    rm -rf "${opt_dir}/Envroot" || {
        echo_error "Failed to remove '${opt_dir}/Envroot'." "errexit"
    }
    mkdir -p "${opt_dir}/Envroot" || {
        echo_error "Failed to create '${opt_dir}/Envroot'." "errexit"
    }

    echo
    echo -e "${bold_green}${sparkles} Installing 'Envroot'${end}"
    curl -L "${download_url}" -o "${dest_tar}" || {
        echo_error "Failed to download 'Envroot'." "errexit"
    }
    echo
    compression="$(file "${dest_tar}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')" || {
        echo_error "Failed to detect '${dest_tar}' compression type." "errexit"
    }
    tar -v -x --"${compression}" -f "${dest_tar}" -C "${opt_dir}/Envroot" || {
        echo_error "Failed to unpack 'Envroot'." "errexit"
    }
    rm -rf "${dest_tar}" || {
        echo_error "Failed to remove '${dest_tar}'." "errexit"
    }

    ln -f -s -n "${opt_dir}/Envroot/Envroot-${envroot_version}/libexec/envroot/${platform}/${arch}/envroot" "${opt_dir}/bin/envroot" || {
        echo_error "Failed to create '${opt_dir}/bin/envroot' symlink." "errexit"
    }

    echo -e "done!"
    echo
}

install_envroot "$@"
