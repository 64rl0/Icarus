#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/build_venv.sh
# Created 3/2/24 - 8:09 AM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Basic Foreground Colors
declare -r black=$'\033[30m'
declare -r red=$'\033[31m'
declare -r green=$'\033[32m'
declare -r yellow=$'\033[33m'
declare -r blue=$'\033[34m'
declare -r magenta=$'\033[35m'
declare -r cyan=$'\033[36m'
declare -r white=$'\033[37m'

# Bold/Bright Foreground Colors
declare -r bold_black=$'\033[1;30m'
declare -r bold_red=$'\033[1;31m'
declare -r bold_green=$'\033[1;32m'
declare -r bold_yellow=$'\033[1;33m'
declare -r bold_blue=$'\033[1;34m'
declare -r bold_magenta=$'\033[1;35m'
declare -r bold_cyan=$'\033[1;36m'
declare -r bold_white=$'\033[1;37m'

# Basic Background Colors
declare -r bg_black=$'\033[40m'
declare -r bg_red=$'\033[41m'
declare -r bg_green=$'\033[42m'
declare -r bg_yellow=$'\033[43m'
declare -r bg_blue=$'\033[44m'
declare -r bg_magenta=$'\033[45m'
declare -r bg_cyan=$'\033[46m'
declare -r bg_white=$'\033[47m'

# Text Formatting
declare -r bold=$'\033[1m'
declare -r dim=$'\033[2m'
declare -r italic=$'\033[3m'
declare -r underline=$'\033[4m'
declare -r invert=$'\033[7m'
declare -r hidden=$'\033[8m'

# Reset Specific Formatting
declare -r end=$'\033[0m'
declare -r end_bold=$'\033[21m'
declare -r end_dim=$'\033[22m'
declare -r end_italic_underline=$'\033[23m'
declare -r end_invert=$'\033[27m'
declare -r end_hidden=$'\033[28m'

# Emoji
declare -r green_check_mark="\xE2\x9C\x85"
declare -r hammer_and_wrench="\xF0\x9F\x9B\xA0"
declare -r clock="\xE2\x8F\xB0"
declare -r sparkles="\xE2\x9C\xA8"
declare -r stop_sign="\xF0\x9F\x9B\x91"
declare -r warning_sign="\xE2\x9A\xA0\xEF\xB8\x8F"
declare -r key="\xF0\x9F\x94\x91"
declare -r circle_arrows="\xF0\x9F\x94\x84"
declare -r broom="\xF0\x9F\xA7\xB9"
declare -r link="\xF0\x9F\x94\x97"
declare -r package="\xF0\x9F\x93\xA6"
declare -r network_world="\xF0\x9F\x8C\x90"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
project_root_dir_abs="$(realpath -- "${script_dir_abs}/..")"
declare -r project_root_dir_abs

# Get venv name or set to default 'build_undefined'
if [[ -z "$1" ]]; then
    venv_name="build_undefined"
    echo -e "\n\n${bold_red}${warning_sign} No venv name supplied! Using: ${venv_name}${end}"
elif [[ -n "$1" ]]; then
    venv_name="$1"
    echo -e "\n\n${bold_green}${green_check_mark} Building venv ${venv_name}${end}"
fi

# Find the most recent Python version in the system
accepted_python_versions=("3.12" "3.11" "3.10" "3.9")
for version in "${accepted_python_versions[@]}"; do
    if command -v "python${version}" >/dev/null 2>&1; then
        python_version_for_venv="${version}"
        break
    fi
done

if [[ -z "${python_version_for_venv}" ]]; then
    echo -e "\n\n${bold_red}${stop_sign} No Python version found!${end}"
    exit 1
fi

# Create Local venv
echo -e "\n\n${bold_green}${sparkles} Creating ${venv_name} venv...${end}"
python${python_version_for_venv} -m venv --clear --copies "${project_root_dir_abs}/${venv_name}"

# Activate local venv
source "${project_root_dir_abs}/${venv_name}/bin/activate"
echo -e "\n\n${bold_green}${green_check_mark} venv ${venv_name} activated:${end}"
echo -e "OS Version: $(uname)"
echo -e "Kernel Version: $(uname -r)"
echo -e "venv: $VIRTUAL_ENV"
echo -e "running: $(python --version)"

# Install requirements
echo -e "\n\n${bold_green}${sparkles} Installing requirements...${end}"
pip install --upgrade pip
pip install -I -r "${project_root_dir_abs}/requirements.txt"

# Build complete!
echo -e "\n\n${bold_green}${sparkles} ${venv_name} venv build complete & Ready for use!...${end}"

echo -e "\n\n${bold_yellow}${warning_sign} Virtual environment deactivated!${end}"
deactivate
