#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/brazil_setup.sh
# Created 1/20/25 - 11:50 AM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs
project_root_dir_abs="$(realpath -- "${cli_scripts_dir_abs}/..")"
declare -r project_root_dir_abs
cli_script_base="${cli_scripts_dir_abs}/base.sh"
declare -r cli_script_base

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
brazil_setup_volumes() {
    echo -e "We need to briefly run as root (through sudo) to execute some commands."
    echo -e "If prompted, please enter your user password."
    sudo -v

    echo -e "\nCreating case-sensitive volumes ('workplace' and 'brazil-pkg-cache')."

    local diskref=$(diskutil apfs list | awk -F: '/Container Reference/{gsub (" ", ""); print $2}')
    echo -e "Diskref is ${diskref}"

    echo -e "\n\nCreating the workplace volume..."
    diskutil apfs addVolume "${diskref}" "Case-sensitive APFS" "workplace"

    echo -e "\n\nCreating the brazil-pkg-cache volume..."
    diskutil apfs addVolume "${diskref}" "Case-sensitive APFS" "brazil-pkg-cache"

    echo -e "\n\nCreating a symbolic link from the workplace volume to your home directory..."
    ln -s "/Volumes/workplace" "${HOME}/workplace"

    echo -e "Creating a symbolic link from the brazil-pkg-cache volume to your home directory..."
    ln -s "/Volumes/brazil-pkg-cache" "${HOME}/brazil-pkg-cache"

    echo -e "\n\n${green_check_mark} ${bold_green}Brazil volumes created successfully!"
}

brazil_setup_volumes "$@"
