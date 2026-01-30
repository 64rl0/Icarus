#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/stop.sh
# Created 1/20/25 - 10:48 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs

# Sourcing base file
. "${cli_scripts_dir_abs}/base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"
. "${script_dir_abs}/unison_base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source unison_base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
unison_stop() {
    local uid
    uid="$(id -u)"

    echo -e "Terminating existing launchd agents configuration"

    echo -e "Terminating ${unison_launchd_label}"
    launchctl disable "gui/${uid}/${unison_launchd_label}" || {
        echo -e "${unison_launchd_label} failed to disable"
    }
    launchctl bootout "gui/${uid}/${unison_launchd_label}" || {
        echo -e "${unison_launchd_label} failed to bootout"
    }

    # Only stop the agent if called by terminal because if it is called by the launch agent
    # this will kill its own process and interrupt the execution.
    if [[ -t 1 ]]; then
        echo -e "Terminating ${unison_daily_restart_label}"
        launchctl disable "gui/${uid}/${unison_daily_restart_label}" || {
            echo -e "${unison_daily_restart_label} failed to disable"
        }
        launchctl bootout "gui/${uid}/${unison_daily_restart_label}" || {
            echo -e "${unison_daily_restart_label} failed to bootout"
        }
    fi

    sleep 1
    echo -e "launchd agents terminated!\n"

    echo -e "${bold}${red}[TERMINATING UNISON]${end}"
    ps aux | grep 'unison -ui' | grep -v grep | awk -v red="${red}" -v end="${end}" '{print "Killing PID: " $2"..." red " >>> " end $11 " " $12 " " $13 " " $14 " " $15 " " $16 " " $17}' || echo -e "No Unison process found."
    ps aux | grep 'unison -ui' | grep -v grep | awk '{print $2}' | xargs kill -9 || :
}

unison_stop "$@"
