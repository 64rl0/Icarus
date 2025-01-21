#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/spurdog_ro.sh
# Created 1/20/25 - 11:41 AM UK Time (London) by carlogtt
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
spurdog_read_on() {
    if [[ "$2" == "--auth" ]]; then
        # Run mwinit authentication
        "${this_cli_fullpath}" "amazon" "auth-init"
    fi

    local username="$1"
    curl --cookie "${HOME}/.midway/cookie" -L -G --silent --data "id=${username}" "https://sarsen-ccwt.adc.security.aws.dev/api/v1/check" | jq
}

spurdog_read_on "$@"
