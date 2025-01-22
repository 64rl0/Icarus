#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/formatter.sh
# Created 3/3/24 - 11:41 AM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Command used in the external tool is:
# --login -c "./scripts/formatter.sh"

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

# Select the correct venv with the tools installed
devdsk="devdsk7"
python_runtime="python3.11"

# Use brazil runtime farm
if [[ -d "${project_root_dir_abs}/build/private" ]]; then
    brazil_bin_dir="$(brazil-path testrun.runtimefarm)/${python_runtime}/bin"
fi

# Use project build_venv venv
if [[ -d "${project_root_dir_abs}/build_venv" ]]; then
    path_to_venv_root="${project_root_dir_abs}/build_venv"
# Use DevDsk dev_tools venv if we are on a DevDsk
elif [[ -d "${HOME}/${devdsk}" ]]; then
    path_to_venv_root="${HOME}/${devdsk}/venvs/dev_tools"
# Use Dropbox dev_tools venv if we are on local macbook
elif [[ -d "${HOME}/Library/CloudStorage/Dropbox" ]]; then
    path_to_venv_root="${HOME}/Library/CloudStorage/Dropbox/SDE/VirtualEnvs/dev_tools"
fi

# Display Project info
echo -e "\n${bold_green}${hammer_and_wrench} Project Root:${end}"
echo "${project_root_dir_abs}"

# Activate brazil runtime env first as it takes precedence
if [[ -n "${brazil_bin_dir}" ]]; then
    OLD_PATH="${PATH}"
    PATH="${brazil_bin_dir}:${PATH}"
    echo -e "\n${bold_green}${green_check_mark} Virtual environment activated:${end}"
    echo -e "${brazil_bin_dir}"
# Activate venv if we are not in brazil venv
elif [[ -n "${path_to_venv_root}" ]]; then
    source "${path_to_venv_root}/bin/activate"
    echo -e "\n${bold_green}${green_check_mark} Virtual environment activated:${end}"
    echo -e "venv: ${VIRTUAL_ENV}"
#  Cannot activate any venv
else
    echo -e "\n${bold_red}Cannot find any venv to activate!${end}"
    echo -e "${bold_red}Have you selected the correct DevDsk and/or build_venv in the formatter file?${end}"
    echo -e "${bold_red}Run 'make build' to build a local build_venv in ${project_root_dir_abs}/build_venv${end}\n"
    exit 1
fi

# Display env info
echo -e "OS Version: $(uname)"
echo -e "Kernel Version: $(uname -r)"
echo -e "running: $(python3 --version)"

echo -e "\n${bold_green}${sparkles} Running iSort...${end}"
isort="Y"
if [[ "${isort}" == "Y" ]]; then
    if [[ -d "${project_root_dir_abs}/src" ]]; then
        echo -e "${blue}src/${end}"
        isort "${project_root_dir_abs}/src" 2>&1
    fi
    if [[ -d "${project_root_dir_abs}/test" ]]; then
        echo -e "${blue}\ntest/${end}"
        isort "${project_root_dir_abs}/test" 2>&1
    fi
else
    echo -e "${bold_red}[DISABLED]${end}"
fi

echo -e "\n${bold_green}${sparkles} Running Black...${end}"
black_fmt="Y"
if [[ "${black_fmt}" == "Y" ]]; then
    if [[ -d "${project_root_dir_abs}/src" ]]; then
        echo -e "${blue}src/${end}"
        black "${project_root_dir_abs}/src" 2>&1
    fi
    if [[ -d "${project_root_dir_abs}/test" ]]; then
        echo -e "${blue}\ntest/${end}"
        black "${project_root_dir_abs}/test" 2>&1
    fi
else
    echo -e "${bold_red}[DISABLED]${end}"
fi

echo -e "\n${bold_green}${sparkles} Running Flake8...${end}"
flake8="Y"
if [[ "${flake8}" == "Y" ]]; then
    if [[ -d "${project_root_dir_abs}/src" ]]; then
        echo -e "${blue}src/${end}"
        flake8 -v "${project_root_dir_abs}/src" 2>&1
    fi
    if [[ -d "${project_root_dir_abs}/test" ]]; then
        echo -e "${blue}\ntest/${end}"
        flake8 -v "${project_root_dir_abs}/test" 2>&1
    fi
else
    echo -e "${bold_red}[DISABLED]${end}"
fi

echo -e "\n${bold_green}${sparkles} Running mypy...${end}"
mypy="Y"
if [[ "${mypy}" == "Y" ]]; then
    if [[ -d "${project_root_dir_abs}/src" ]]; then
        echo -e "${blue}src/${end}"
        mypy "${project_root_dir_abs}/src" 2>&1
    fi
    if [[ -d "${project_root_dir_abs}/test" ]]; then
        echo -e "${blue}\ntest/${end}"
        mypy "${project_root_dir_abs}/test" 2>&1
    fi
else
    echo -e "${bold_red}[DISABLED]${end}"
fi

echo -e "\n${bold_green}${sparkles} Running shfmt...${end}"
shfmt="Y"
if [[ "${shfmt}" == "Y" ]]; then
    if [[ -d "${script_dir_abs}" ]]; then
        echo -e "${blue}scripts/${end}"
        shfmt -l -w "${script_dir_abs}"
    fi
    if [[ -d "${project_root_dir_abs}/cli_scripts" ]]; then
        echo -e "${blue}\ncli_scripts/${end}"
        shfmt -l -w "${project_root_dir_abs}/cli_scripts"
    fi
    if [[ -d "${project_root_dir_abs}/configuration" ]]; then
        echo -e "${blue}\nconfiguration/${end}"
        shfmt -l -w "${project_root_dir_abs}/configuration"
    fi
    if [[ -d "${project_root_dir_abs}/src" ]]; then
        echo -e "${blue}\nsrc/${end}"
        shfmt -l -w "${project_root_dir_abs}/src"
    fi
    if [[ -d "${project_root_dir_abs}/test" ]]; then
        echo -e "${blue}\ntest/${end}"
        shfmt -l -w "${project_root_dir_abs}/test"
    fi
    if [[ -d "${project_root_dir_abs}/lib" ]]; then
        echo -e "${blue}\nlib/${end}"
        shfmt -l -w "${project_root_dir_abs}/lib"
    fi
else
    echo -e "${bold_red}[DISABLED]${end}"
fi

echo -e "\n${bold_green}${sparkles} Running 'NNBSP' char replacement...${end}"
nnbsp="Y"
if [[ "${nnbsp}" == "Y" ]]; then
    if [[ -d "${script_dir_abs}" ]]; then
        echo -e "${blue}scripts/${end}"
        find "${project_root_dir_abs}/scripts" -type f -not -name "formatter.sh" -exec sed -i '' 's/ / /g' {} +
        echo -e "done!"
    fi
    if [[ -d "${project_root_dir_abs}/cli_scripts" ]]; then
        echo -e "${blue}\ncli_scripts/${end}"
        find "${project_root_dir_abs}/cli_scripts" -type f -exec sed -i '' 's/ / /g' {} +
        echo -e "done!"
    fi
    if [[ -d "${project_root_dir_abs}/configuration" ]]; then
        echo -e "${blue}\nconfiguration/${end}"
        find "${project_root_dir_abs}/configuration" -type f -exec sed -i '' 's/ / /g' {} +
        echo -e "done!"
    fi
    if [[ -d "${project_root_dir_abs}/src" ]]; then
        echo -e "${blue}\nsrc/${end}"
        find "${project_root_dir_abs}/src" -type f -not -path '*.pyc' -exec sed -i '' 's/ / /g' {} +
        echo -e "done!"
    fi
    if [[ -d "${project_root_dir_abs}/test" ]]; then
        echo -e "${blue}\ntest/${end}"
        find "${project_root_dir_abs}/test" -type f -not -path '*.pyc' -exec sed -i '' 's/ / /g' {} +
        echo -e "done!"
    fi
    if [[ -d "${project_root_dir_abs}/lib" ]]; then
        echo -e "${blue}\nlib/${end}"
        find "${project_root_dir_abs}/lib" -type f -exec sed -i '' 's/ / /g' {} +
        echo -e "done!"
    fi
else
    echo -e "${bold_red}[DISABLED]${end}"
fi

echo -e "\n${bold_yellow}${warning_sign} Virtual environment deactivated!${end}"
if [[ -n "${OLD_PATH}" ]]; then
    PATH="${OLD_PATH}"
else
    deactivate
fi
