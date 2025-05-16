#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/forge.sh
# Created 5/15/25 - 11:55 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs
this_script_abs_filepath="$(realpath -- "${BASH_SOURCE[0]}")"
declare -r this_script_abs_filepath
cli_script_base="${cli_scripts_dir_abs}/base.sh"
declare -r cli_script_base

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# Forge Script Paths
user_current_path="$(pwd -P)"
declare -r user_current_path

project_root_dir_abs="$(realpath -- "${user_current_path}")"
declare -r project_root_dir_abs

icarusignore="${project_root_dir_abs}/.icarusignore"
declare -r icarusignore

# Initial validation
if [[ -z "${*}" ]]; then
    echo -e "${bold_black}${bg_red} ERROR! ${end}"
    echo -e " No arguments provided!"
    exit 1
fi
if [[ ! -e "${icarusignore}" ]]; then
    echo -e "${bold_black}${bg_red} ERROR! ${end}"
    echo -e " You are not in an icarus build enabled directory!"
    echo -e " No \`.icarusignore\` file found. To enable icarus build create a \`.icarusignore\` in the project root directory."
    exit 1
fi

# User defined variables
devdsk="devdsk8"
brazil_python_runtime="python3.11"
python_version_for_venv="3.12"

forge_preflight_tools=(
    "isort"
    "black"
    "flake8"
    "mypy"
    "shfmt"
    "whitespaces"
    "trailing"
    "eofnewline"
    "gitleaks"
    "pytest"
)

if [[ "${*}" =~ "--with-isort" ]]; then
    isort="Y"
else
    isort="N"
fi

if [[ "${*}" =~ "--with-black" ]]; then
    black_fmt="Y"
else
    black_fmt="N"
fi

if [[ "${*}" =~ "--with-flake8" ]]; then
    flake8="Y"
else
    flake8="N"
fi

if [[ "${*}" =~ "--with-mypy" ]]; then
    mypy="Y"
else
    mypy="N"
fi

if [[ "${*}" =~ "--with-shfmt" ]]; then
    shfmt="Y"
else
    shfmt="N"
fi

if [[ "${*}" =~ "--with-whitespaces" ]]; then
    whitespaces="Y"
else
    whitespaces="N"
fi

if [[ "${*}" =~ "--with-eofnewline" ]]; then
    eofnewline="Y"
else
    eofnewline="N"
fi

if [[ "${*}" =~ "--with-trailing" ]]; then
    trailing="Y"
else
    trailing="N"
fi

if [[ "${*}" =~ "--with-pytest" ]]; then
    pytest="Y"
else
    pytest="N"
fi

if [[ "${*}" =~ "--with-gitleaks" ]]; then
    gitleaks="Y"
else
    gitleaks="N"
fi

if [[ "${*}" =~ "--format" ]]; then
    isort="Y"
    black_fmt="Y"
    flake8="Y"
    mypy="Y"
    shfmt="Y"
    whitespaces="Y"
    eofnewline="Y"
    trailing="Y"
fi

if [[ "${*}" =~ "--test" ]]; then
    pytest="Y"
fi

if [[ "${*}" =~ "--all" ]]; then
    isort="Y"
    black_fmt="Y"
    flake8="Y"
    mypy="Y"
    shfmt="Y"
    whitespaces="Y"
    eofnewline="Y"
    trailing="Y"
    pytest="Y"
    gitleaks="Y"
fi

function echo_title() {
    title="${1}"
    echo -e "\n${sparkles} ${bg_cyan}${bold_black} ${title} ${end}"
    echo
}

function run_isort() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    isort_summary_status="${bold_black}${bg_green} PASS ${end}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        isort "${el}" 2>&1 || {
            isort_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
    done
}

function run_black() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    black_summary_status="${bold_black}${bg_green} PASS ${end}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        black "${el}" 2>&1 || {
            black_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
    done
}

function run_flake8() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    flake8_summary_status="${bold_black}${bg_green} PASS ${end}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        flake8 -v "${el}" 2>&1 || {
            flake8_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
    done
}

function run_mypy() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    mypy_summary_status="${bold_black}${bg_green} PASS ${end}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        output=$(mypy "${el}" 2>&1 | tee /dev/tty) || {
            if [[ ! "${output}" =~ ^There\ are\ no\ \.py\[i\]\ files\ in\ directory ]]; then
                mypy_summary_status="${bold_black}${bg_red} FAIL ${end}"
                exit_code=1
            fi
        }
        echo
    done
}

function run_shfmt() {
    elements=("${active_dirs[@]}" "${active_sh_files[@]}")
    shfmt_summary_status="${bold_black}${bg_green} PASS ${end}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        shfmt -l -w "${el}" 2>&1 || {
            shfmt_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
    done
}

function run_char_replacement() {
    elements=("${active_files_all[@]}")
    whitespaces_summary_status="${bold_black}${bg_green} PASS ${end}"
    local counter=0

    for el in "${elements[@]}"; do
        # Skip this script
        if [[ "${el}" == "${this_script_abs_filepath}" ]]; then
            continue
        fi

        # Skip empty files
        if [[ ! -s "${el}" ]]; then
            continue
        fi

        # Skip non-text (binary) files
        if file_path=$(command -v file); then
            if [[ $("${file_path}" -b --mime-type -- "${el}") != text/* ]]; then
                continue
            fi
        else
            grep -Iq . "${el}" || continue
        fi

        echo -e "Fixing: ${el}"
        ((counter = counter + 1))

        if [[ $(uname -s) == "Darwin" ]]; then
            # macOS
            find "${el}" -type f -exec sed -i '' 's/ / /g' {} + 2>&1 || {
                whitespaces_summary_status="${bold_black}${bg_red} FAIL ${end}"
                exit_code=1
            }
        else
            # Linux
            find "${el}" -type f -exec sed -i 's/ / /g' {} + 2>&1 || {
                whitespaces_summary_status="${bold_black}${bg_red} FAIL ${end}"
                exit_code=1
            }
        fi
    done

    echo
    echo -e "Fixed ${counter} file(s)"
    echo
}

function run_eofnewline() {
    elements=("${active_files_all[@]}")
    eofnewline_summary_status="${bold_black}${bg_green} PASS ${end}"
    local counter=0

    for el in "${elements[@]}"; do
        # Skip empty files – they already satisfy the “blank line” rule.
        if [[ ! -s "${el}" ]]; then
            continue
        fi

        # Skip non-text (binary) files
        if file_path=$(command -v file); then
            if [[ $("${file_path}" -b --mime-type -- "${el}") != text/* ]]; then
                continue
            fi
        else
            grep -Iq . "${el}" || continue
        fi

        # Read the last byte; add '\n' only if it isn't one already.
        if [[ $(tail -c1 -- "${el}" | od -An -tu1) -ne 10 ]]; then
            echo "Fixing: ${el}"
            echo "EOF char is: $(tail -c1 -- "${el}")"
            echo
            printf '\n' >>"${el}" || {
                eofnewline_summary_status="${bold_black}${bg_red} FAIL ${end}"
                exit_code=1
            }
            ((counter = counter + 1))
        fi
    done

    echo -e "Fixed ${counter} file(s)"
    echo
}

function run_trailingwhitespaces() {
    elements=("${active_files_all[@]}")
    trailing_summary_status="${bold_black}${bg_green} PASS ${end}"

    # TODO(carlogtt): implement this tool

    echo -e "Tool not implemented yet"
    echo
}

function run_pytest() {
    pytest_summary_status="${bold_black}${bg_green} PASS ${end}"

    pytest 2>&1 || {
        pytest_summary_status="${bold_black}${bg_red} FAIL ${end}"
        exit_code=1
    }
    echo
}

function run_gitleaks() {
    gitleaks_summary_status="${bold_black}${bg_green} PASS ${end}"

    if gitleaks_path=$(command -v \gitleaks); then
        echo -e "${blue}git commits${end}"
        "${gitleaks_path}" git --no-banner -v 2>&1 || {
            gitleaks_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
        echo -e "${blue}git pre-commit${end}"
        "${gitleaks_path}" git --pre-commit --no-banner -v 2>&1 || {
            gitleaks_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
        echo -e "${blue}git staged${end}"
        "${gitleaks_path}" git --staged --no-banner -v 2>&1 || {
            gitleaks_summary_status="${bold_black}${bg_red} FAIL ${end}"
            exit_code=1
        }
        echo
    else
        gitleaks_summary_status="${bold_black}${bg_magenta} SKIP ${end}"
        echo -e "${bold_red}[NOT FOUND] gitleaks not found in PATH${end}"
        echo
    fi
}

function read_icarusignore() {
    declare -a -g icarusignore_content

    while IFS= read -r line || [[ -n ${line} ]]; do
        # strip leading & trailing blanks
        trimmed=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"${line}")

        # ignore empty/blank lines
        if [[ -z "${trimmed}" ]]; then
            continue
        fi

        # ignore comments
        if [[ "${trimmed}" =~ ^#.* ]]; then
            continue
        fi

        # keep only the first whitespace-separated field
        read -r first _ <<<"${trimmed}"
        icarusignore_content+=("${first}")
    done <"${icarusignore}"

    declare -r -g icarusignore_content
}

function build_active_dirs_l1() {
    declare -a all_dirs_l1
    all_dirs_l1=($(find "${project_root_dir_abs}" -mindepth 1 -maxdepth 1 -type d))

    declare -a -g active_dirs
    active_dirs=()

    for dir in "${all_dirs_l1[@]}"; do
        unset ignore_dir

        for ignored in "${icarusignore_content[@]}"; do
            if [[ "${ignored}" =~ ^\*\/.+ ]]; then
                if [[ "${dir}/" == "${project_root_dir_abs}"${ignored} ]]; then
                    ignore_dir=true
                    break
                fi
            else
                if [[ "${dir}/" == "${project_root_dir_abs}/"${ignored} ]]; then
                    ignore_dir=true
                    break
                fi
            fi
        done

        if [[ "${ignore_dir}" != true ]]; then
            active_dirs+=("${dir}")
        fi
    done

    declare -r -g active_dirs
}

function build_active_files_l1() {
    declare -a all_files_l1
    all_files_l1=($(find "${project_root_dir_abs}" -mindepth 1 -maxdepth 1 -type f))

    declare -a -g active_py_files
    active_py_files=()
    declare -a -g active_sh_files
    active_sh_files=()
    declare -a -g active_other_files
    active_other_files=()

    for file in "${all_files_l1[@]}"; do
        unset ignore_file

        for ignored in "${icarusignore_content[@]}"; do
            if [[ "${ignored}" =~ ^\*\/.+ ]]; then
                if [[ "${file}" == "${project_root_dir_abs}"${ignored} ]]; then
                    ignore_file=true
                    break
                fi
            else
                if [[ "${file}" == "${project_root_dir_abs}/"${ignored} ]]; then
                    ignore_file=true
                    break
                fi
            fi
        done

        if [[ "${ignore_file}" != true ]]; then
            if [[ "${file}" =~ .+\.py$ ]]; then
                active_py_files+=("${file}")
            elif [[ "${file}" =~ .+\.sh$ ]]; then
                active_sh_files+=("${file}")
            else
                active_other_files+=("${file}")
            fi
        fi
    done

    declare -r -g active_py_files
    declare -r -g active_sh_files
    declare -r -g active_other_files
}

function build_all_active_files() {
    declare -a all_files
    all_files=($(find "${project_root_dir_abs}" -type f))

    declare -a -g active_files_all
    active_files_all=()

    for file in "${all_files[@]}"; do
        unset ignore_file

        for ignored in "${icarusignore_content[@]}"; do
            if [[ "${ignored}" =~ ^\*\/.+ ]]; then
                if [[ "${file}" == "${project_root_dir_abs}"${ignored}* ]]; then
                    ignore_file=true
                    break
                fi
            else
                if [[ "${file}" == "${project_root_dir_abs}/"${ignored}* ]]; then
                    ignore_file=true
                    break
                fi
            fi
        done

        if [[ "${ignore_file}" != true ]]; then
            active_files_all+=("${file}")
        fi
    done

    declare -r -g active_files_all
}

function echo_summary() {
    echo -e "${runtime}"
    echo

    printf "%-35s-+-%-7s\n" "-----------------------------------" "-------"
    printf "%-46s | %-7s\n" "${bold_white}Tool${end}" "${bold_white}Status${end}"
    printf "%-35s-+-%-7s\n" "-----------------------------------" "-------"

    for pftool in "${forge_preflight_tools[@]}"; do
        tool="$(printf '%s' "${pftool} ..................................." | cut -c1-35)"
        eval status='$'"${pftool}_summary_status"
        printf "%-35s | %-7s\n" "${tool}" "${status}"
    done

    printf "%-35s-+-%-7s\n" "-----------------------------------" "-------"

    echo
}

function build_venv() {
    venv_name="${2}"
    if [[ -z "${venv_name}" ]]; then
        venv_name="build_undefined"
        echo -e "\n\n${bold_red}${warning_sign} No venv name supplied! Using default: '${venv_name}'${end}"
    elif [[ -n "${venv_name}" ]]; then
        echo -e "\n\n${bold_green}${green_check_mark} Building '${venv_name}' venv...${end}"
    fi

    # Create Local venv
    echo -e "\n\n${bold_green}${sparkles} Creating '${venv_name}' venv...${end}"
    python${python_version_for_venv} -m venv --clear --copies "${project_root_dir_abs}/${venv_name}"

    # Activate local venv
    . "${project_root_dir_abs}/${venv_name}/bin/activate"
    echo -e "\n\n${bold_green}${green_check_mark} '${venv_name}' venv activated:${end}"
    echo -e "OS Version: $(uname)"
    echo -e "Kernel Version: $(uname -r)"
    echo -e "venv: $VIRTUAL_ENV"
    echo -e "running: $(python --version)"

    # Install requirements
    echo -e "\n\n${bold_green}${sparkles} Installing requirements into '${venv_name}' venv...${end}"
    pip install --upgrade pip
    pip install -I -r "${project_root_dir_abs}/requirements.txt"

    # Build complete!
    echo -e "\n\n${bold_green}${sparkles} '${venv_name}' venv build complete & Ready for use!${end}"

    echo -e "\n\n${bold_yellow}${warning_sign} Virtual environment deactivated!${end}"
    deactivate
}

function activate_venv() {
    # Use brazil runtime farm
    if [[ -d "${project_root_dir_abs}/build/private" ]]; then
        brazil_bin_dir="$(brazil-path testrun.runtimefarm)/${brazil_python_runtime}/bin"
    fi

    # Use project build_venv venv
    if [[ -d "${project_root_dir_abs}/build_venv" ]]; then
        path_to_venv_root="${project_root_dir_abs}/build_venv"
        venv_name="venv (build_venv)"
    # Use DevDsk dev_tools venv if we are on a DevDsk
    elif [[ -d "${HOME}/${devdsk}" ]]; then
        path_to_venv_root="${HOME}/${devdsk}/venvs/dev_tools"
        venv_name="venv DevDsk (dev_tools)"
    # Use Dropbox dev_tools venv if we are on local macbook
    elif [[ -d "${HOME}/Library/CloudStorage/Dropbox" ]]; then
        path_to_venv_root="${HOME}/Library/CloudStorage/Dropbox/SDE/VirtualEnvs/dev_tools"
        venv_name="venv Dropbox (dev_tools)"
    fi

    # Display Project info
    echo -e "${bold_green}${hammer_and_wrench} Project Root:${end}"
    echo "${project_root_dir_abs}"

    # Activate brazil runtime env first as it takes precedence
    if [[ -n "${brazil_bin_dir}" ]]; then
        OLD_PATH="${PATH}"
        PATH="${brazil_bin_dir}:${PATH}"
        venv_name="Brazil ENV"
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

    # Set runtime to be used in summary
    runtime="${bold_yellow}Runtime:${end} \n--| $(python3 --version)\n--| ${venv_name}"

    # Display env info
    echo -e "OS Version: $(uname)"
    echo -e "Kernel Version: $(uname -r)"
    echo -e "running: $(python3 --version)"
    echo
}

function deactivate_venv() {
    if [[ -n "${OLD_PATH}" ]]; then
        PATH="${OLD_PATH}"
    else
        deactivate
    fi
    echo -e "${bold_yellow}${warning_sign} Virtual environment deactivated!${end}"
    echo
    echo
}

function preflight_tools() {
    skipped="${bold_black}${bg_white} SKIP ${end}"

    echo_title "Project info"
    activate_venv

    read_icarusignore
    build_active_dirs_l1
    build_active_files_l1
    build_all_active_files

    if [[ "${isort}" == "Y" ]]; then
        echo_title "Running iSort..."
        run_isort
    else
        isort_summary_status="${skipped}"
    fi

    if [[ "${black_fmt}" == "Y" ]]; then
        echo_title "Running Black..."
        run_black
    else
        black_summary_status="${skipped}"
    fi

    if [[ "${flake8}" == "Y" ]]; then
        echo_title "Running Flake8..."
        run_flake8
    else
        flake8_summary_status="${skipped}"
    fi

    if [[ "${mypy}" == "Y" ]]; then
        echo_title "Running mypy..."
        run_mypy
    else
        mypy_summary_status="${skipped}"
    fi

    if [[ "${shfmt}" == "Y" ]]; then
        echo_title "Running shfmt (bash formatter)..."
        run_shfmt
    else
        shfmt_summary_status="${skipped}"
    fi

    if [[ "${whitespaces}" == "Y" ]]; then
        echo_title "Running 'NNBSP' char replacement..."
        run_char_replacement
    else
        whitespaces_summary_status="${skipped}"
    fi

    if [[ "${trailing}" == "Y" ]]; then
        echo_title "Running trailing-whitespaces..."
        run_trailingwhitespaces
    else
        trailing_summary_status="${skipped}"
    fi

    if [[ "${eofnewline}" == "Y" ]]; then
        echo_title "Running eof-newline..."
        run_eofnewline
    else
        eofnewline_summary_status="${skipped}"
    fi

    if [[ "${gitleaks}" == "Y" ]]; then
        echo_title "Running gitleaks..."
        run_gitleaks
    else
        gitleaks_summary_status="${skipped}"
    fi

    if [[ "${pytest}" == "Y" ]]; then
        echo_title "Running pytest..."
        run_pytest
    else
        pytest_summary_status="${skipped}"
    fi

    echo_title "Deactivating virtual environment..."
    deactivate_venv

    echo_title "Forge Summary"
    echo_summary
}

function main() {
    exit_code=0

    # If we are building a local venv, build it and exit
    if [[ "${*}" =~ "--build-venv" ]]; then
        build_venv ${@}
        exit "${exit_code}"
    fi

    # If we are not building a venv, run preflight tools
    preflight_tools ${@}

    return "${exit_code}"
}

echo running with args: "${*}"
main "${@}"
