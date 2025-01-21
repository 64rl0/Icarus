#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/midway_cookie.sh
# Created 1/20/25 - 10:32 AM UK Time (London) by carlogtt
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
cookies_analysis() {
    # Define the path to the cookies file
    if [[ -n $1 ]]; then
        local cookies_filepath="${1}"
    else
        local cookies_filepath="${HOME}/.midway/cookie"
    fi

    # Check if the cookies file exists
    if [[ ! -f "$cookies_filepath" ]]; then
        echo "Cookies file not found."
        exit 1
    fi

    local current_timestamp=$(date +%s)

    # Process each line of the file
    while read -r line; do
        # Skip commented out lines and empty lines
        if [[ "${line}" =~ ^#[[:space:]] || "${line}" =~ ^$ ]]; then
            continue
        fi

        # Extract the expiration timestamp and the cookie name
        local cookie_name=$(echo "$line" | awk '{print $6}')
        local cookie_domain=$(echo "$line" | awk '{print $1}' | awk '{gsub(/(#HttpOnly_\.?|^\.)/, ""); print}')
        local cookie_expiry_timestamp=$(echo "$line" | awk '{print $5}')

        # Calculate the time remaining
        local cookie_time_remaining=$((cookie_expiry_timestamp - current_timestamp))

        # Convert time remaining to human-readable format
        local days_remaining=$((cookie_time_remaining / 86400))
        local hours_remaining=$(((cookie_time_remaining % 86400) / 3600))
        local minutes_remaining=$(((cookie_time_remaining % 3600) / 60))
        local seconds_remaining=$((cookie_time_remaining % 60))

        # Use printf to format the output
        if [[ "${cookie_time_remaining}" -le 0 ]]; then
            printf -- "--| %-30s %-35s EXPIRED\n" "$cookie_name" "$cookie_domain"
        else
            printf -- "--| %-30s %-35s VALID %9d days, %2d hours, %2d minutes, %2d seconds\n" "$cookie_name" "$cookie_domain" "$days_remaining" "$hours_remaining" "$minutes_remaining" "$seconds_remaining"
        fi
    done <"${cookies_filepath}"
}

cookies_analysis "$@"
