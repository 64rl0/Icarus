#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/unison_base.sh
# Created 1/21/25 - 1:50 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# User defined variables
declare -r unison_launchd_daemon_path="${HOME}/Library/LaunchAgents/com.unison.launchd.agent.plist"
declare -r unison_daily_restart_daemon_path="${HOME}/Library/LaunchAgents/com.unison.daily_restart.agent.plist"
