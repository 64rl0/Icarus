#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/build_runtime.sh
# Created 3/2/24 - 8:09 AM UK Time (London) by carlogtt

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

declare -r bold_green=$'\033[1;32m'
declare -r end=$'\033[0m'
declare -r sparkles="\xE2\x9C\xA8"

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
project_root_dir_abs="$(realpath -- "${script_dir_abs}/..")"
declare -r project_root_dir_abs

function build_runtime() {
    local platform_id venv_name python_full_version_for_venv download_url pybin

    platform_id="$(platform_id)"

    venv_name="runtime"
    python_full_version_for_venv="3.13.11"
    download_url="https://github.com/64rl0/PythonRuntime/releases/download/cpython-${python_full_version_for_venv}-${platform_id}/cpython-${python_full_version_for_venv}-${platform_id}.tar.gz"
    pybin="${project_root_dir_abs}/${venv_name}/env/bin/python3"

    # Prep env
    echo -e "\n\n${bold_green}${sparkles} Preparing Runtime${end}"
    rm -rf "${project_root_dir_abs:?}/${venv_name}"
    mkdir -p "${project_root_dir_abs}/${venv_name}"
    echo -e "done!"

    # Download Python Runtime
    echo -e "\n\n${bold_green}${sparkles} Downloading Python${end}"
    curl -L "${download_url}" -o "${project_root_dir_abs}/${venv_name}/cpython.tar.gz"
    tar -xzf "${project_root_dir_abs}/${venv_name}/cpython.tar.gz" -C "${project_root_dir_abs}/${venv_name}"
    mv "${project_root_dir_abs}/${venv_name}/${python_full_version_for_venv}" "${project_root_dir_abs}/${venv_name}/env"
    rm -rf "${project_root_dir_abs}/${venv_name}/cpython.tar.gz"

    # Install requirements
    echo -e "\n\n${bold_green}${sparkles} Installing Requirements${end}"
    "${pybin}" -m pip install --upgrade pip
    ICARUS_PACKAGE_VERSION=$(cat "${project_root_dir_abs}/icarus.cfg" | grep 'version: ' | awk '{ print $3 }') \
        "${pybin}" -m pip install "${project_root_dir_abs}"

    # Cleanup
    rm -rf "${project_root_dir_abs}/build"
    rm -rf "${project_root_dir_abs}/src/icarus.egg-info"

    # Build complete!
    echo -e "\n\n${bold_green}${sparkles} ${venv_name} build Complete & Ready for use!${end}"
}

function platform_id() {
    # platform_id: combine OS-flavour and architecture,
    # then sanitize/normalize

    # 1) Determine architecture (lowercased)
    #    e.g. "x86_64" → "x86_64", "aarch64" or "arm64" → "arm64"
    local arch
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    # 2) Determine OS-specific "os_part"
    local uname_s os_part
    uname_s=$(uname -s)

    case "$uname_s" in
    Linux*)
        # On Linux, use /etc/os-release to get "distroVERSION"
        os_part=$(_linux_flavour)
        ;;

    Darwin*)
        # On macOS, use sw_vers to get the product version (e.g. "13.4.1")
        local version
        version=$(sw_vers -productVersion 2>/dev/null | cut -d '.' -f1 || echo "")
        [[ -z "$version" ]] && version="0"
        os_part="macos${version}"
        ;;

    CYGWIN* | MINGW* | MSYS*)
        # On Windows/Cygwin/Msys, attempt to extract "Windows NT x.x.xxxxx" from 'ver'
        # If that fails, fall back to "win0"
        local winver
        # 'cmd.exe /c ver' gives something like: "Microsoft Windows [Version 10.0.19044.2130]"
        winver=$(cmd.exe /c ver 2>/dev/null | tr -d '\r' \
            | sed -n 's/.*\[Version[[:space:]]\([0-9.]*\)\].*/\1/p')
        [[ -z "$winver" ]] && winver="0"
        os_part="win${winver}"
        ;;

    *)
        # For any other platform, just use uname -s with spaces → dashes
        os_part=$(echo "$uname_s" | sed 's/ /-/g')
        ;;
    esac

    # 3) Combine os_part and arch, lowercase, then sanitize
    local raw
    raw="${os_part}-${arch}"
    raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]')
    echo "$(_sanitize "$raw")"
}

function _sanitize() {
    local raw="$1"
    # sanitize: replace any character not in [A-Za-z0-9.-] with a dash
    # The sed expression replaces every character that's not A-Za-z0-9 or '.' or '-' with '-'
    echo "$raw" | sed 's/[^A-Za-z0-9.\-]/-/g'
}

function _linux_flavour() {
    # linux_flavour: parse /etc/os-release for ID and VERSION_ID
    # If /etc/os-release is readable, pull ID and VERSION_ID
    if [[ -r /etc/os-release ]]; then
        # Extract ID (e.g. "ubuntu" or "debian") and strip quotes
        local distro
        distro=$(grep '^ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"')
        # Extract VERSION_ID (e.g. "22.04") and strip quotes
        local version
        version=$(grep '^VERSION_ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"')
        # Fallback defaults if those keys are missing
        [[ -z "$distro" ]] && distro="linux"
        [[ -z "$version" ]] && version="0"
        echo "${distro}${version}"
    else
        # If the file is missing or unreadable, fallback to "linux0"
        echo "linux0"
    fi
}

build_runtime
