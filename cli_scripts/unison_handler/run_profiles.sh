#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/run_profiles.sh
# Created 1/21/25 - 3:48 PM UK Time (London) by carlogtt
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
source "${unison_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source unison_base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
unison_terminal_notifier() {
    local profile=$1
    local message=""
    local log_file="${HOME}/.unison/unison_${profile}.log"
    local line=""

    # Make sure the log file exists, if not create it and add a new empty line
    # so the tail -f will not read the last line on file
    touch "${log_file}"
    echo "" >>"${log_file}"

    # Run unison with profile
    /opt/homebrew/bin/unison -ui text "$profile" >/dev/null 2>&1 &

    # Follow the log file and process new lines as they are written
    tail -f -n 1 "${log_file}" | while IFS= read -r line; do

        if [[ "${line:0:24}" == "Synchronization complete" ]]; then
            message=${line:39:$((${#line} - 40))}
            message="✅ SYNC SUCCESSFUL                                         $message"

            # For debugging
            echo "$message"

            # Push notification
            /opt/homebrew/bin/terminal-notifier -message "$message" \
                -title "UNISON -> ${profile}" \
                -sound "Default" -group "UNISON-$(date +%s)" \
                -open "file://${log_file}"

        elif [[ "${line:0:26}" == "Synchronization incomplete" ]]; then
            message=${line:41:$((${#line} - 42))}
            message="⚠️ SYNC WARNING                                           $message"

            # For debugging
            echo "$message"

            # Push notification
            /opt/homebrew/bin/terminal-notifier -message "$message" \
                -title "UNISON -> ${profile}" \
                -sound "Default" -group "UNISON-$(date +%s)" \
                -open "file://${log_file}"

        elif [[ "${line:0:6}" == "Error:" || "${line:0:11}" == "Fatal error" ]]; then
            message=$line
            message="🚨 SYNC ALERT                                              $message"

            # For debugging
            echo "$message"

            # Push notification
            /opt/homebrew/bin/terminal-notifier -message "$message" \
                -title "UNISON ERROR -> ${profile}" \
                -sound "Default" -group "UNISON-$(date +%s)" \
                -open "file://${log_file}"

        fi
    done
}

unison_run_profiles() {
    local -a unison_profiles=(
        "prof_devdsk9"
        "prof_devdsk10"

        "prof_workplace"

        "prof_my_lib_src"
        "prof_my_lib_test"
        "prof_my_lib_playground"
    )

    for unison_profile in "${unison_profiles[@]}"; do
        unison_terminal_notifier "${unison_profile}" &
    done

    # wait to keep the unison profiles running
    wait
}

unison_run_profiles "$@"
