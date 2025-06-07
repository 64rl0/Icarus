#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/platform_id.sh
# Created 6/6/25 - 3:47 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# -------------------------------------------------------------------
# sanitize: replace any character not in [A-Za-z0-9.-] with a dash
# -------------------------------------------------------------------
sanitize() {
    local raw="$1"
    # The sed expression replaces every character that's not A-Za-z0-9 or '.' or '-' with '-'
    echo "$raw" | sed 's/[^A-Za-z0-9.\-]/-/g'
}

# -------------------------------------------------------------------
# linux_flavour: parse /etc/os-release for ID and VERSION_ID
# -------------------------------------------------------------------
linux_flavour() {
    # If /etc/os-release is readable, pull ID and VERSION_ID
    if [[ -r /etc/os-release ]]; then
        # Extract ID (e.g. “ubuntu” or “debian”) and strip quotes
        local distro
        distro=$(grep '^ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"')
        # Extract VERSION_ID (e.g. “22.04”) and strip quotes
        local version
        version=$(grep '^VERSION_ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"')
        # Fallback defaults if those keys are missing
        [[ -z "$distro" ]] && distro="linux"
        [[ -z "$version" ]] && version="0"
        echo "${distro}${version}"
    else
        # If the file is missing or unreadable, fallback to “linux0”
        echo "linux0"
    fi
}

# -------------------------------------------------------------------
# platform_id: combine OS-flavour and architecture, then sanitize/normalize
# -------------------------------------------------------------------
platform_id() {
    # 1) Determine architecture (lowercased)
    #    e.g. “x86_64” → “x86_64”, “aarch64” or “arm64” → “arm64”
    local arch
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    # 2) Determine OS-specific “os_part”
    local uname_s os_part
    uname_s=$(uname -s)

    case "$uname_s" in
    Linux*)
        # On Linux, use /etc/os-release to get “distroVERSION”
        os_part=$(linux_flavour)
        ;;

    Darwin*)
        # On macOS, use sw_vers to get the product version (e.g. “13.4.1”)
        local version
        version=$(sw_vers -productVersion 2>/dev/null || echo "")
        [[ -z "$version" ]] && version="0"
        os_part="macos${version}"
        ;;

    CYGWIN* | MINGW* | MSYS*)
        # On Windows/Cygwin/Msys, attempt to extract “Windows NT x.x.xxxxx” from ‘ver’
        # If that fails, fall back to “win0”
        local winver
        # ‘cmd.exe /c ver’ gives something like: “Microsoft Windows [Version 10.0.19044.2130]”
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
    echo "$(sanitize "$raw")"
}

platform_id
