#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/cache.sh
# Created 5/15/25 - 11:55 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs

# Sourcing base file
. "${cli_scripts_dir_abs}/base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"
. "${cli_scripts_dir_abs}/builder_handler/builder_base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source builder_base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

####################################################################################################
# SYSTEM
####################################################################################################
function validate_prerequisites() {
    # Nothing to do here
    :
}

####################################################################################################
# CONSTANTS
####################################################################################################
function set_constants() {
    eval "${@}"

    # Declaring global vars from `builder_base`
    # This must be done after the `eval "${@}"` call
    declare_global_vars

    exit_code=0
}

####################################################################################################
# TOOLS
####################################################################################################
function clean_cache() {
    rm -rf "${path_to_cache_root}" || {
        echo_error "Failed to clean '${path_to_cache_root}'."
        exit_code=1
    }
    echo

    mkdir -p "${path_to_cache_root}" || {
        echo_error "Failed to create cache root directory."
        exit_code=1
    }
}

####################################################################################################
# DISPATCHERS
####################################################################################################
function dispatch_build_system() {
    if [[ "${cache_root}" == "Y" ]]; then
        printf "%s\n" "${path_to_cache_root}"
    fi

    if [[ "${cache_clean}" == "Y" ]]; then
        clean_cache
    fi
}

####################################################################################################
# MAIN
####################################################################################################
function main() {
    validate_prerequisites

    set_constants "${@}"

    dispatch_build_system

    return "${exit_code}"
}

main "${@}"
