#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# bin/icarus.sh
# Created 1/18/25 - 6:35 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Script Options
set -o errexit   # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
project_root_dir_abs="$(realpath -- "${script_dir_abs}/..")"
declare -r project_root_dir_abs
python_interpreter_abs="${project_root_dir_abs}/build_venv/bin/python3"
declare -r python_interpreter_abs
python_entrypoint_abs="${project_root_dir_abs}/entrypoint.py"
declare -r python_entrypoint_abs

# Ensure the virtual environment exists
if [ ! -x "${python_interpreter_abs}" ]; then
    echo "Python interpreter not found. Please create it." >&2
    exit 1
fi

# Execute the main CLI script with the virtual environment's Python
exec "${python_interpreter_abs}" "${python_entrypoint_abs}" "$@"
