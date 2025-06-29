#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/base.sh
# Created 1/21/25 - 12:25 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Basic Foreground Colors
declare -r black_=$'\033[30m'
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
declare -r clear_line=$'\033[2K'

# Emoji
declare -r green_check_mark="\xE2\x9C\x85"
declare -r hammer_and_wrench="\xF0\x9F\x9B\xA0"
declare -r clock="\xE2\x8F\xB0"
declare -r sparkles="\xE2\x9C\xA8"
declare -r green_sparkles="\xE2\x9D\x87"
declare -r green_circle="\xF0\x9F\x9F\xA2"
declare -r stop_sign="\xF0\x9F\x9B\x91"
declare -r warning_sign="\xE2\x9A\xA0\xEF\xB8\x8F"
declare -r key="\xF0\x9F\x94\x91"
declare -r circle_arrows="\xF0\x9F\x94\x84"
declare -r broom="\xF0\x9F\xA7\xB9"
declare -r link="\xF0\x9F\x94\x97"
declare -r package="\xF0\x9F\x93\xA6"
declare -r network_world="\xF0\x9F\x8C\x90"

# Sourcing existing bashrc to export current PATH
. "${HOME}/.bashrc" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source .bashrc"
if [[ -n "${SUDO_USER}" ]]; then
    if [[ $(uname -s) == "Darwin" ]]; then
        . "/Users/${SUDO_USER}/.bashrc" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source .bashrc"
        . "/Users/${SUDO_USER}/.bash/config/bash.conf" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source bash.conf"
    elif [[ $(uname -s) == "Linux" ]]; then
        . "/home/${SUDO_USER}/.bashrc" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source .bashrc"
        . "/home/${SUDO_USER}/.bash/config/bash.conf" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source bash.conf"
    fi
fi

# CLI variables
declare -r cli_name='icarus'
declare -r this_cli_fullpath="${HOME}/.icarus/bin/${cli_name}"

function echo_error() {
    local message="${1}"
    local errexit="${2}"

    echo
    echo -e "${bold_black}${bg_red} ERROR! ${end}"
    echo -e " [$(date '+%Y-%m-%d %T %Z')]"
    echo -e " ${message}"
    echo

    if [[ "${errexit}" == "errexit" ]]; then
        return 1
    else
        return 0
    fi
}

function echo_warning() {
    local message="${1}"
    local errexit="${2}"

    echo
    echo -e "${bold_black}${bg_yellow} WARNING! ${end}"
    echo -e " [$(date '+%Y-%m-%d %T %Z')]"
    echo -e " ${message}"
    echo

    if [[ "${errexit}" == "errexit" ]]; then
        return 1
    else
        return 0
    fi
}

function echo_time() {
    local message="${1}"

    echo -e "[$(date '+%Y-%m-%d %T %Z')] ${message}"
}

function echo_need_sudo() {
    echo -e "We need to briefly run as root (through sudo) to execute some commands."
    echo -e "If prompted, please enter your user password."
    sudo -v
    echo
}
