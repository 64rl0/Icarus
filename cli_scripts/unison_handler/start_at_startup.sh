#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/start_at_startup.sh
# Created 1/20/25 - 10:49 PM UK Time (London) by carlogtt
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
unison_install_launchd() {
    echo -e "Writing launchd daemon configuration"

    cat <<EOF >"${unison_launchd_daemon_path}"
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
        <string>com.unison.launchd.agent</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>StandardOutPath</key>
        <string>/tmp/com.unison.launchd.agent.log</string>
        <key>StandardErrorPath</key>
        <string>/tmp/com.unison.launchd.agent.log</string>
        <key>ProgramArguments</key>
        <array>
            <string>${this_cli_fullpath}</string>
            <string>unison</string>
            <string>run-profiles</string>
        </array>
    </dict>
</plist>
EOF

    cat <<EOF >"${unison_daily_restart_daemon_path}"
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
        <string>com.unison.daily_restart.agent</string>
        <key>StartCalendarInterval</key>
        <dict>
            <key>Hour</key>
            <integer>12</integer>
            <key>Minute</key>
            <integer>00</integer>
        </dict>
        <key>StandardOutPath</key>
        <string>/tmp/com.unison.daily_restart.agent.log</string>
        <key>StandardErrorPath</key>
        <string>/tmp/com.unison.daily_restart.agent.log</string>
        <key>ProgramArguments</key>
        <array>
            <string>${this_cli_fullpath}</string>
            <string>unison</string>
            <string>restart</string>
        </array>
    </dict>
</plist>
EOF

    echo -e "launchd daemon configuration was successfully written to"
    echo -e "${unison_launchd_daemon_path}"
    echo -e "${unison_daily_restart_daemon_path}\n"
}

unison_install_launchd "$@"
