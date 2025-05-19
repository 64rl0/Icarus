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

# User defined variables
function echo_error() {
    echo
    echo -e "${bold_black}${bg_red} ERROR! ${end}"
    echo -e " [$(date '+%Y-%m-%d %T %Z')]"
    echo -e " ${1}"
    echo
    exit 1
}

function echo_title() {
    local title="${1}"

    local total_width=100
    local gap=2
    local title_len=${#title}

    # How many “=” are still available once we subtract the title and the gaps?
    local free=$((total_width - title_len - gap))

    # Split that space into left and right pads
    local left=$((free / 2))
    local right=$((free - left))

    # Build the pieces
    local left_pad=$(printf '%*s' "${left}" '' | tr ' ' '=')
    local right_pad=$(printf '%*s' "${right}" '' | tr ' ' '=')
    local border=$(printf '=%.0s' $(seq 1 $total_width))

    # Output
    echo
    echo -e "${bold_white}${left_pad} ${title} ${right_pad}${end}"
    echo
}

function echo_running_hooks() {
    echo_title "Running Info"
    echo -e "Collected and preparing to run ${running_hooks_count} hook(s)."
    for hook in "${running_hooks_name[@]}"; do
        echo -e "--| ${blue}${hook}${end}"
    done
    echo
}

function echo_summary() {
    echo_title "Forge Summary"
    echo -e "${runtime}"
    echo

    printf "%-35s-+-%-7s\n" "-----------------------------------" "-------"
    printf "%-46s | %-7s\n" "${bold_white}Tool${end}" "${bold_white}Status${end}"
    printf "%-35s-+-%-7s\n" "-----------------------------------" "-------"

    for hook in "${forge_hooks[@]}"; do
        tool="$(printf '%s' "${hook} ..................................." | cut -c1-35)"
        eval status='$'"${hook}_summary_status"
        printf "%-35s | %-7s\n" "${tool}" "${status}"
    done

    printf "%-35s-+-%-7s\n" "-----------------------------------" "-------"

    echo
}

find_project_root() {
    local dir=$PWD

    while [[ "${dir}" != '/' ]]; do
        if [[ -f "${dir}/${icarus_config_filename}" ]]; then
            project_root_dir_abs="$(realpath -- "${dir}")"
            break
        else
            dir="$(realpath -- "${dir}/..")"
        fi
    done

    if [[ -z "${project_root_dir_abs}" ]]; then
        echo_error "You are not in an icarus build enabled directory!\n No \`${icarus_config_filename}\` file found. To enable icarus build create a \`${icarus_config_filename}\` in the project root directory."
    fi

    declare -r -g project_root_dir_abs
}

function run_isort() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    isort_summary_status="${passed}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        isort "${el}" 2>&1 || {
            isort_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function run_black() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    blackfmt_summary_status="${passed}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        black "${el}" 2>&1 || {
            blackfmt_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function run_flake8() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    flake8_summary_status="${passed}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        flake8 -v "${el}" 2>&1 || {
            flake8_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function run_mypy() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    mypy_summary_status="${passed}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        output=$(mypy "${el}" 2>&1 | tee /dev/tty) || {
            if [[ ! "${output}" =~ ^There\ are\ no\ \.py\[i\]\ files\ in\ directory ]]; then
                mypy_summary_status="${failed}"
                exit_code=1
            fi
        }
        echo
    done
}

function run_shfmt() {
    elements=("${active_dirs[@]}" "${active_sh_files[@]}")
    shfmt_summary_status="${passed}"

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        shfmt -l -w "${el}" 2>&1 || {
            shfmt_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function run_char_replacement() {
    elements=("${active_files_all[@]}")
    whitespaces_summary_status="${passed}"
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
                whitespaces_summary_status="${failed}"
                exit_code=1
            }
        else
            # Linux
            find "${el}" -type f -exec sed -i 's/ / /g' {} + 2>&1 || {
                whitespaces_summary_status="${failed}"
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
    eofnewline_summary_status="${passed}"
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
                eofnewline_summary_status="${failed}"
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
    trailing_summary_status="${passed}"

    # TODO(carlogtt): implement this tool

    echo -e "${bold_yellow}Tool not implemented yet!${end}"

    echo
}

function run_pytest() {
    pytest_summary_status="${passed}"

    pytest "${project_root_dir_abs}" 2>&1 || {
        pytest_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_gitleaks() {
    gitleaks_summary_status="${passed}"

    if gitleaks_path=$(command -v \gitleaks); then
        echo -e "${blue}git commits${end}"
        "${gitleaks_path}" git --no-banner -v 2>&1 || {
            gitleaks_summary_status="${failed}"
            exit_code=1
        }
        echo
        echo -e "${blue}git pre-commit${end}"
        "${gitleaks_path}" git --pre-commit --no-banner -v 2>&1 || {
            gitleaks_summary_status="${failed}"
            exit_code=1
        }
        echo
        echo -e "${blue}git staged${end}"
        "${gitleaks_path}" git --staged --no-banner -v 2>&1 || {
            gitleaks_summary_status="${failed}"
            exit_code=1
        }
        echo
    else
        echo_error "[NOT FOUND] gitleaks not found in PATH"
    fi
}

function parse_icarus_config() {
    echo -e "Parsing ${icarus_config_filename}"

    # BUILD-SYSTEM
    declare -a build_system_array
    IFS=' ' read -r -a build_system_array 2>/dev/null <<<"$(
        "${python3_icarus_build_env}" - <<-PY
import yaml
with open("${icarus_config}") as file:
    cfg = yaml.safe_load(file)
    section = cfg.get('build-system', [])
    try:
        runtime = str([d['runtime'] for d in section if d.get('runtime')][0])
    except IndexError:
        runtime = ''
    stdout = ' '.join([runtime]).strip()
    print(stdout)
PY
    )"
    build_system_in_use="${build_system_array[0]}"

    # BRAZIL
    declare -a build_system_brazil_array
    IFS=' ' read -r -a build_system_brazil_array 2>/dev/null <<<"$(
        "${python3_icarus_build_env}" - <<-PY
import yaml
with open("${icarus_config}") as file:
    cfg = yaml.safe_load(file)
    section = cfg.get('brazil', [])
    try:
        version = str([d['python'] for d in section if d.get('python')][0])
    except IndexError:
        version = ''
    stdout = ' '.join([version]).strip()
    print(stdout)
PY
    )"
    brazil_python_runtime="${build_system_brazil_array[0]}"

    # VENV
    declare -a build_system_venv_array
    IFS=' ' read -r -a build_system_venv_array 2>/dev/null <<<"$(
        "${python3_icarus_build_env}" - <<-PY
import yaml
with open("${icarus_config}") as file:
    cfg = yaml.safe_load(file)
    section = cfg.get('venv', [])
    try:
        name = str([d['name'] for d in section if d.get('name')][0])
    except IndexError:
        name = ''
    try:
        version = str([d['python'] for d in section if d.get('python')][0])
    except IndexError:
        version = ''
    try:
        requirements = str([d['requirements'] for d in section if d.get('requirements')][0])
    except IndexError:
        requirements = ''
    stdout = ' '.join([name, version, requirements]).strip()
    print(stdout)
PY
    )"
    venv_name="${build_system_venv_array[0]}"
    python_version_for_venv="${build_system_venv_array[1]}"
    requirements_path="${build_system_venv_array[2]}"

    # IGNORE
    declare -a -g icarus_ignore_array
    IFS=' ' read -r -a icarus_ignore_array 2>/dev/null <<<"$(
        "${python3_icarus_build_env}" - <<-PY
import yaml
with open("${icarus_config}") as file:
    cfg = yaml.safe_load(file)
    section = cfg.get('ignore', [])
    stdout = ' '.join([ignore.strip() for ignore in section]).strip()
    print(stdout)
PY
    )"
}

function validate_icarus_config() {
    echo -e "Validating ${icarus_config_filename}"

    if [[ -z "${build_system_in_use}" ]]; then
        echo_error "No build system specified in ${icarus_config_filename}"
    fi

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        if [[ -z "${brazil_python_runtime}" ]]; then
            echo_error "No python version specified in brazil ${icarus_config_filename}"
        else
            brazil_python_runtime="python${brazil_python_runtime}"
        fi
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        if [[ -z "${venv_name}" ]]; then
            echo_error "No venv name specified in venv ${icarus_config_filename}"
        fi
        if [[ -z "${python_version_for_venv}" ]]; then
            echo_error "No python version specified in venv ${icarus_config_filename}"
        fi
        if [[ -z "${requirements_path}" ]]; then
            requirements_path="requirements.txt"
            echo -e "requirements key not found in ${icarus_config_filename}, setting default requirements path to: \`${requirements_path}\`"
        fi
    else
        echo_error "Invalid build system in ${icarus_config_filename}"
    fi

    declare -r -g build_system_in_use
    declare -r -g brazil_python_runtime
    declare -r -g venv_name
    declare -r -g python_version_for_venv
    declare -r -g requirements_path
    declare -r -g icarus_ignore_array
}

function build_active_dirs_l1() {
    local -a all_dirs_l1
    all_dirs_l1=($(find "${project_root_dir_abs}" -mindepth 1 -maxdepth 1 -type d))

    for dir in "${all_dirs_l1[@]}"; do
        unset ignore_dir

        for ignored in "${icarus_ignore_array[@]}"; do
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
    local -a all_files_l1
    all_files_l1=($(find "${project_root_dir_abs}" -mindepth 1 -maxdepth 1 -type f))

    for file in "${all_files_l1[@]}"; do
        unset ignore_file

        for ignored in "${icarus_ignore_array[@]}"; do
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
    local -a all_files
    all_files=($(find "${project_root_dir_abs}" -type f))

    for file in "${all_files[@]}"; do
        unset ignore_file

        for ignored in "${icarus_ignore_array[@]}"; do
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

function set_runtime_info() {
    # Set runtime to be used in summary
    local path_to_env_bin="${1}"
    local venv_print_name=""

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        venv_print_name="(Brazil ENV)"
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        venv_print_name="(${venv_name})"
    fi

    runtime="${bold_blue}Runtime:${end} \
        \n--| project ${project_root_dir_abs} \
        \n--| brazil env $(realpath -- ${path_to_env_bin}/..) \
        \n--| venv ${venv_print_name} \
        \n--| $(${path_to_env_bin}/python3 --version)"
}

function build_brazil_env() {
    brazil ws sync --md || exit 1

    # Use brazil runtime farm to activate brazil runtime env
    local brazil_bin_dir="$(brazil-path testrun.runtimefarm)/${brazil_python_runtime}/bin"

    # Set runtime to be used in summary
    set_runtime_info "${brazil_bin_dir}"
}

function build_venv_env() {
    local path_to_venv_root="${project_root_dir_abs}/${venv_name}"

    echo -e "\n${bold_green}${green_check_mark} Preparing building '${venv_name}' venv...${end}"

    # Create Local venv
    echo -e "\n\n${bold_green}${sparkles} Creating '${venv_name}' venv...${end}"
    python${python_version_for_venv} -m venv --clear --copies "${path_to_venv_root}" && echo -e "done!"

    # Activate local venv
    . "${path_to_venv_root}/bin/activate"
    echo -e "\n\n${bold_green}${green_check_mark} '${venv_name}' venv activated:${end}"
    echo -e "OS Version: $(uname)"
    echo -e "Kernel Version: $(uname -r)"
    echo -e "venv: $VIRTUAL_ENV"
    echo -e "running: $(python --version)"

    # Install requirements
    echo -e "\n\n${bold_green}${sparkles} Installing requirements into '${venv_name}' venv...${end}"
    pip install --upgrade pip
    pip install -I -r "${project_root_dir_abs}/${requirements_path}"

    # Build complete!
    echo -e "\n\n${bold_green}${sparkles} '${venv_name}' venv build complete & Ready for use!${end}"

    echo -e "\n\n${bold_yellow}Virtual environment deactivated!${end}"
    echo
    deactivate

    # Set runtime to be used in summary
    set_runtime_info "${path_to_venv_root}/bin"
}

function activate_brazil_env() {
    # Use brazil runtime farm to activate brazil runtime env
    local brazil_bin_dir="$(brazil-path testrun.runtimefarm 2>/dev/null)/${brazil_python_runtime}/bin"
    OLD_PATH="${PATH}"
    PATH="${brazil_bin_dir}:${PATH}"

    # Set runtime to be used in summary
    set_runtime_info "${brazil_bin_dir}"

    # Display Project info
    echo -e "${bold_green}${hammer_and_wrench} Project Root:${end}"
    echo "${project_root_dir_abs}"
    # Display env info
    echo -e "\n${bold_green}${green_check_mark} Virtual environment activated:${end}"
    echo -e "brazil env: $(realpath -- ${brazil_bin_dir}/..)"
    echo -e "OS Version: $(uname)"
    echo -e "Kernel Version: $(uname -r)"
    echo -e "running: $(python3 --version)"
    echo
}

function activate_venv_env() {
    local path_to_venv_root="${project_root_dir_abs}/${venv_name}"

    if [[ ! -e "${path_to_venv_root}/bin/activate" ]]; then
        echo_error "Cannot find the requested venv: \`${venv_name}\` to activate!\n venv: ${path_to_venv_root}"
    fi

    # Activate venv
    . "${path_to_venv_root}/bin/activate"

    # Set runtime to be used in summary
    set_runtime_info "${path_to_venv_root}/bin"

    # Display Project info
    echo -e "${bold_green}${hammer_and_wrench} Project Root:${end}"
    echo "${project_root_dir_abs}"
    # Display env info
    echo -e "\n${bold_green}${green_check_mark} Virtual environment activated:${end}"
    echo -e "venv: ${VIRTUAL_ENV}"
    echo -e "OS Version: $(uname)"
    echo -e "Kernel Version: $(uname -r)"
    echo -e "running: $(python3 --version)"
    echo
}

function deactivate_brazil_env() {
    PATH="${OLD_PATH}"
    echo -e "Virtual environment deactivated!"
    echo
    echo
}

function deactivate_venv_env() {
    deactivate
    echo -e "Virtual environment deactivated!"
    echo
    echo
}

function activate_env() {
    if [[ "${build_system_in_use}" == "brazil" ]]; then
        activate_brazil_env
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        activate_venv_env
    fi
}

function deactivate_env() {
    if [[ "${build_system_in_use}" == "brazil" ]]; then
        deactivate_brazil_env
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        deactivate_venv_env
    fi
}

function dispatch_preflight_tools() {
    build_active_dirs_l1
    build_active_files_l1
    build_all_active_files

    echo_title "Project info"
    activate_env

    if [[ "${isort}" == "Y" ]]; then
        echo_title "Running iSort"
        run_isort
    fi

    if [[ "${blackfmt}" == "Y" ]]; then
        echo_title "Running Black"
        run_black
    fi

    if [[ "${flake8}" == "Y" ]]; then
        echo_title "Running Flake8"
        run_flake8
    fi

    if [[ "${mypy}" == "Y" ]]; then
        echo_title "Running mypy"
        run_mypy
    fi

    if [[ "${shfmt}" == "Y" ]]; then
        echo_title "Running shfmt (bash formatter)"
        run_shfmt
    fi

    if [[ "${whitespaces}" == "Y" ]]; then
        echo_title "Running 'NNBSP' char replacement"
        run_char_replacement
    fi

    if [[ "${trailing}" == "Y" ]]; then
        echo_title "Running trailing-whitespaces"
        run_trailingwhitespaces
    fi

    if [[ "${eofnewline}" == "Y" ]]; then
        echo_title "Running eof-newline"
        run_eofnewline
    fi

    if [[ "${gitleaks}" == "Y" ]]; then
        echo_title "Running gitleaks"
        run_gitleaks
    fi

    if [[ "${pytest}" == "Y" ]]; then
        echo_title "Running pytest"
        run_pytest
    fi

    echo_title "Deactivating virtual environment"
    deactivate_env
}

function dispatch_build() {
    build_summary_status="${passed}"

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        echo_title "Building brazil"
        build_brazil_env || {
            build_summary_status="${failed}"
            exit_code=1
        }
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        echo_title "Building venv"
        build_venv_env || {
            build_summary_status="${failed}"
            exit_code=1
        }
    fi
}

function parse_args() {
    if [[ "${1}" == "--isort" ]]; then
        isort="Y"
    fi

    if [[ "${2}" == "--black" ]]; then
        blackfmt="Y"
    fi

    if [[ "${3}" == "--flake8" ]]; then
        flake8="Y"
    fi

    if [[ "${4}" == "--mypy" ]]; then
        mypy="Y"
    fi

    if [[ "${5}" == "--shfmt" ]]; then
        shfmt="Y"
    fi

    if [[ "${6}" == "--whitespaces" ]]; then
        whitespaces="Y"
    fi

    if [[ "${7}" == "--eofnewline" ]]; then
        eofnewline="Y"
    fi

    if [[ "${8}" == "--trailing" ]]; then
        trailing="Y"
    fi

    if [[ "${9}" == "--gitleaks" ]]; then
        gitleaks="Y"
    fi

    if [[ "${10}" == "--pytest" ]]; then
        pytest="Y"
    fi

    if [[ "${11}" == "--build" ]]; then
        build="Y"
    fi

    if [[ "${12}" == "--release" ]]; then
        build="Y"
        isort="Y"
        blackfmt="Y"
        flake8="Y"
        mypy="Y"
        shfmt="Y"
        whitespaces="Y"
        eofnewline="Y"
        trailing="Y"
        pytest="Y"
        gitleaks="Y"
    fi

    if [[ "${13}" == "--format" ]]; then
        isort="Y"
        blackfmt="Y"
        flake8="Y"
        mypy="Y"
        shfmt="Y"
        whitespaces="Y"
        eofnewline="Y"
        trailing="Y"
    fi

    if [[ "${13}" == "--test" ]]; then
        pytest="Y"
    fi

    for hook in "${forge_hooks[@]}"; do
        if [[ "${!hook}" == "Y" ]]; then
            running_hooks_name+=("${hook}")
            ((running_hooks_count = running_hooks_count + 1))
        fi
    done
    declare -r -g running_hooks_name

    if [[ "${running_hooks_count}" -eq 0 ]]; then
        echo_error "No arguments provided!"
    fi
}

function dispatch_hooks() {
    echo_running_hooks

    if [[ "${11}" =~ "--build" ]]; then
        dispatch_build
    elif [[ "${12}" =~ "--release" ]]; then
        dispatch_build
        dispatch_preflight_tools
    else
        dispatch_preflight_tools
    fi

    echo_summary
}

function set_constants() {
    icarus_config_filename="icarus.cfg"
    find_project_root
    icarus_config="$(realpath -- "${project_root_dir_abs}/${icarus_config_filename}")"

    exit_code=0

    running_hooks_count=0
    declare -a -g running_hooks_name=()

    declare -a -g active_dirs=()
    declare -a -g active_py_files=()
    declare -a -g active_sh_files=()
    declare -a -g active_other_files=()
    declare -a -g active_files_all=()

    python3_icarus_build_env="$(realpath -- "${cli_scripts_dir_abs}/../build_venv/bin/python3")"

    passed="${bold_black}${bg_green} PASS ${end}"
    skipped="${bold_black}${bg_white} SKIP ${end}"
    failed="${bold_black}${bg_red} FAIL ${end}"

    forge_hooks=(
        "build"
        "isort"
        "blackfmt"
        "flake8"
        "mypy"
        "shfmt"
        "whitespaces"
        "trailing"
        "eofnewline"
        "gitleaks"
        "pytest"
    )

    build="N"
    isort="N"
    blackfmt="N"
    flake8="N"
    mypy="N"
    shfmt="N"
    whitespaces="N"
    trailing="N"
    eofnewline="N"
    gitleaks="N"
    pytest="N"

    build_summary_status="${skipped}"
    isort_summary_status="${skipped}"
    blackfmt_summary_status="${skipped}"
    flake8_summary_status="${skipped}"
    mypy_summary_status="${skipped}"
    shfmt_summary_status="${skipped}"
    whitespaces_summary_status="${skipped}"
    trailing_summary_status="${skipped}"
    eofnewline_summary_status="${skipped}"
    gitleaks_summary_status="${skipped}"
    pytest_summary_status="${skipped}"
}

function main() {
    set_constants

    echo_title "${icarus_config_filename}"
    parse_icarus_config
    validate_icarus_config

    parse_args "${@}"
    dispatch_hooks "${@}"

    return "${exit_code}"
}

main "${@}"
