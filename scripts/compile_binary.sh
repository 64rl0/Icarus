#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/compile_binary.sh
# Created 1/20/25 - 2:19 PM UK Time (London) by carlogtt
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

# User defined variables

# Activate local venv
source "${project_root_dir_abs}/build_venv/bin/activate"
echo -e "\n\n${bold_green}${green_check_mark} venv build_venv activated:${end}"
echo -e "OS Version: $(uname)"
echo -e "Kernel Version: $(uname -r)"
echo -e "venv: $VIRTUAL_ENV"
echo -e "running: $(python --version)"

echo -e "\n${bold_green}${hammer_and_wrench} Compiling binary...${end}"
pyinstaller \
    --clean \
    --onedir \
    --noconfirm \
    --name "icarus" \
    --add-data "build_venv:build_venv" \
    --add-data "cli_scripts:cli_scripts" \
    --add-data "src:src" \
    --add-data "entrypoint.py:entrypoint.py" \
    --hidden-import "src.icarus.main" \
    --collect-binaries "python3" \
    --debug "all" \
    --log-level "DEBUG" \
    --distpath "${project_root_dir_abs}/dist" \
    --workpath "${project_root_dir_abs}/dist/build" \
    "${project_root_dir_abs}/entrypoint.py"

mv "${project_root_dir_abs}/icarus.spec" "${project_root_dir_abs}/dist/build/icarus.spec"

#nuitka \
#    --standalone \
#    --onefile \
#    "${project_root_dir_abs}/entrypoint.py"

echo -e "\n\n${bold_yellow}${warning_sign} Virtual environment deactivated!${end}"
deactivate

echo -e "\n${bold_green}${green_check_mark} Done!${end}"
