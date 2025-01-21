#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/stop.sh
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
unison_stop() {
    echo -e "Terminating existing launchd daemons configuration"
    echo -e "unloading ${unison_launchd_daemon_path}"
    launchctl unload "${unison_launchd_daemon_path}" || {
        echo -e "${unison_launchd_daemon_path} failed unload"
    }

    # Only stop the daemon if called by terminal because if it is called by the launch agent
    # this will kill its own process and interrupt the execution.
    if [[ -t 1 ]]; then
        echo -e "unloading ${unison_daily_restart_daemon_path}"
        launchctl unload "${unison_daily_restart_daemon_path}" || {
            echo -e "${unison_daily_restart_daemon_path} failed unload"
        }
    fi

    echo -e "unload completed!"
    sleep 1
    echo -e "Configuration terminated\n"

    echo -e "${bold}${red}[TERMINATING UNISON]${end}"
    ps aux | grep 'unison -ui' | grep -v grep | awk -v red="${red}" -v end="${end}" '{print "Killing PID: " $2"..." red " >>> " end $11 " " $12 " " $13 " " $14 " " $15 " " $16 " " $17}' || echo -e "No Unison process found."
    ps aux | grep 'unison -ui' | grep -v grep | awk '{print $2}' | xargs kill -9 || :
}

unison_stop "$@"
