#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/macos_handler/update_icarus_daemon.sh
# Created 6/26/25 - 8:13 PM UK Time (London) by carlogtt
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
icarus_update_install_launchd() {
    local agent_fullpath agent_label uid
    agent_label="com.icarus.cli.updater"
    agent_fullpath="${HOME}/Library/LaunchAgents/com.icarus.cli.updater.plist"
    uid="$(id -u)"

    echo -e "Writing launchd icarus cli updater agent configuration"

    # This is specifically set to update at 11:42 to prevent clashed with other
    # schedules that run on the same time.

    cat <<EOF >"${agent_fullpath}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>

        <key>EnvironmentVariables</key>
        <dict>
            <key>PATH</key>
            <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            <key>HOME</key>
            <string>${HOME}</string>
        </dict>

        <key>WorkingDirectory</key>
        <string>${HOME}</string>

        <key>LimitLoadToSessionType</key>
        <string>Aqua</string>

        <key>Label</key>
        <string>${agent_label}</string>

        <key>StartCalendarInterval</key>
        <dict>
            <key>Hour</key>
            <integer>11</integer>
            <key>Minute</key>
            <integer>42</integer>
        </dict>

        <key>StandardOutPath</key>
        <string>/tmp/${agent_label}.log</string>

        <key>StandardErrorPath</key>
        <string>/tmp/${agent_label}.log</string>

        <key>ProgramArguments</key>
        <array>
            <string>${this_cli_fullpath}</string>
            <string>--update</string>
        </array>

    </dict>
</plist>
EOF

    echo -e "launchd icarus cli updater agent configuration was successfully written to"
    echo -e "${agent_fullpath}"
    echo

    echo -e "Loading launchd icarus cli updater agent configuration"

    launchctl disable "gui/${uid}/${agent_label}" || {
        echo -e "${agent_label} failed to disable"
    }

    launchctl bootout "gui/${uid}/${agent_label}" || {
        echo -e "${agent_label} failed to bootout"
    }

    launchctl enable "gui/${uid}/${agent_label}" || {
        echo -e "${agent_label} failed to enable"
    }

    launchctl bootstrap "gui/${uid}" "${agent_fullpath}" || {
        echo -e "${agent_label} failed to bootstrap"
    }
}

icarus_update_install_launchd "$@"
