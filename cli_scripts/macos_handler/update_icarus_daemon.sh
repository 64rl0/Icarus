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
    local daemon_fullpath user_name
    daemon_fullpath="${HOME}/Library/LaunchAgents/com.icarus.daily_update.agent.plist"
    user_name="$(whoami)"

    echo -e "Writing launchd icarus daily update demon configuration"

    cat <<EOF >"${daemon_fullpath}"
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
        <key>Label</key>
        <string>com.icarus.daily_update.agent</string>
        <key>UserName</key>
        <string>${user_name}</string>
        <key>StartCalendarInterval</key>
        <dict>
            <key>Hour</key>
            <integer>12</integer>
            <key>Minute</key>
            <integer>00</integer>
        </dict>
        <key>StandardOutPath</key>
        <string>/tmp/com.icarus.daily_update.agent.log</string>
        <key>StandardErrorPath</key>
        <string>/tmp/com.icarus.daily_update.agent.log</string>
        <key>ProgramArguments</key>
        <array>
            <string>${this_cli_fullpath}</string>
            <string>--update</string>
        </array>
    </dict>
</plist>
EOF
    echo -e "launchd icarus daily update demon configuration was successfully written to"
    echo -e "${daemon_fullpath}"
    echo

    echo -e "Loading launchd icarus daily update demon configuration"
    launchctl unload "${daemon_fullpath}"
    launchctl load "${daemon_fullpath}"
}

icarus_update_install_launchd "$@"
