#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/unison_handler/run_profiles.sh
# Created 1/21/25 - 3:48 PM UK Time (London) by carlogtt
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
run_profiles_core="${script_dir_abs}/run_profiles_core.sh"
declare -r cli_scripts_dir_abs

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"
source "${unison_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source unison_base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
unison_run_profiles() {
    local -a unison_profiles=(
        "prof_workplace"
        # "prof_brazil-pkg-cache"
        "prof_my_lib"
        "prof_devdsk7"
        "prof_devdsk8"
    )

    for unison_profile in "${unison_profiles[@]}"; do
        nohup "${run_profiles_core}" "${unison_profile}" >'/tmp/com.unison.run_profiles_core.log' 2>&1 &
    done

    # wait to keep the unison profiles running
    wait
}

unison_run_profiles "$@"
