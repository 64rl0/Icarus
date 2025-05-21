#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/build.sh
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
    local message="${1}"

    echo
    echo -e "${bold_black}${bg_red} ERROR! ${end}"
    echo -e " [$(date '+%Y-%m-%d %T %Z')]"
    echo -e " ${message}"
    echo

    return 1
}

function validate_command() {
    local command_to_validate="${1}"
    if [[ -z "$(command -v "${command_to_validate}" 2>/dev/null)" ]]; then
        echo_error "[NOT FOUND] \`${command_to_validate}\` not found in PATH"
    fi
}

function validate_prerequisites() {
    # Validate we are not running the prod script on this dev env to prevent special formatting
    # of this script
    if [[ "${PWD}" =~ _Projects\/Icarus && ! "${BASH_SOURCE[0]}" =~ _Projects\/Icarus\/ ]]; then
        echo_error "You are not supposed to run production icarus in the icarus development environment"
    fi

    validate_command "bc"
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
    local execution_time=""
    local execution_time_total=0
    local execution_time_partial=""
    local tool=""
    local tet=""

    echo_title "Icarus Builder Build Summary"
    echo -e "${bold_blue}Command:${end}\n--| ${initial_command_received}"
    echo
    echo -e "${runtime}"
    echo

    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    printf "%-41s | %-7s | %-7s\n" "${bold_white}Tool${end}" "${bold_white}Status${end}" "${bold_white}Timings${end}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    for hook in "${build_hooks[@]}"; do
        tool="$(printf '%s' "${hook} ..................................." | cut -c1-30)"
        eval status='$'"${hook}_summary_status"
        if [[ "${status}" == "${skipped}" ]]; then
            continue
        fi
        eval execution_time='$'"${hook}_execution_time"
        if [[ -n "${execution_time}" ]]; then
            execution_time="$(printf "%.3f" "${execution_time}")s"
        fi
        printf "%-30s | %-7s | %-7s\n" "${tool}" "${status}" "${execution_time}"
    done
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    for hook in "${build_hooks[@]}"; do
        eval execution_time_partial='$'"${hook}_execution_time"
        execution_time_partial="$(printf "%.3f" "${execution_time_partial}")"
        execution_time_total="$(echo "${execution_time_total} + ${execution_time_partial}" | bc)"
    done
    if (($(echo "${execution_time_total} > 60" | bc))); then
        execution_time_total="$(echo "${execution_time_total} / 60" | bc -l)"
        execution_time_total="$(printf "%.3f" "${execution_time_total}")m"
    else
        execution_time_total="$(printf "%.3f" "${execution_time_total}")s"
    fi
    tet="$(printf '%s' "total-execution-time ..................................." | cut -c1-39)"
    printf "%-30s | %-7s\n" "${tet}" "${execution_time_total}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"

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

    validate_command "isort" || {
        isort_summary_status="${failed}"
        exit_code=1
        return
    }

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
    black_summary_status="${passed}"

    validate_command "black" || {
        black_summary_status="${failed}"
        exit_code=1
        return
    }

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        black "${el}" 2>&1 || {
            black_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function run_flake8() {
    elements=("${active_dirs[@]}" "${active_py_files[@]}")
    flake8_summary_status="${passed}"

    validate_command "flake8" || {
        flake8_summary_status="${failed}"
        exit_code=1
        return
    }

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

    validate_command "mypy" || {
        mypy_summary_status="${failed}"
        exit_code=1
        return
    }

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

    validate_command "shfmt" || {
        shfmt_summary_status="${failed}"
        exit_code=1
        return
    }

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
            find "${el}" -type f -exec sed -i '' 's/ / /g' {} + 2>&1 || {
                whitespaces_summary_status="${failed}"
                exit_code=1
            }
        else
            # Linux
            find "${el}" -type f -exec sed -i 's/ / /g' {} + 2>&1 || {
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
        if [[ $(tail -c 1 -- "${el}" | od -An -tu1) -ne 10 ]]; then
            echo "Fixing: ${el}"
            echo "EOF char is: $(tail -c1 -- "${el}")"
            echo
            printf '\n' >>"${el}" || {
                eofnewline_summary_status="${failed}"
                exit_code=1
            }
            ((counter = counter + 1))
        else
            while true; do
                if [[ $(tail -c 2 -- "${el}" | head -c 1 | od -An -tu1) -eq 10 ]]; then
                    if [[ "${entered}" != true ]]; then
                        local entered=true
                        echo "Fixing: ${el}"
                        echo "Removing extra EOF new-lines"
                        echo
                        ((counter = counter + 1))
                    fi
                    truncate -s -1 -- "${el}" || {
                        eofnewline_summary_status="failed"
                        exit_code=1
                    }
                else
                    break
                fi
            done
        fi
    done

    echo -e "Fixed ${counter} file(s)"
    echo
}

function run_trailingwhitespaces() {
    elements=("${active_files_all[@]}")
    trailing_summary_status="${passed}"

    {
        # TODO(carlogtt): implement this tool
        echo -e "${bold_yellow}Tool not implemented yet!${end}"
        echo
    } || {
        trailing_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_gitleaks() {
    gitleaks_summary_status="${passed}"

    validate_command "gitleaks" || {
        gitleaks_summary_status="${failed}"
        exit_code=1
        return
    }

    echo -e "${blue}git pre-commit${end}"
    gitleaks git --pre-commit --no-banner -v 2>&1 || {
        gitleaks_summary_status="${failed}"
        exit_code=1
    }
    echo

    echo -e "${blue}git staged${end}"
    gitleaks git --staged --no-banner -v 2>&1 || {
        gitleaks_summary_status="${failed}"
        exit_code=1
    }
    echo

    echo -e "${blue}git commits${end}"
    gitleaks git --no-banner -v 2>&1 || {
        gitleaks_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_brazil_documentation() {
    brazil-build amazon_doc_utils_build_sphinx || {
        docs_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_venv_documentation() {
    validate_command "sphinx-apidoc" || {
        docs_summary_status="${failed}"
        exit_code=1
        return
    }

    validate_command "sphinx-build" || {
        docs_summary_status="${failed}"
        exit_code=1
        return
    }

    if [[ ! -d "${project_root_dir_abs}/docs" ]]; then
        docs_summary_status="${failed}"
        exit_code=1
        echo_error "No \`${project_root_dir_abs}/docs\` directory found.\n To enable documentation create a \`docs\` directory in the project root directory." || :
        return
    fi

    {
        # Cleaning docs env
        rm -rf "${project_root_dir_abs}/docs/_apidoc"
        rm -rf "${project_root_dir_abs}/docs/html"

        # Generating Sphinx sources
        sphinx-apidoc -d 1000 --separate --module-first -o "${project_root_dir_abs}/docs/_apidoc" "${project_root_dir_abs}/src"

        # Generating HTML docs
        sphinx-build -v --fail-on-warning --builder html "${project_root_dir_abs}/docs" "${project_root_dir_abs}/docs/html"
    } || {
        docs_summary_status="${failed}"
        exit_code=1
    }

    # Cleaning not needed build dirs
    rm -rf "${project_root_dir_abs}/docs/html/.doctrees"
    rm -rf "${project_root_dir_abs}/docs/html/.buildinfo"

    echo
    echo "Open the HTML pages"
    echo "${yellow}file://${project_root_dir_abs}/docs/html/index.html${end}"
    echo
}

function run_documentation() {
    docs_summary_status="${passed}"

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        run_brazil_documentation
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        run_venv_documentation
    fi
}

function run_brazil_pytest() {
    brazil-build brazil_test || {
        pytest_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_venv_pytest() {
    echo -e "Preparing tests"
    echo

    validate_command "pytest" || {
        pytest_summary_status="${failed}"
        exit_code=1
        return
    }

    pytest "${project_root_dir_abs}" 2>&1 || {
        pytest_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_pytest() {
    pytest_summary_status="${passed}"

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        run_brazil_pytest
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        run_venv_pytest
    fi
}

convert_to_snake_case() {
    local input_str="$1"

    # Remove leading and trailing whitespace
    local sanitized_input_str=$(echo "${input_str}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Validate input: only alphanumeric characters are allowed
    if ! [[ "${sanitized_input_str}" =~ ^[a-zA-Z0-9]+$ ]]; then
        echo ""
        return
    fi

    # Convert camelCase to snake_case
    local snake_case_str=$(echo "${sanitized_input_str}" | sed -r 's/([0-9]+)/_\1_/g; s/([a-z])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]' | sed -r 's/__/_/g; s/^_+|_+$//g')

    # Output the snake_case string
    echo "${snake_case_str}"
}

function parse_icarus_config() {
    echo -e "Parsing ${icarus_config_filename}"

    # PROJECT
    declare -a project_array
    IFS=' ' read -r -a project_array 2>/dev/null <<<"$(
        "${python3_icarus_build_env}" - <<-PY
import yaml
with open("${icarus_config}") as file:
    cfg = yaml.safe_load(file)
    section = cfg.get('project', [])
    try:
        proj_name = str([d['name'] for d in section if d.get('name')][0])
    except IndexError:
        proj_name = ''
    stdout = ' '.join([proj_name]).strip()
    print(stdout)
PY
    )"
    project_name_pascal_case="${project_array[0]}"

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

    if [[ -z "${project_name_pascal_case}" ]]; then
        echo_error "No project name specified in ${icarus_config_filename}"
    else
        project_name_snake_case=$(convert_to_snake_case "${project_name_pascal_case}")
        project_name_snake_case_dashed="$(echo "${project_name_snake_case}" | sed 's/_/-/g')"
    fi

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

    declare -r -g project_name_pascal_case
    declare -r -g project_name_snake_case
    declare -r -g project_name_snake_case_dashed
    declare -r -g build_system_in_use
    declare -r -g brazil_python_runtime
    declare -r -g venv_name
    declare -r -g python_version_for_venv
    declare -r -g requirements_path
    declare -r -g icarus_ignore_array
}

function process_icarus_config() {
    echo_title "Processing ${icarus_config_filename}"

    parse_icarus_config
    validate_icarus_config

    echo
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
        \n--| project ${project_name_pascal_case} \
        \n--| ${project_root_dir_abs} \
        \n--| brazil env $(realpath -- ${path_to_env_bin}/..) \
        \n--| venv ${venv_print_name} \
        \n--| $(${path_to_env_bin}/python3 --version)"
}

function build_brazil_env() {
    # We don't want to suppress this error
    brazil ws sync --md || exit 1

    {
        # Use brazil runtime farm to activate brazil runtime env
        local brazil_bin_dir="$(brazil-path testrun.runtimefarm)/${brazil_python_runtime}/bin"

        # Set runtime to be used in summary
        set_runtime_info "${brazil_bin_dir}"
    } || {
        build_summary_status="${failed}"
        exit_code=1
    }
}

function build_venv_env() {
    {
        local path_to_venv_root="${project_root_dir_abs}/${venv_name}"

        echo -e "${bold_green}${green_check_mark} Preparing building '${venv_name}' venv...${end}"

        # Create Local venv
        echo -e "\n\n${bold_green}${sparkles} Creating '${venv_name}' venv...${end}"
        python${python_version_for_venv} -m venv --clear --copies "${path_to_venv_root}" && echo -e "done!"

        # Activate local venv silently
        . "${path_to_venv_root}/bin/activate"

        # Install pip and update
        echo -e "\n\n${bold_green}${sparkles} Updating pip...${end}"
        pip install --upgrade pip

        # Install requirements
        echo -e "\n\n${bold_green}${sparkles} Installing requirements into '${venv_name}' venv...${end}"
        pip install -I -r "${project_root_dir_abs}/${requirements_path}"

        # Cleanup pre
        echo -e "\n\n${bold_green}${broom} Cleaning up...${end}"
        rm -rf "${project_root_dir_abs}/dist/"
        rm -rf "${project_root_dir_abs}/src/"*".egg-info"
        echo -e "cleanup completed"

        # Building local package
        echo -e "\n\n${bold_green}${hammer_and_wrench}  Building '${project_root_dir_abs}'...${end}"
        python3 -m build "${project_root_dir_abs}"
        echo -e "\n\n${bold_green}${package} Checking package health${end}"
        twine check "${project_root_dir_abs}/dist/"*.whl

        # Install local package into venv (as last so it will override the same name)
        echo -e "\n\n${bold_green}${sparkles} Installing '${project_root_dir_abs}' into '${venv_name}' venv...${end}"
        pip install -I "${project_root_dir_abs}/dist/"*.whl

        # Cleanup post
        echo -e "\n\n${bold_green}${broom} Cleaning up...${end}"
        rm -rf "${project_root_dir_abs}/dist/"
        rm -rf "${project_root_dir_abs}/src/"*".egg-info"
        echo -e "cleanup completed"

        # Build complete!
        echo -e "\n\n${bold_green}${sparkles} '${venv_name}' venv build complete & Ready for use!${end}"

        # Deactivate virtual env silently
        deactivate

        # Set runtime to be used in summary
        set_runtime_info "${path_to_venv_root}/bin"
    } || {
        build_summary_status="${failed}"
        exit_code=1
    }
}

function clean_brazil_env() {
    brazil-build clean || {
        clean_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function clean_venv_env() {
    rm -rf "${project_root_dir_abs}/dist/" || {
        clean_summary_status="${failed}"
        exit_code=1
        return
    }

    rm -rf "${project_root_dir_abs}/src/"*".egg-info" || {
        clean_summary_status="${failed}"
        exit_code=1
        return
    }

    rm -rf "${project_root_dir_abs}/${venv_name}" || {
        clean_summary_status="${failed}"
        exit_code=1
        return
    }

    echo -e "Virtual environment '${venv_name}' cleaned!"
    echo
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
}

function deactivate_venv_env() {
    deactivate
    echo -e "Virtual environment deactivated!"
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

function exec_brazil() {
    echo_title "Running exec"
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_exec_command_receive[*]}"
    echo

    brazil-test-exec "${initial_exec_command_receive[@]}" || {
        exec_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function exec_venv() {
    echo_title "Project info"
    activate_env

    echo_title "Running exec"
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_exec_command_receive[*]}"
    echo

    "${initial_exec_command_receive[@]}" || {
        exec_summary_status="${failed}"
        exit_code=1
    }
    echo

    echo_title "Deactivating virtual environment"
    deactivate_env
}

function dispatch_build() {
    build_summary_status="${passed}"

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        echo_title "Building brazil"
        build_brazil_env
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        echo_title "Building venv"
        build_venv_env
    fi
}

function dispatch_clean() {
    clean_summary_status="${passed}"
    start_block=$(date +%s.%N)

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        echo_title "Cleaning brazil"
        clean_brazil_env
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        echo_title "Cleaning venv"
        clean_venv_env
    fi

    end_block=$(date +%s.%N)
    clean_execution_time=$(echo "${end_block} - ${start_block}" | bc)
}

function dispatch_exec() {
    exec_summary_status="${passed}"
    start_block=$(date +%s.%N)

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        exec_brazil
    elif [[ "${build_system_in_use}" == "venv" ]]; then
        exec_venv
    fi

    end_block=$(date +%s.%N)
    exec_execution_time=$(echo "${end_block} - ${start_block}" | bc)
}

function dispatch_tools() {
    # Build must stay at the top to be run as first if enabled
    if [[ "${build}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        dispatch_build
        end_block=$(date +%s.%N)
        build_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    build_active_dirs_l1
    build_active_files_l1
    build_all_active_files

    echo_title "Project info"
    activate_env

    if [[ "${isort}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running iSort"
        run_isort
        end_block=$(date +%s.%N)
        isort_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${black}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running Black"
        run_black
        end_block=$(date +%s.%N)
        black_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${flake8}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running Flake8"
        run_flake8
        end_block=$(date +%s.%N)
        flake8_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${mypy}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running mypy"
        run_mypy
        end_block=$(date +%s.%N)
        mypy_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${shfmt}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running shfmt (bash formatter)"
        run_shfmt
        end_block=$(date +%s.%N)
        shfmt_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${whitespaces}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Replacing non-breaking-space (NBSP) characters"
        run_char_replacement
        end_block=$(date +%s.%N)
        whitespaces_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${trailing}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running trailing-whitespaces"
        run_trailingwhitespaces
        end_block=$(date +%s.%N)
        trailing_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eofnewline}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running eof-newline"
        run_eofnewline
        end_block=$(date +%s.%N)
        eofnewline_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${gitleaks}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running gitleaks"
        run_gitleaks
        end_block=$(date +%s.%N)
        gitleaks_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${pytest}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running pytest"
        run_pytest
        end_block=$(date +%s.%N)
        pytest_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${docs}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Generating documentation"
        run_documentation
        end_block=$(date +%s.%N)
        docs_execution_time=$(echo "${end_block} - ${start_block}" | bc)
    fi

    echo_title "Deactivating virtual environment"
    deactivate_env
}

function parse_args() {
    if [[ "${1}" == "--isort" ]]; then
        isort="Y"
    fi

    if [[ "${2}" == "--black" ]]; then
        black="Y"
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

    if [[ "${7}" == "--trailing" ]]; then
        trailing="Y"
    fi

    if [[ "${8}" == "--eofnewline" ]]; then
        eofnewline="Y"
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

    if [[ "${12}" == "--docs" ]]; then
        docs="Y"
    fi

    if [[ "${13}" == "--clean" ]]; then
        clean="Y"
    fi

    if [[ "${14}" == "--release" ]]; then
        build="Y"
        isort="Y"
        black="Y"
        flake8="Y"
        mypy="Y"
        shfmt="Y"
        whitespaces="Y"
        trailing="Y"
        eofnewline="Y"
        pytest="Y"
        gitleaks="Y"
        docs="Y"
    fi

    if [[ "${15}" == "--format" ]]; then
        isort="Y"
        black="Y"
        flake8="Y"
        mypy="Y"
        shfmt="Y"
        whitespaces="Y"
        trailing="Y"
        eofnewline="Y"
    fi

    if [[ "${16}" == "--test" ]]; then
        pytest="Y"
    fi

    if [[ "${17}" =~ ^--exec ]]; then
        exec="Y"
        read -r -a initial_exec_command_receive <<<"$(echo "${17}")"
        initial_exec_command_receive=("${initial_exec_command_receive[@]:1}")
        declare -r -g initial_exec_command_receive
    fi

    for hook in "${build_hooks[@]}"; do
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

    if [[ "${13}" == "--clean" ]]; then
        # Clean must be run alone
        for arg in "${@}"; do
            if [[ "${arg}" != "--clean" && "${arg}" != "" ]]; then
                echo_error "Cannot run \`clean\` with other arguments!"
            fi
        done
        dispatch_clean
    elif [[ "${17}" =~ ^--exec ]]; then
        # Exec must be run alone
        for arg in "${@}"; do
            if [[ ! "${arg}" =~ --exec && "${arg}" != "" ]]; then
                echo_error "Cannot run \`exec\` with other arguments!"
            fi
        done
        dispatch_exec
    else
        dispatch_tools
    fi

    echo_summary
}

function set_constants() {
    icarus_config_filename="icarus.cfg"
    find_project_root
    icarus_config="$(realpath -- "${project_root_dir_abs}/${icarus_config_filename}")"

    exit_code=0

    initial_command_received="icarus builder build"
    for arg in "${@}"; do
        if [[ "${arg}" != "" ]]; then
            initial_command_received+=" ${arg}"
        fi
    done
    declare -r -g initial_command_received

    declare -a -g initial_exec_command_receive=()

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

    build_hooks=(
        "build"
        "clean"
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
        "docs"
        "exec"
    )

    build="N"
    clean="N"
    isort="N"
    black="N"
    flake8="N"
    mypy="N"
    shfmt="N"
    whitespaces="N"
    trailing="N"
    eofnewline="N"
    gitleaks="N"
    pytest="N"
    docs="N"
    exec="N"

    build_summary_status="${skipped}"
    clean_summary_status="${skipped}"
    isort_summary_status="${skipped}"
    black_summary_status="${skipped}"
    flake8_summary_status="${skipped}"
    mypy_summary_status="${skipped}"
    shfmt_summary_status="${skipped}"
    whitespaces_summary_status="${skipped}"
    trailing_summary_status="${skipped}"
    eofnewline_summary_status="${skipped}"
    gitleaks_summary_status="${skipped}"
    pytest_summary_status="${skipped}"
    docs_summary_status="${skipped}"
    exec_summary_status="${skipped}"

    build_execution_time=""
    clean_excecution_time=""
    isort_execution_time=""
    black_execution_time=""
    flake8_execution_time=""
    mypy_execution_time=""
    shfmt_execution_time=""
    whitespaces_execution_time=""
    trailing_execution_time=""
    eofnewline_execution_time=""
    gitleaks_execution_time=""
    pytest_execution_time=""
    docs_execution_time=""
    exec_execution_time=""
}

function main() {
    validate_prerequisites
    set_constants "${@}"

    process_icarus_config

    parse_args "${@}"
    dispatch_hooks "${@}"

    return "${exit_code}"
}

main "${@}"
