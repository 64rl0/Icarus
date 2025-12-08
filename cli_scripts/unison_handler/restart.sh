#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/restart.sh
# Created 1/20/25 - 10:48 PM UK Time (London) by carlogtt

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
unison_restart() {
    local uid
    uid="$(id -u)"

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
        echo -e "${unison_launchd_path}"
        ls -la "${unison_launchd_path}"
        echo
        echo -e "${unison_daily_restart_path}"
        ls -la "${unison_daily_restart_path}"
        echo
        echo -e "active launchd including unison:"
        launchctl list | grep unison || echo "-none found"
        echo -e "++++++++++++++++++++++++++++++++++++++++\n"
    fi

    ${this_cli_fullpath} unison stop
    echo -e ""
    sleep 1

    for identity in "${devdsk_to_sync[@]}"; do
        ${this_cli_fullpath} unison clear-locks -i "${identity}"
        echo -e ""
    done

    ${this_cli_fullpath} unison start-at-startup
    sleep 1

    echo -e "Loading launchd agents configuration"

    echo -e "bootstrapping ${unison_launchd_path}"
    launchctl enable "gui/${uid}/${unison_launchd_label}" || {
        echo -e "${unison_launchd_label} failed to enable"
    }
    launchctl bootstrap "gui/${uid}" "${unison_launchd_path}" || {
        echo -e "${unison_launchd_label} failed to bootstrap"
    }

    echo -e "bootstrapping ${unison_daily_restart_path}"
    launchctl enable "gui/${uid}/${unison_daily_restart_label}" || {
        echo -e "${unison_daily_restart_label} failed to enable"
    }
    launchctl bootstrap "gui/${uid}" "${unison_daily_restart_path}" || {
        echo -e "${unison_daily_restart_label} failed to bootstrap"
    }

    echo -e "Configuration loaded\n"

    echo -e "Starting up Unison service..."
    for i in {1..10}; do
        printf "\r${clear_line}Please wait %d" $((10 - i))
        sleep 1
    done
    printf "\r${clear_line}\n"
    ${this_cli_fullpath} unison status
}

unison_restart "$@"
