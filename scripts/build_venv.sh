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
platform_id_script_path_abs="${script_dir_abs}/platform_id.sh"
declare -r platform_id_script_path_abs

venv_name="build_venv"
python_full_version_for_venv="3.13.5"
platform_id="$(bash "${platform_id_script_path_abs}")"
download_url="https://github.com/64rl0/PythonRuntime/releases/download/cpython-${python_full_version_for_venv}-${platform_id}/cpython-${python_full_version_for_venv}-${platform_id}.tar.gz"
pybin="${project_root_dir_abs}/${venv_name}/env/icarus-runtime/bin/python3"

# Download Python Runtime
echo -e "\n\n${bold_green}${sparkles} Downloading Python Runtime...${end}"
mkdir -p "${project_root_dir_abs}/${venv_name}/env"
curl -L "${download_url}" -o "${project_root_dir_abs}/${venv_name}/env/cpython.tar.gz"
tar -xzf "${project_root_dir_abs}/${venv_name}/env/cpython.tar.gz" -C "${project_root_dir_abs}/${venv_name}/env"
mv "${project_root_dir_abs}/${venv_name}/env/${python_full_version_for_venv}" "${project_root_dir_abs}/${venv_name}/env/icarus-runtime"
rm -rf "${project_root_dir_abs}/${venv_name}/env/cpython.tar.gz"

# Install requirements
echo -e "\n\n${bold_green}${sparkles} Installing requirements...${end}"
"${pybin}" -m pip install --upgrade pip
"${pybin}" -m pip install -I -r "${project_root_dir_abs}/requirements.txt"

# Build complete!
echo -e "\n\n${bold_green}${sparkles} ${venv_name} venv build complete & Ready for use!...${end}"
