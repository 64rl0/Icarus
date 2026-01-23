#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/build_launcher_binary.sh
# Created 1/21/26 - 3:37 PM UK Time (London) by carlogtt

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
project_root_dir_abs="$(realpath -- "${script_dir_abs}/..")"
declare -r project_root_dir_abs
launcher_dir="${project_root_dir_abs}/launcher"
declare -r launcher_dir

macos_src="${project_root_dir_abs}/launcher/icarus_launcher_macos.c"
linux_src="${project_root_dir_abs}/launcher/icarus_launcher_linux.c"

build_macos() {
    local arch="$1"
    local output_dir="${launcher_dir}/bin/macos/${arch}"
    local output="${output_dir}/icarus"
    local cc="${CC_MACOS:-clang}"

    if ! command -v "${cc}" >/dev/null 2>&1; then
        echo "Missing compiler for macOS (${cc})."
        return 1
    fi

    rm -rf "${output_dir}"
    mkdir -p "${output_dir}"
    "${cc}" -O2 -Wall -Wextra -arch "${arch}" -mmacosx-version-min=11.0 \
        -o "${output}" "${macos_src}"
    chmod 755 "${output}"
    echo "Built ${output}"
}

build_linux() {
    local arch="$1"
    local output_dir="${launcher_dir}/bin/linux/${arch}"
    local output="${output_dir}/icarus"
    local cc=""

    if [[ "${arch}" == "x86_64" ]]; then
        cc="${CC_LINUX_X86_64:-cc}"
    else
        cc="${CC_LINUX_ARM64:-aarch64-linux-gnu-gcc}"
        if ! command -v "${cc}" >/dev/null 2>&1; then
            cc="${CC_LINUX_ARM64:-cc}"
        fi
    fi

    if ! command -v "${cc}" >/dev/null 2>&1; then
        echo "Missing compiler for Linux ${arch} (${cc})."
        return 1
    fi

    rm -rf "${output_dir}"
    mkdir -p "${output_dir}"
    "${cc}" -O2 -Wall -Wextra -o "${output}" "${linux_src}"
    chmod 755 "${output}"
    echo "Built ${output}"
}

build_all() {
    local failed=0

    build_macos "arm64" || failed=1
    build_macos "x86_64" || failed=1
    build_linux "arm64" || failed=1
    build_linux "x86_64" || failed=1

    if [[ "${failed}" -ne 0 ]]; then
        echo "One or more launcher builds failed."
        return 1
    fi
}

build_all
