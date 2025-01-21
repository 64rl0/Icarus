#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/clear_locks.sh
# Created 1/20/25 - 10:48 PM UK Time (London) by carlogtt
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
unison_base="${script_dir_abs}/unison_base.sh"
declare -r unison_base

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"
source "${unison_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
clear_locks_local_machine() {
    echo -e "Clearing locks on local host..."
    rm -rf -- "${HOME}/.unison/lk"* || exit 0
    echo -e "Local host clear"
}

clear_locks_ssh() {
    local hostname="devdsk$1"

    echo -e "Clearing locks on SSH ${hostname}..."
    ssh "${hostname}" 'rm -rf -- ${HOME}/.unison/lk* || exit  0'
    echo -e "SSH ${hostname} clear"
}

# Parsing args
declare devdsk_id="$1"

if [[ -z "${devdsk_id}" ]]; then
    clear_locks_local_machine
else
    clear_locks_ssh "${devdsk_id}"
    echo -e "\n"
    clear_locks_ssh "${devdsk_id}"
fi
