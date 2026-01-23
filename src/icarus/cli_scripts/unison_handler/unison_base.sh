#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/unison_base.sh
# Created 1/21/25 - 1:50 PM UK Time (London) by carlogtt

# User defined variables
declare -r unison_launchd_label="com.icarus.unison.launchd"
declare -r unison_launchd_path="${HOME}/Library/LaunchAgents/com.icarus.unison.launchd.plist"

declare -r unison_daily_restart_label="com.icarus.unison.restart.daily"
declare -r unison_daily_restart_path="${HOME}/Library/LaunchAgents/com.icarus.unison.restart.daily.plist"

declare -r -a devdsk_to_sync=(
    "9"
    "10"
    "14"
)
