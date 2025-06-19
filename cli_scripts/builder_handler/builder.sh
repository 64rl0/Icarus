#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/builder.sh
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

####################################################################################################
# SYSTEM
####################################################################################################
function validate_command() {
    local command_to_validate="${1}"
    if [[ -z "$(command -v "${command_to_validate}" 2>/dev/null)" ]]; then
        echo_error "[NOT FOUND] \`${command_to_validate}\` not found in PATH" "errexit"
    fi
}

function validate_prerequisites() {
    # Validate we are not running the prod script on this dev env to prevent special formatting
    # of this script
    if [[ "${PWD}" =~ _Projects\/Icarus && ! "${BASH_SOURCE[0]}" =~ _Projects\/Icarus\/ ]]; then
        echo_error "You are not supposed to run production ${cli_name} in the ${cli_name} development environment" "errexit"
    fi

    validate_command "bc"

    echo
}

function echo_title() {
    local title="${1}"
    local header_mode="${2}"

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
    if [[ "${header_mode}" == "header" ]]; then
        echo -e "${bold_black}${bg_white}${left_pad} ${title} ${right_pad}${end}"
    else
        echo -e "${bold_white}${left_pad} ${title} ${right_pad}${end}"
        echo_time ""
        echo
    fi
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
    local python_versions_pretty=""

    for python_version_composite in "${python_versions[@]}"; do
        python_versions_pretty+="Python$(echo "${python_version_composite}" | cut -d ':' -f 2) "
    done

    local runtime="${bold_blue}Runtime:${end} \
        \n--| Package ${bold_green}${package_name_pascal_case}${end} \
        \n--| ${project_root_dir_abs} \
        \n--| Interpreters enabled ${bold_green}${python_versions_pretty}${end} \
        \n--| Interpreter default ${bold_green}Python${python_default_version}${end}"

    echo_title "Icarus Builder Build Summary"
    echo -e "${bold_blue}Command:${end}\n--| ${initial_command_received}"
    echo
    echo -e "${runtime}"
    echo

    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    printf "%-41s | %-7s | %-7s\n" "${bold_white}Tool${end}" "${bold_white}Status${end}" "${bold_white}Timings${end}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    for hook in "${running_hooks_name[@]}"; do
        tool="$(printf '%s' "${hook} ..................................." | cut -c1-30)"
        eval status='$'"${hook}_summary_status"
        eval execution_time='$'"${hook}_execution_time"
        if (($(echo "${execution_time} > 60" | bc))); then
            execution_time="$(echo "${execution_time} / 60" | bc -l)"
            execution_time="$(printf "%.3f" "${execution_time}")m"
        else
            execution_time="$(printf "%.3f" "${execution_time}")s"
        fi
        printf "%-30s | %-6s | %-7s\n" "${tool}" "${status}" "${execution_time}"
    done
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    for hook in "${running_hooks_name[@]}"; do
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

####################################################################################################
# CONSTANTS
####################################################################################################
function set_constants() {
    echo_title "Analyzing icarus.cfg"

    echo -e "Reading constants"
    eval "${@}"

    declare -r -g all_hooks
    declare -r -g icarus_config_filename
    declare -r -g icarus_config_filepath
    declare -r -g project_root_dir_abs
    declare -r -g package_name_pascal_case
    declare -r -g package_name_snake_case
    declare -r -g package_name_dashed
    declare -r -g package_language
    declare -r -g build_system_in_use
    declare -r -g platform_identifier
    declare -r -g python_version_default_for_brazil
    declare -r -g python_versions_for_brazil
    declare -r -g build_env_dir_name
    declare -r -g python_version_default_for_icarus
    declare -r -g python_versions_for_icarus
    declare -r -g requirements_paths
    declare -r -g icarus_ignore_array
    declare -r -g build
    declare -r -g is_only_build_hook
    declare -r -g clean
    declare -r -g isort
    declare -r -g black
    declare -r -g flake8
    declare -r -g mypy
    declare -r -g shfmt
    declare -r -g whitespaces
    declare -r -g eolnorm
    declare -r -g trailing
    declare -r -g eofnewline
    declare -r -g gitleaks
    declare -r -g pytest
    declare -r -g docs
    declare -r -g exec
    declare -r -g initial_command_received
    declare -r -g initial_exec_command_received
    declare -r -g running_hooks_name
    declare -r -g running_hooks_count
    declare -r -g python_default_version
    declare -r -g python_default_full_version
    declare -r -g python_versions

    exit_code=0

    passed="${bold_black}${bg_green} PASS ${end}"
    failed="${bold_black}${bg_red} FAIL ${end}"

    build_summary_status="${passed}"
    clean_summary_status="${passed}"
    isort_summary_status="${passed}"
    black_summary_status="${passed}"
    flake8_summary_status="${passed}"
    mypy_summary_status="${passed}"
    shfmt_summary_status="${passed}"
    whitespaces_summary_status="${passed}"
    eolnorm_summary_status="${passed}"
    trailing_summary_status="${passed}"
    eofnewline_summary_status="${passed}"
    gitleaks_summary_status="${passed}"
    pytest_summary_status="${passed}"
    docs_summary_status="${passed}"
    exec_summary_status="${passed}"

    build_execution_time=0
    clean_execution_time=0
    isort_execution_time=0
    black_execution_time=0
    flake8_execution_time=0
    mypy_execution_time=0
    shfmt_execution_time=0
    whitespaces_execution_time=0
    eolnorm_execution_time=0
    trailing_execution_time=0
    eofnewline_execution_time=0
    gitleaks_execution_time=0
    pytest_execution_time=0
    docs_execution_time=0
    exec_execution_time=0

    declare -a -g active_dirs=()
    declare -a -g active_py_files=()
    declare -a -g active_sh_files=()
    declare -a -g active_other_files=()
    declare -a -g active_files_all=()

    echo -e "Walking package root"
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

    echo
}

function set_python_constants() {
    python_version="$(echo "${1}" | cut -d ':' -f 1)"
    python_full_version="$(echo "${1}" | cut -d ':' -f 2)"

    path_to_cache_root="${project_root_dir_abs}/${build_env_dir_name}/cache"
    path_to_runtime_root="${project_root_dir_abs}/${build_env_dir_name}/runtime/${platform_identifier}"
    path_to_env_root="${project_root_dir_abs}/${build_env_dir_name}/env/${platform_identifier}/CPython/${python_full_version}"
    path_to_wheel_root="${project_root_dir_abs}/${build_env_dir_name}/wheel/${package_name_snake_case}/${platform_identifier}/CPython/${python_full_version}"

    python_pkg_name="cpython-${python_full_version}-${platform_identifier}"
    python_pkg_full_name="${python_pkg_name}.tar.gz"
    python_pkg_download_url="https://github.com/64rl0/PythonRuntime/releases/download/${python_pkg_name}/${python_pkg_full_name}"
}

####################################################################################################
# TOOLS
####################################################################################################
function run_isort() {
    local elements=("${active_dirs[@]}" "${active_py_files[@]}")

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
    local elements=("${active_dirs[@]}" "${active_py_files[@]}")

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
    local elements=("${active_dirs[@]}" "${active_py_files[@]}")

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
    local elements=("${active_dirs[@]}" "${active_py_files[@]}")

    validate_command "mypy" || {
        mypy_summary_status="${failed}"
        exit_code=1
        return
    }

    for el in "${elements[@]}"; do
        echo -e "${blue}${el}${end}"
        mypy --color-output "${el}" || {
            if [[ "${?}" -eq 1 ]]; then
                mypy_summary_status="${failed}"
                exit_code=1
            fi
        }
        echo
    done
}

function run_shfmt() {
    local elements=("${active_dirs[@]}" "${active_sh_files[@]}")

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
    local elements=("${active_files_all[@]}")
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
    local elements=("${active_files_all[@]}")
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

        # Read last byte safely (strip spaces cranked out by od)
        local last_byte=$(tail -c 1 -- "${el}" | od -An -tu1 | tr -d '[:space:]')
        local fixed=false

        # Add \n only if it isn't one already.
        if [[ "${last_byte}" != 10 ]]; then
            echo "Fixing: ${el}"
            printf '\n' >>"${el}" || {
                eofnewline_summary_status="${failed}"
                exit_code=1
            }
            ((counter = counter + 1))
        # The last char already is a \n.
        else
            while true; do
                local penultimate_byte=$(tail -c 2 -- "${el}" | head -c 1 | od -An -tu1 | tr -d '[:space:]')
                if [[ "${penultimate_byte}" == 10 ]]; then
                    if [[ "${fixed}" != true ]]; then
                        fixed=true
                        echo "Fixing: ${el}"
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

    if [[ "${counter}" -ge 1 ]]; then
        echo
    fi
    echo -e "Fixed ${counter} file(s)"
    echo
}

function run_trailingwhitespaces() {
    local elements=("${active_files_all[@]}")
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

        # Trail whitespaces
        echo "Fixing: ${el}"
        ((counter = counter + 1))

        if [[ $(uname -s) == "Darwin" ]]; then
            # macOS
            sed -E -i '' 's/[[:space:]]+$//' "${el}" || {
                trailing_summary_status="${failed}"
                exit_code=1
            }
        else
            # Linux
            sed -E -i 's/[[:space:]]+$//' "${el}" || {
                trailing_summary_status="${failed}"
                exit_code=1
            }
        fi
    done

    echo
    echo -e "Fixed ${counter} file(s)"
    echo
}

function run_eolnorm() {
    local elements=("${active_files_all[@]}")
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

        # Does the file actually contain a CR?
        if ! grep -q $'\r' "${el}"; then
            continue
        fi

        echo "Fixing: ${el}"
        ((counter = counter + 1))

        tmp=$(mktemp --tmpdir="$(dirname "${el}")" "$(basename "${el}").XXXX")
        { sed 's/\r$//' "${el}" | tr '\r' '\n'; } >"${tmp}" && mv "${tmp}" "${el}" || {
            echo_error "Failed to normalize EOLs in ${el}"
            eolnorm_summary_status="$failed"
            exit_code=1
        }
    done

    if [[ "${counter}" -ge 1 ]]; then
        echo
    fi
    echo -e "Fixed ${counter} file(s)"
    echo
}

function run_gitleaks() {
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

function run_brazil_pytest() {
    brazil-build brazil_test || {
        pytest_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_venv_pytest() {
    local elements=("${active_dirs[@]}" "${active_py_files[@]}")
    echo -e "Preparing tests"
    echo

    validate_command "pytest" || {
        pytest_summary_status="${failed}"
        exit_code=1
        return
    }

    pytest 2>&1 || {
        pytest_summary_status="${failed}"
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
        echo_error "No \`${project_root_dir_abs}/docs\` directory found.\n To enable documentation create a \`docs\` directory in the project root directory."
        return
    fi

    # Cleaning docs env
    rm -rf "${project_root_dir_abs}/docs/_apidoc"
    rm -rf "${project_root_dir_abs}/docs/html"

    # Generating Sphinx sources
    sphinx-apidoc --force -d 1000 --separate --module-first -o "${project_root_dir_abs}/docs/_apidoc" "${project_root_dir_abs}/src" || {
        docs_summary_status="${failed}"
        exit_code=1
    }

    # Generating HTML docs
    sphinx-build -v --fail-on-warning --builder html "${project_root_dir_abs}/docs" "${project_root_dir_abs}/docs/html" || {
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

function build_brazil_env() {
    # We don't want to suppress this error
    brazil ws sync --md || exit 1

    {
        # Use brazil runtime farm to build brazil runtime env
        local brazil_bin_dir="$(brazil-path testrun.runtimefarm)/python${python_version_default_for_brazil}/bin"
        brazil-build
    } || {
        build_summary_status="${failed}"
        exit_code=1
    }
}

function install_python_runtime() {
    local dest_tar="${path_to_cache_root}/CPython/${python_pkg_full_name}"
    local root_tree=(
        "${path_to_cache_root}/CPython"
        "${path_to_runtime_root}/CPython"
        "${path_to_runtime_root}/bin"
        "${path_to_runtime_root}/include"
        "${path_to_runtime_root}/lib"
        "${path_to_runtime_root}/private"
        "${path_to_runtime_root}/share"
    )

    for d in "${root_tree[@]}"; do
        mkdir -p "${d}" || {
            echo_error "Failed to create '${d}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done

    echo -e "${bold_green}${sparkles} Downloading & Installing 'Python${python_full_version}'${end}"
    echo -e "This can take a while"
    if [[ ! -e "${dest_tar}" ]]; then
        curl -L "${python_pkg_download_url}" -o "${dest_tar}" || {
            echo_error "Failed to download '${python_pkg_name}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
        echo
    fi
    # Clean any partial or old dir left there before unpacking
    rm -rf "${path_to_cache_root}/CPython/${python_full_version}" || {
        echo_error "Failed to remove '${path_to_cache_root}/CPython/${python_full_version}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    tar -vxzf "${dest_tar}" -C "${path_to_cache_root}/CPython" || {
        echo_error "Failed to unpack '${python_pkg_name}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    # Clean any partial or old dir left there before moving to runtime root
    rm -rf "${path_to_runtime_root}/CPython/${python_full_version}" || {
        echo_error "Failed to remove '${path_to_runtime_root}/CPython/${python_full_version}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    mv "${path_to_cache_root}/CPython/${python_full_version}" "${path_to_runtime_root}/CPython/${python_full_version}" || {
        echo_error "Failed to move '${dest_tar}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    if [[ "${build_single_run_status}" -eq 0 ]]; then
        echo -e "done!"
        echo
    fi
}

function build_venv_env() {
    build_single_run_status=0

    activate_venv_env_core

    # Build python runtime
    install_python_runtime

    # Create Local env
    mkdir -p "${path_to_env_root}" || {
        echo_error "Failed to create '${path_to_env_root}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    rm -rf "${path_to_env_root}" || {
        echo_error "Failed to remove '${path_to_env_root}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    ln -f -s "${path_to_runtime_root}/CPython/${python_full_version}" "${path_to_env_root}" || {
        echo_error "Failed to create symlink to '${path_to_env_root}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Install pip and update
    echo -e "${bold_green}${sparkles} Updating pip...${end}"
    "python${python_version}" -m pip install --upgrade pip setuptools wheel || {
        echo_error "Failed to update pip."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Install requirements
    echo
    echo -e "${bold_green}${sparkles} Installing requirements into 'Python${python_full_version}' env...${end}"
    for requirements_path in "${requirements_paths[@]}"; do
        "python${python_version}" -m pip install -I -r "${project_root_dir_abs}/${requirements_path}" || {
            echo_error "Failed to install requirements ${requirements_path} 'Python${python_full_version}' env."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done

    # Cleanup pre silently
    # We are about to rebuild the wheel so make sure the env is clean to accommodate the new one
    rm -rf "${path_to_wheel_root}"
    rm -rf "${project_root_dir_abs}/src/"*".egg-info"

    # Building local package
    echo
    echo -e "${bold_green}${hammer_and_wrench}  Building '${package_name_snake_case}' package...${end}"
    "python${python_version}" -m build --wheel --outdir "${path_to_wheel_root}/dist" "${project_root_dir_abs}" || {
        echo_error "Failed to build '${project_root_dir_abs}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    echo
    echo -e "${bold_green}${package} Checking package health${end}"
    twine check "${path_to_wheel_root}/dist/"* || {
        echo_error "Failed to check package health."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Install local package into env (as last so it will override the same name)
    echo
    echo -e "${bold_green}${sparkles} Installing '${package_name_snake_case}' into 'Python${python_full_version}' env...${end}"
    "python${python_version}" -m pip install -I "${path_to_wheel_root}/dist/"*.whl || {
        echo_error "Failed to install '${project_root_dir_abs}' into 'Python${python_full_version}' env."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Cleanup post
    echo
    echo -e "${bold_green}${broom} Cleaning up...${end}"
    if [[ "${build_env_dir_name}" == 'build' ]]; then
        mkdir -p "${path_to_wheel_root}/build" || {
            echo_error "Failed to create build dir."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
        mv "${project_root_dir_abs}/build/lib" "${path_to_wheel_root}/build" || {
            echo_error "Failed to move build/lib dir to env dir."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
        mv "${project_root_dir_abs}/build/bdist."* "${path_to_wheel_root}/build" || {
            echo_error "Failed to move build/bdist dir to env dir."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    else
        mv "${project_root_dir_abs}/build" "${path_to_wheel_root}" || {
            echo_error "Failed to move build dir to env dir."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    fi
    mv "${project_root_dir_abs}/src/"*".egg-info" "${path_to_wheel_root}/build" || {
        echo_error "Failed to move build dir to env dir."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    echo -e "cleanup completed"

    deactivate_venv_env_core

    if [[ "${build_single_run_status}" -eq 0 ]]; then
        # Build complete!
        echo
        echo -e "${bold_green}${green_check_mark} 'Python${python_full_version}' env build complete & Ready for use!${end}"
        echo
    else
        # Build failed!
        echo
        echo -e "${bold_red}${stop_sign} 'Python${python_full_version}' env build failed!${end}"
        echo
    fi
}

function echo_env_info() {
    local bin_dir="${1}"

    # Display Project info
    echo -e "${bold_green}${hammer_and_wrench}  Project Root:${end}"
    echo "${project_root_dir_abs}"
    echo

    # Display env info
    echo -e "${bold_green}${green_check_mark} Environment activated:${end}"
    echo -e "Runtime Env: ${bin_dir}"
    echo -e "Platform ID: ${platform_identifier}"
    echo -e "Python Version: $("python${python_version}" -c 'import sys; print(sys.version)')"
    echo
}

function activate_brazil_env() {
    local brazil_bin_dir

    # Use brazil runtime farm to activate brazil runtime env
    brazil_bin_dir="$(brazil-path testrun.runtimefarm 2>/dev/null)/python${python_version_default_for_brazil}/bin"
    brazil-build

    # Adding brazil python runtime to path
    OLD_PATH="${PATH}"
    export PATH="${brazil_bin_dir}:${PATH}"

    # Display Env info
    echo_env_info "${brazil_bin_dir}"
}

function activate_venv_env_core() {
    # we need to keep this activate core separated from any echo message as it's being
    # used in the build function too

    # Adding runtime bin to path
    OLD_PATH="${PATH}"
    export PATH="${path_to_runtime_root}/bin:${path_to_env_root}/bin:${OLD_PATH}"
}

function activate_venv_env() {
    local bin_dir

    if [[ ! -e "${path_to_env_root}/bin/python${python_version}" ]]; then
        echo_error "Cannot find the requested env: \`Python${python_full_version}\`"
    fi

    activate_venv_env_core

    # Display Env info
    bin_dir="$(command -v "python${python_version}")"
    echo_env_info "${bin_dir}"
}

function deactivate_brazil_env() {
    export PATH="${OLD_PATH}"
    echo -e "Environment deactivated!"
    echo
}

function deactivate_venv_env_core() {
    # we need to keep this deactivate core separated from any echo message as it's being
    # used in the build function too
    export PATH="${OLD_PATH}"
}

function deactivate_venv_env() {
    deactivate_venv_env_core
    echo -e "Environment deactivated!"
    echo
}

function clean_common() {
    local dirs_to_clean=(
        "${project_root_dir_abs}/src/"*".egg-info"
    )
    for dir in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}$(basename ${dir})${end}'"
        echo -e "${dir}"
        rm -rf "${dir}" || {
            echo_error "Failed to clean '${dir}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done

    local dirs_to_clean=(
        ".mypy_cache"
        ".pytest_cache"
        "__pycache__"
    )
    for dir in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}${dir}${end}'"
        find "${project_root_dir_abs}" -type d -name "${dir}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${dir}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done

    local files_to_clean=(
        ".DS_Store"
        "Thumbs.db"
    )
    for file in "${files_to_clean[@]}"; do
        echo -e "Cleaning '${blue}${file}${end}'"
        find "${project_root_dir_abs}" -type f -name "${file}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${file}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done

}

function clean_brazil_env() {
    echo -e "Cleaning up..."
    echo
    clean_common

    brazil-build clean || {
        clean_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function clean_venv_env() {
    echo -e "Cleaning up..."
    echo

    local dirs_to_clean=(
        "${project_root_dir_abs}/${build_env_dir_name}"
    )
    for dir in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}$(basename ${dir})${end}'"
        echo -e "${dir}"
        rm -rf "${dir}" || {
            echo_error "Failed to clean '${dir}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done

    clean_common

    if [[ "${clean_summary_status}" == "${failed}" ]]; then
        echo
        echo -e "${bold_red}${stop_sign} Environment '${build_env_dir_name}' clean failed!${end}"
        echo
    else
        echo
        echo -e "Environment '${build_env_dir_name}' cleaned!"
        echo
    fi
}

function exec_brazil() {
    echo_title "Running exec"
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_exec_command_received[*]}"
    echo

    brazil-test-exec "${initial_exec_command_received[@]}" || {
        exec_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function exec_venv() {
    echo_title "Running exec"
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_exec_command_received[*]}"
    echo

    "${initial_exec_command_received[@]}" || {
        exec_summary_status="${failed}"
        exit_code=1
    }
    echo
}

####################################################################################################
# DISPATCHERS
####################################################################################################
function dispatch_tools() {
    if [[ "${build}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        if [[ "${build_system_in_use}" == "brazil" ]]; then
            echo_title "Building brazil"
            build_brazil_env
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            echo_title "Building env"
            build_venv_env
        fi

        end_block=$(date +%s.%N)
        build_execution_time=$(echo "${build_execution_time}" + "${end_block} - ${start_block}" | bc)

        # Stop here if the only hook was build
        if [[ "${is_only_build_hook}" == "Y" ]]; then
            return
        fi
    fi

    if [[ "${clean}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        if [[ "${build_system_in_use}" == "brazil" ]]; then
            echo_title "Cleaning brazil"
            clean_brazil_env
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            echo_title "Cleaning env"
            clean_venv_env
        fi

        end_block=$(date +%s.%N)
        clean_execution_time=$(echo "${clean_execution_time}" + "${end_block} - ${start_block}" | bc)
        return
    fi

    # Tools that are run as composite
    if [[ "${build_system_in_use}" == "brazil" ]]; then
        echo_title "Project & Env info"
        activate_brazil_env
    elif [[ "${build_system_in_use}" == "icarus" ]]; then
        echo_title "Project & Env info"
        activate_venv_env
    fi

    if [[ "${isort}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running iSort"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_isort
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_isort
        fi

        end_block=$(date +%s.%N)
        isort_execution_time=$(echo "${isort_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${black}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running Black"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_black
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_black
        fi

        end_block=$(date +%s.%N)
        black_execution_time=$(echo "${black_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${flake8}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running Flake8"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_flake8
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_flake8
        fi

        end_block=$(date +%s.%N)
        flake8_execution_time=$(echo "${flake8_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${mypy}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running mypy"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_mypy
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_mypy
        fi

        end_block=$(date +%s.%N)
        mypy_execution_time=$(echo "${mypy_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${shfmt}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running shfmt (bash formatter)"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_shfmt
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_shfmt
        fi

        end_block=$(date +%s.%N)
        shfmt_execution_time=$(echo "${shfmt_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eolnorm}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running eol-norm (convert CR and CRLF to LF)"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_eolnorm
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_eolnorm
        fi

        end_block=$(date +%s.%N)
        eolnorm_execution_time=$(echo "${eolnorm_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${whitespaces}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Replacing non-breaking-space (NBSP) characters"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_char_replacement
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_char_replacement
        fi

        end_block=$(date +%s.%N)
        whitespaces_execution_time=$(echo "${whitespaces_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${trailing}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running trailing-whitespaces"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_trailingwhitespaces
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_trailingwhitespaces
        fi

        end_block=$(date +%s.%N)
        trailing_execution_time=$(echo "${trailing_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eofnewline}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running eof-newline"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_eofnewline
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_eofnewline
        fi

        end_block=$(date +%s.%N)
        eofnewline_execution_time=$(echo "${eofnewline_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${gitleaks}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running gitleaks"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_gitleaks
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_gitleaks
        fi

        end_block=$(date +%s.%N)
        gitleaks_execution_time=$(echo "${gitleaks_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${pytest}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running pytest"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_brazil_pytest
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_venv_pytest
        fi

        end_block=$(date +%s.%N)
        pytest_execution_time=$(echo "${pytest_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${docs}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Generating documentation"
        if [[ "${build_system_in_use}" == "brazil" ]]; then
            run_brazil_documentation
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            run_venv_documentation
        fi

        end_block=$(date +%s.%N)
        docs_execution_time=$(echo "${docs_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${exec}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        if [[ "${build_system_in_use}" == "brazil" ]]; then
            exec_brazil
        elif [[ "${build_system_in_use}" == "icarus" ]]; then
            exec_venv
        fi

        end_block=$(date +%s.%N)
        exec_execution_time=$(echo "${exec_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        echo_title "Deactivating Environment"
        deactivate_brazil_env
    elif [[ "${build_system_in_use}" == "icarus" ]]; then
        echo_title "Deactivating Environment"
        deactivate_venv_env
    fi
}

function dispatch_hooks() {
    echo_running_hooks

    if [[ "${build_system_in_use}" == "brazil" ]]; then
        dispatch_tools
    elif [[ "${build_system_in_use}" == "icarus" ]]; then
        if [[ "${clean}" == "Y" ]]; then
            set_python_constants "${python_default_version}:${python_default_full_version}"
            dispatch_tools
        elif [[ "${exec}" == "Y" ]]; then
            set_python_constants "${python_default_version}:${python_default_full_version}"
            dispatch_tools
        else
            for python_version_composite in "${python_versions[@]}"; do
                set_python_constants "${python_version_composite}"
                echo_title "Running tools for: Python${python_version}" "header"
                dispatch_tools
            done
        fi
    fi

    echo_summary
}

####################################################################################################
# MAIN
####################################################################################################
function main() {
    validate_prerequisites
    set_constants "${@}"
    dispatch_hooks "${@}"

    return "${exit_code}"
}

main "${@}"
