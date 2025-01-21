#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/restart.sh
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
unison_restart() {
    # Only print this if NOT called by the terminal for logging purposes
    if [[ ! -t 1 ]]; then
        echo -e "\n\n\n\n\n"
        echo -e "++++++++++++ DEBUGGING INFO ++++++++++++"
        echo -e "icarus unison restart called at -> $(date)"
        echo
        echo -e "Home var is -> ${HOME}"
        echo
        echo -e "Path var is -> ${PATH}"
        echo
        echo -e "Iam -> $(whoami)"
        echo
        echo -e "I'm in -> $(pwd)"
        echo
        echo -e "agents are located at:"
        echo -e "${unison_launchd_daemon_path}"
        ls -la "${unison_launchd_daemon_path}"
        echo
        echo -e "${unison_daily_restart_daemon_path}"
        ls -la "${unison_daily_restart_daemon_path}"
        echo
        echo -e "active launchd including unison:"
        launchctl list | grep unison || echo "-none found"
        echo -e "++++++++++++++++++++++++++++++++++++++++\n"
    fi

    ${this_cli_fullpath} unison stop
    echo -e ""
    sleep 1

    ${this_cli_fullpath} unison clear-locks
    echo -e ""
    sleep 1

    ${this_cli_fullpath} unison start-at-startup
    sleep 1

    echo -e "Loading launchd daemons configuration"

    echo -e "loading ${unison_launchd_daemon_path}"
    launchctl load "${unison_launchd_daemon_path}"

    echo -e "loading ${unison_daily_restart_daemon_path}"
    launchctl load "${unison_daily_restart_daemon_path}"

    echo -e "Configuration loaded\n"

    echo -e "Starting up Unison..."
    echo -e ""
    sleep 10
    ${this_cli_fullpath} unison status
}

unison_restart "$@"
