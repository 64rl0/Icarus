#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/auth_init.sh
# Created 1/20/25 - 10:42 PM UK Time (London) by carlogtt
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

_authenticate_midway() {
    local -a mw_args=($@)

    # Temporarily disable 'errexit' to allow for retries
    set +e

    local attempt=1
    local max_attempts=3

    while [[ ${attempt} -le ${max_attempts} ]]; do
        ((attempt++))

        echo -e "${blue}Midway Authentication${end}"
        if [ -n "$SSH_CONNECTION" ]; then
            echo -e "${blue}cmd: mwinit -o -s ${mw_args[*]} ${end}"
            mwinit --otp-auth -s "${mw_args[@]}"
        else
            echo -e "${blue}cmd: mwinit -f -s ${mw_args[*]} ${end}"
            mwinit --fido2 -s "${mw_args[@]}"
        fi
        mwinit_status=$?

        # Check if Midway was successful
        if [[ ${mwinit_status} -eq 0 ]]; then
            echo -e "${bold_green}${key} Successfully authenticated!${end}"
            break
        else
            echo -e "${bold_red}Authentication failed! Please try again.\n${end}"
            continue
        fi
    done

    # Re-enable 'errexit'
    set -e
}

_authenticate_kerberos() {
    # Temporarily disable 'errexit' to allow for retries
    set +e

    local attempt=1
    local max_attempts=3

    while [[ ${attempt} -le ${max_attempts} ]]; do
        ((attempt++))

        echo -e "${blue}Kerberos Authentication${end}"
        if kinit_path=$(command -v \kinit); then
            echo -e "${blue}cmd: kinit -f${end}"
            ${kinit_path} -f
            kinit_status=$?
        else
            echo -e "${bold_red}[DISABLED] Kerberos not found!${end}"
            kinit_status=0
        fi

        # Check if Kerberos was successful
        if [[ ${kinit_status} -eq 0 ]]; then
            echo -e "${bold_green}${key} Successfully authenticated!${end}"
            break
        else
            echo -e "${bold_red}Authentication failed! Please try again.\n${end}"
            # continue
            break # break the loop as sometimes we do not have Kerberos
        fi
    done

    # Re-enable 'errexit'
    set -e
}

# User defined variables
auth_init_local_machine() {
    local -a mw_args=($1)

    # Local machine
    echo -e "${bold_yellow}${circle_arrows} Authentication started for $(uname -n)...\n${end}"

    # Authenticate Kerberos
    _authenticate_kerberos

    # Break line
    echo ""

    # Authenticate Midway
    _authenticate_midway "${mw_args[@]}"

    # Break line
    echo ""
    echo ""
}

auth_init_ssh() {
    local -a devdsk_ids=($1)
    local -a mw_args=($2)

    # Prefix each element with --mw-args
    local -a mw_args_expanded=()
    for arg in "${mw_args[@]}"; do
        mw_args_expanded+=("--mw-args" "${arg}")
    done

    # Iterate over each argument
    for dev_dsk_number in "${devdsk_ids[@]}"; do
        # Construct the HOSTNAME
        local hostname="devdsk${dev_dsk_number}"

        # SSH into the cloud desktop and initialize there
        echo -e "${bold_yellow}${circle_arrows} Authentication started for REMOTE SSH ${hostname}...${end}"

        ssh -t "${hostname}" "\${HOME}/.icarus/bin/icarus amazon auth-init ${mw_args_expanded[*]}"

        # Break line
        echo ""
        echo ""
    done
}

parse_args() {
    local -a devdsk_ids=($1)
    local -a mw_args=($2)

    if [[ -z "${devdsk_ids[0]}" ]]; then
        auth_init_local_machine "${mw_args[*]}"
    else
        auth_init_local_machine "${mw_args[*]}"
        auth_init_ssh "${devdsk_ids[*]}" "${mw_args[*]}"
    fi
}

parse_args "$@"
