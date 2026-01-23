#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/icarus.sh
# Created 1/18/25 - 6:35 PM UK Time (London) by carlogtt

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

declare -r red=$'\033[31m'
declare -r bg_red=$'\033[41m'
declare -r bold_black=$'\033[1;30m'
declare -r end=$'\033[0m'

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs

project_root_dir_abs="$(realpath -- "${script_dir_abs}/..")"
declare -r project_root_dir_abs

python_interpreter_abs="${project_root_dir_abs}/runtime_env/env/bin/python3"
declare -r python_interpreter_abs

python_entrypoint_abs="${project_root_dir_abs}/entrypoint.py"
declare -r python_entrypoint_abs

log_path="${project_root_dir_abs}/log"
declare -r log_path

log_filepath="${project_root_dir_abs}/log/icarus.log"
declare -r log_filepath

# Check if the --update option is called
if [[ "$1" == '--update' ]]; then
    if [[ "${script_dir_abs}" =~ _Projects\/Icarus\/ ]]; then
        echo -e "${bg_red}${bold_black}[WARNING]${end}"
        echo -e " You are about to run ${red}git reset --hard${end} on the dev env!"
        echo -e " Operation Interrupted! Only available in PROD!"
        echo -e " Use make build-runtime in dev!"
        exit 1
    fi
    echo -e "Updating icarus CLI please wait..."
    mkdir -p "${log_path}"
    {
        echo -e "[$(date '+%Y-%m-%d %T %Z')] Running icarus --update"
        pushd "${project_root_dir_abs}"
        git fetch --all --prune
        git reset --hard origin/HEAD
        git pull --rebase=false
        bash "${project_root_dir_abs}/scripts/build_runtime.sh"
    } >"${log_filepath}" 2>&1 || {
        echo -e "${bg_red}${bold_black}[ERROR]${end} - Failed to install icarus CLI"
        echo -e " logs saved in ${log_filepath}"
        exit 1
    }
    echo -e "icarus CLI updated!"
    echo -e ""
fi

# Ensure the virtual environment exists
if [ ! -x "${python_interpreter_abs}" ]; then
    echo -e "Installing icarus CLI please wait..."
    mkdir -p "${log_path}"
    {
        echo -e "[$(date '+%Y-%m-%d %T %Z')] ${python_interpreter_abs} not found! rebuilding env"
        pushd "${project_root_dir_abs}"
        bash "${project_root_dir_abs}/scripts/build_runtime.sh"
    } >"${log_filepath}" 2>&1 || {
        echo -e "${bg_red}${bold_black}[ERROR]${end} - Failed to install icarus CLI"
        echo -e " logs saved in ${log_filepath}"
        exit 1
    }
    echo -e "icarus CLI installed!"
    echo -e ""
fi

# Execute the main CLI script with the virtual environment's Python
exec "${python_interpreter_abs}" "${python_entrypoint_abs}" "$@"
