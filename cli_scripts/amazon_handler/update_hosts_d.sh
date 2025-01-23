#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/update_hosts_d.sh
# Created 1/20/25 - 11:39 AM UK Time (London) by carlogtt
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
update_etc_hosts_daemon() {
    local hosts_launchd_daemon_path="/Library/LaunchDaemons/com.carlogtt.hosts.daemon.plist"

    echo -e "We need to briefly run as root (through sudo) to execute some commands."
    echo -e "If prompted, please enter your user password."
    sudo -v

    echo -e "\nWriting launchd daemon configuration"

    cat <<EOF | sudo tee "${hosts_launchd_daemon_path}" >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.carlogtt.hosts.daemon</string>
        <key>StartCalendarInterval</key>
        <dict>
            <key>Minute</key>
            <integer>00</integer>
        </dict>
        <key>StandardOutPath</key>
        <string>/tmp/com.carlogtt.hosts.daemon.log</string>
        <key>StandardErrorPath</key>
        <string>/tmp/com.carlogtt.hosts.daemon.log</string>
        <key>ProgramArguments</key>
        <array>
            <string>${this_cli_fullpath}</string>
            <string>-v</string>
            <string>amazon</string>
            <string>update-hosts</string>
        </array>
    </dict>
</plist>
EOF

    sudo chown root:wheel ${hosts_launchd_daemon_path}
    sudo chmod 644 ${hosts_launchd_daemon_path}

    echo -e "launchd daemon configuration was successfully written to"
    echo -e "${hosts_launchd_daemon_path}"

    echo -e "\nLoading launchd daemons configuration"
    echo -e "loading ${hosts_launchd_daemon_path}"
    sudo launchctl unload "${hosts_launchd_daemon_path}"
    sudo launchctl load "${hosts_launchd_daemon_path}"
    echo -e "Configuration loaded"
}

update_etc_hosts_daemon "$@"
