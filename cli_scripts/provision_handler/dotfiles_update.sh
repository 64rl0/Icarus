#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/dotfiles_update.sh
# Created 1/20/25 - 10:44 PM UK Time (London) by carlogtt
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
function dotfiles_update() {
    local -a dotfiles=(
        "${HOME}/.bash/config"
        "${HOME}/.bash/completion"
        "${HOME}/.zsh/config"
        "${HOME}/.zsh/completion"
        "${HOME}/.carlogtt_alias"
        "${HOME}/.carlogtt_script"
        "${HOME}/.aws"
        "${HOME}/.vim"
        "${HOME}/.config/alacritty"
        "${HOME}/.config/apple-terminal"
        "${HOME}/.config/bat"
        "${HOME}/.config/fzf"
        "${HOME}/.config/homebrew"
        "${HOME}/.config/lazygit"
        "${HOME}/.config/starship"
        "${HOME}/.config/tmux"
        "${HOME}/.config/yazi"
    )

    for dotfile in "${dotfiles[@]}"; do
        if [[ -d "${dotfile}/.git" ]]; then
            echo_time ""
            echo -e "${sparkles}${bold_yellow}${dotfile}${end}"
            pushd "${dotfile}" >/dev/null
            git fetch
            git pull
            git status
            popd >/dev/null
            echo -e ""
        fi
    done
}

dotfiles_update "$@"
