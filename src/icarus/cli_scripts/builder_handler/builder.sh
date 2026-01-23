#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/builder.sh
# Created 5/15/25 - 11:55 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs
this_icarus_abs_filepath="$(realpath -- "${script_dir_abs}/../../../../../../../../bin/icarus")"
declare -r this_icarus_abs_filepath
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
    if [[ "${PWD}" =~ _Projects\/Icarus && ! "${this_icarus_abs_filepath}" =~ _Projects\/Icarus\/ ]]; then
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
    local hook

    echo_title "Running Info"
    echo -e "Collected and preparing to run ${running_hooks_count} hook(s)."
    for hook in "${running_hooks_name[@]}"; do
        echo -e "--| ${blue}${hook}${end}"
    done
    echo
}

function echo_summary() {
    local execution_time execution_time_total execution_time_partial total_execution_time
    local python_versions_pretty python_version_composite hook tool
    local -a all_running_hooks_name

    execution_time=""
    execution_time_total=0
    execution_time_partial=""
    tool=""
    total_execution_time=""
    python_versions_pretty=""
    all_running_hooks_name=("index" "${running_hooks_name[@]}")

    for python_version_composite in "${python_versions[@]}"; do
        python_versions_pretty+="Python$(echo "${python_version_composite}" | cut -d ':' -f 2) "
    done

    echo_title "Icarus Builder Summary"

    echo -e "${bold_blue}${cli_name} builder:${end}"
    echo -e "$("${this_icarus_abs_filepath}" --version)"
    echo

    echo -e "${bold_blue}Command:${end}\n--| ${initial_command_received}"
    echo

    echo -e "${bold_blue}Runtime:${end} \
        \n--| Package ${bold_green}${package_name_pascal_case}${end} \
        \n--| ${project_root_dir_abs} \
        \n--| Interpreters enabled ${bold_green}${python_versions_pretty}${end} \
        \n--| Interpreter default ${bold_green}Python${python_default_version}${end}"
    echo

    echo -e "${bold_blue}Execution metrics overview:${end}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    printf "%-41s | %-7s | %-7s\n" "${bold_white}Tool${end}" "${bold_white}Status${end}" "${bold_white}Timings${end}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    for hook in "${all_running_hooks_name[@]}"; do
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
    for hook in "${all_running_hooks_name[@]}"; do
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
    total_execution_time="$(printf '%s' "total-execution-time ..................................." | cut -c1-39)"
    printf "%-30s | %-7s\n" "${total_execution_time}" "${execution_time_total}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "----------"
    echo
}

####################################################################################################
# CONSTANTS
####################################################################################################
function should_ignore_path() {
    local path="${1}"
    local rel_path="${2}"

    local normalized_path ignored pat anchored dir_only anywhere need_anywhere p
    local -a patterns

    normalized_path="${rel_path%/}"

    for ignored in "${icarus_ignore_array[@]}"; do
        pat="${ignored#./}"
        anchored=false
        dir_only=false
        anywhere=false
        need_anywhere=false

        if [[ "${pat}" == /* ]]; then
            anchored=true
            pat="${pat#/}"
        fi
        if [[ "${pat}" == */ ]]; then
            dir_only=true
            pat="${pat%/}"
        fi
        if [[ "${pat}" == '**/'* ]]; then
            pat="${pat#**/}"
            anywhere=true
        fi
        if [[ "${anywhere}" == true || "${pat}" == */* ]]; then
            need_anywhere=true
        fi

        patterns=()
        if [[ "${anchored}" == true ]]; then
            patterns+=("${pat}")
            if [[ "${dir_only}" == true ]]; then
                patterns+=("${pat}/*" "${pat}/**")
            fi
        else
            patterns+=("${pat}")
            if [[ "${need_anywhere}" == true ]]; then
                patterns+=("**/${pat}")
            fi
            if [[ "${dir_only}" == true ]]; then
                patterns+=("${pat}/*" "${pat}/**")
                if [[ "${need_anywhere}" == true ]]; then
                    patterns+=("**/${pat}/*" "**/${pat}/**")
                fi
            fi
        fi

        for p in "${patterns[@]}"; do
            if [[ "${normalized_path}" == ${p} ]]; then
                return 0
            fi
        done
    done

    return 1
}

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
    declare -r -g build_root_dir
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
    warned="${bold_black}${bg_yellow} WARN ${end}"

    index_summary_status="${passed}"
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

    index_execution_time=0
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

    declare -a -g active_dirs_d1=()
    declare -a -g active_py_files_d1=()
    declare -a -g active_sh_files_d1=()
    declare -a -g active_other_files_d1=()
    declare -a -g active_files_all=()

    echo -e "Walking package root"

    local pat anchored dir_only has_glob path rel_path
    local -a find_cmd prune_patterns prune_expr

    # We do a partial prune on safe ignore without any * to speed up find
    # and exclude big excluded dirs
    prune_patterns=()
    for pat in "${icarus_ignore_array[@]}"; do
        anchored=false
        dir_only=false
        has_glob=false

        pat="${pat#./}"
        if [[ "${pat}" == /* ]]; then
            anchored=true
            pat="${pat#/}"
        fi
        if [[ "${pat}" == */ ]]; then
            dir_only=true
            pat="${pat%/}"
        fi
        if [[ "${pat}" == '**/'* ]]; then
            pat="${pat#**/}"
        fi
        # Does it contain any of *, ? or [
        if [[ "${pat}" == *[\*\?\[]* ]]; then
            has_glob=true
        fi

        # Only use -prune for simple (no-glob) directory-like ignores
        if [[ "${has_glob}" == false ]]; then
            if [[ "${anchored}" == true ]]; then
                prune_patterns+=("${project_root_dir_abs}/${pat}")
            else
                prune_patterns+=("${project_root_dir_abs}/${pat}")
                prune_patterns+=("${project_root_dir_abs}/*/${pat}")
            fi
        fi
    done

    if ((${#prune_patterns[@]})); then
        prune_expr=("(")
        for pat in "${prune_patterns[@]}"; do
            prune_expr+=("-path" "${pat}" "-o")
        done
        # Slice to remove the trailing "-o"
        prune_expr=("${prune_expr[@]:0:${#prune_expr[@]}-1}")
        prune_expr+=(")")
        find_cmd=("find" "${project_root_dir_abs}" "-mindepth" "1" "${prune_expr[@]}" "-prune" "-o" "-print0")
    else
        find_cmd=("find" "${project_root_dir_abs}" "-mindepth" "1" "-print0")
    fi

    while IFS= read -r -d '' path; do
        # Strip the project root prefix plus the trailing / from the absolute path
        rel_path="${path#${project_root_dir_abs}/}"

        if should_ignore_path "${path}" "${rel_path}"; then
            continue
        fi

        # Dirs classification
        if [[ -d "${path}" ]]; then
            if [[ "${rel_path}" != *'/'* ]]; then
                # Depth-1 directories only
                active_dirs_d1+=("${path}")
            fi
            continue
        fi

        # If we get here then it's not a directory
        # Files classification
        if [[ "${rel_path}" != *'/'* ]]; then
            # Depth-1 directories only
            if [[ "${path}" =~ .+\.py$ ]]; then
                active_py_files_d1+=("${path}")
            elif [[ "${path}" =~ .+\.sh$ ]]; then
                active_sh_files_d1+=("${path}")
            else
                active_other_files_d1+=("${path}")
            fi
        fi

        # Always an active file regardless of the type and depth
        active_files_all+=("${path}")
    done < <("${find_cmd[@]}")

    declare -r -g active_dirs_d1
    declare -r -g active_py_files_d1
    declare -r -g active_sh_files_d1
    declare -r -g active_other_files_d1
    declare -r -g active_files_all

    echo
}

function set_icarus_python3_constants() {
    python_version="$(echo "${1}" | cut -d ':' -f 1)"
    python_full_version="$(echo "${1}" | cut -d ':' -f 2)"

    path_to_cache_root="${project_root_dir_abs}/${build_root_dir}/cache"
    path_to_runtime_root="${project_root_dir_abs}/${build_root_dir}/runtime/${platform_identifier}"
    path_to_env_root="${project_root_dir_abs}/${build_root_dir}/env/${platform_identifier}"
    path_to_wheel_root="${project_root_dir_abs}/${build_root_dir}/wheel/${package_name_snake_case}/${platform_identifier}/CPython/${python_full_version}"

    python_pkg_name="cpython-${python_full_version}-${platform_identifier}"
    python_pkg_full_name="${python_pkg_name}.tar.gz"
    python_pkg_download_url="https://github.com/64rl0/PythonRuntime/releases/download/${python_pkg_name}/${python_pkg_full_name}"
}

function set_icarus_cdk_constants() {
    :
}

####################################################################################################
# TOOLS
####################################################################################################
function run_isort() {
    local el
    local -a elements

    elements=("${active_dirs_d1[@]}" "${active_py_files_d1[@]}")

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
    local el
    local -a elements

    elements=("${active_dirs_d1[@]}" "${active_py_files_d1[@]}")

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
    local el
    local -a elements

    elements=("${active_dirs_d1[@]}" "${active_py_files_d1[@]}")

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
    local el
    local -a elements

    elements=("${active_dirs_d1[@]}" "${active_py_files_d1[@]}")

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
    local el
    local -a elements

    elements=("${active_dirs_d1[@]}" "${active_sh_files_d1[@]}")

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
    local el counter
    local -a elements

    counter=0
    elements=("${active_files_all[@]}")

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
    local el counter last_byte fixed file_path penultimate_byte
    local -a elements

    counter=0
    elements=("${active_files_all[@]}")

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
        last_byte=$(tail -c 1 -- "${el}" | od -An -tu1 | tr -d '[:space:]')
        fixed=false

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
                penultimate_byte=$(tail -c 2 -- "${el}" | head -c 1 | od -An -tu1 | tr -d '[:space:]')
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
    local el counter file_path
    local -a elements

    counter=0
    elements=("${active_files_all[@]}")

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
    local el counter file_path tmp
    local -a elements

    counter=0
    elements=("${active_files_all[@]}")

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

function run_pytest() {
    local -a elements

    elements=("${active_dirs_d1[@]}" "${active_py_files_d1[@]}")

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

function run_documentation() {
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

function link_python_to_runtime() {
    local filename filepath files_to_link

    files_to_link=(
        "${path_to_runtime_root}/CPython/${python_full_version}/bin/"*
    )
    for filepath in "${files_to_link[@]}"; do
        filename="$(basename "${filepath}")"
        ln -f -s -n "${filepath}" "${path_to_runtime_root}/bin/${filename}" || {
            echo_error "Failed to create symlink to '${path_to_runtime_root}' for '${filename}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done

    files_to_link=(
        "${path_to_runtime_root}/CPython/${python_full_version}/include/"*
    )
    for filepath in "${files_to_link[@]}"; do
        filename="$(basename "${filepath}")"
        ln -f -s -n "${filepath}" "${path_to_runtime_root}/include/${filename}" || {
            echo_error "Failed to create symlink to '${path_to_runtime_root}' for '${filename}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done

    files_to_link=(
        "${path_to_runtime_root}/CPython/${python_full_version}/lib/"*
    )
    for filepath in "${files_to_link[@]}"; do
        filename="$(basename "${filepath}")"
        ln -f -s -n "${filepath}" "${path_to_runtime_root}/lib/${filename}" || {
            echo_error "Failed to create symlink to '${path_to_runtime_root}' for '${filename}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done
}

function install_python_runtime() {
    local d compression dest_tar
    local -a root_tree

    root_tree=(
        "${path_to_cache_root}/CPython"
        "${path_to_runtime_root}/CPython"
        "${path_to_runtime_root}/bin"
        "${path_to_runtime_root}/include"
        "${path_to_runtime_root}/lib"
        "${path_to_runtime_root}/private"
        "${path_to_runtime_root}/share"
    )

    dest_tar="${path_to_cache_root}/CPython/${python_pkg_full_name}"

    for d in "${root_tree[@]}"; do
        mkdir -p "${d}" || {
            echo_error "Failed to create '${d}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done

    # Make lib64 → lib symlink
    ln -f -s -n "./lib" "${path_to_runtime_root}/lib64" || {
        echo_error "Failed to create '${path_to_runtime_root}/lib64' symlink."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    echo -e "${bold_green}${sparkles} Downloading & Installing 'Python${python_full_version}'${end}"
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
    compression="$(file "${dest_tar}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')" || {
        echo_error "Failed to detect '${dest_tar}' compression type."
        exit_code=1
    }
    tar -v -x --"${compression}" -f "${dest_tar}" -C "${path_to_cache_root}/CPython" || {
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

    # Link all runtime bins to env root
    link_python_to_runtime

    if [[ "${build_single_run_status}" -eq 0 ]]; then
        echo -e "done!"
        echo
    fi
}

function build_icarus_python3() {
    local requirements_path dir dirs_to_link

    build_single_run_status=0

    activate_icarus_python3_core

    # Build python runtime
    install_python_runtime

    # Ensure the Local env path always points to the exact runtime we just built.
    # We (1) remove any existing env root (old symlink or directory), then
    # (2) recreate it, then (3) create the  symlinks to the target runtime dirs.
    # This keeps the path deterministic and avoids stale/partial environments from
    # previous runs.
    rm -rf "${path_to_env_root}" || {
        echo_error "Failed to remove '${path_to_env_root}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    mkdir -p "${path_to_env_root}" || {
        echo_error "Failed to create '${path_to_env_root}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    dirs_to_link=(
        "../../runtime/${platform_identifier}/bin"
        "../../runtime/${platform_identifier}/include"
        "../../runtime/${platform_identifier}/lib"
        "../../runtime/${platform_identifier}/lib64"
        "../../runtime/${platform_identifier}/private"
        "../../runtime/${platform_identifier}/share"
    )
    for dir in "${dirs_to_link[@]}"; do
        ln -f -s -n "${dir}" "${path_to_env_root}" || {
            echo_error "Failed to create symlink to '${path_to_env_root}' for '${dir}'."
            build_summary_status="${failed}"
            build_single_run_status=1
            exit_code=1
        }
    done

    # Install pip and update
    echo -e "${bold_green}${sparkles} Updating pip...${end}"
    "python${python_version}" -m pip install --upgrade --no-warn-script-location pip || {
        echo_error "Failed to update pip."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Install tools required by icarus builder to build and release
    echo
    echo -e "${bold_green}${sparkles} Installing builder tools into 'Python${python_full_version}' env...${end}"
    "python${python_version}" -m pip install --force-reinstall --no-warn-script-location setuptools wheel build twine || {
        echo_error "Failed to install builder tools."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Install requirements
    echo
    echo -e "${bold_green}${sparkles} Installing requirements into 'Python${python_full_version}' env...${end}"
    for requirements_path in "${requirements_paths[@]}"; do
        "python${python_version}" -m pip install --force-reinstall --no-warn-script-location --requirement "${project_root_dir_abs}/${requirements_path}" || {
            echo_error "Failed to install requirements '${requirements_path}'."
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
    "python${python_version}" -m twine check "${path_to_wheel_root}/dist/"* || {
        echo_error "Failed to check package health."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Install local package into env (as last so it will override the same name)
    echo
    echo -e "${bold_green}${sparkles} Installing '${package_name_snake_case}' into 'Python${python_full_version}' env...${end}"
    "python${python_version}" -m pip install --force-reinstall --no-warn-script-location "${path_to_wheel_root}/dist/"*.whl || {
        echo_error "Failed to install '${package_name_snake_case}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Link all runtime bins to env root (after install)
    link_python_to_runtime

    # Cleanup post
    echo
    echo -e "${bold_green}${broom} Cleaning up...${end}"
    if [[ "${build_root_dir}" == 'build' ]]; then
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

    deactivate_icarus_python3_core

    if [[ "${build_single_run_status}" -eq 0 ]]; then
        # Build complete!
        echo
        echo -e "${bold_green}${green_check_mark} 'Python${python_full_version}' build Complete & Ready for use!${end}"
        echo
    else
        # Build failed!
        echo
        echo -e "${bold_red}${stop_sign} 'Python${python_full_version}' build failed!${end}"
        echo
    fi
}

function activate_icarus_python3_core() {
    # we need to keep this activate core separated from any echo message as it's being
    # used in the build function too

    # Adding runtime bin to path
    OLD_PATH="${PATH}"
    export PATH="${path_to_env_root}/bin:${OLD_PATH}"
}

function activate_icarus_python3() {
    if [[ ! -e "${path_to_env_root}/bin/python${python_version}" ]]; then
        echo_error "Cannot find the requested env: \`Python${python_full_version}\`"
    fi

    activate_icarus_python3_core

    # Display Project info
    echo -e "${bold_green}${green_circle} Project Root:${end}"
    echo "${project_root_dir_abs}"
    echo

    # Display env info
    echo -e "${bold_green}${green_circle} Runtime Environment:${end}"
    echo -e "Runtime Env: $(command -v "python${python_version}")"
    echo -e "Platform ID: ${platform_identifier}"
    echo -e "Python Version: $("python${python_version}" -c 'import sys; print(sys.version)')"
    echo
}

function deactivate_icarus_python3_core() {
    # we need to keep this deactivate core separated from any echo message as it's being
    # used in the build function too
    export PATH="${OLD_PATH}"
}

function deactivate_icarus_python3() {
    deactivate_icarus_python3_core
    echo -e "Environment deactivated!"
    echo
}

function clean_icarus_root() {
    local path
    local -a dirs_to_clean

    dirs_to_clean=(
        "${project_root_dir_abs}/${build_root_dir}"
    )
    for path in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}$(basename "${path}")${end}'"
        echo -e "${path}"
        rm -rf "${path}" || {
            echo_error "Failed to clean '${path}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function clean_macos() {
    local path
    local -a files_to_clean

    files_to_clean=(
        ".DS_Store"
        "Thumbs.db"
    )
    for path in "${files_to_clean[@]}"; do
        echo -e "Cleaning '${blue}${path}${end}'"
        find "${project_root_dir_abs}" -type f -name "${path}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${path}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function clean_python() {
    local path
    local -a dirs_to_clean

    dirs_to_clean=(
        "${project_root_dir_abs}/src/"*".egg-info"
    )
    for path in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}$(basename ${path})${end}'"
        echo -e "${path}"
        rm -rf "${path}" || {
            echo_error "Failed to clean '${path}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done

    dirs_to_clean=(
        ".mypy_cache"
        ".pytest_cache"
        "__pycache__"
    )
    for path in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}${path}${end}'"
        find "${project_root_dir_abs}" -type d -name "${path}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${path}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function clean_node() {
    local path
    local -a dirs_to_clean

    dirs_to_clean=(
        "${project_root_dir_abs}/node_modules"
    )
    for path in "${dirs_to_clean[@]}"; do
        echo -e "Cleaning '${blue}$(basename "${path}")${end}'"
        echo -e "${path}"
        rm -rf "${path}" || {
            echo_error "Failed to clean '${path}'."
            clean_summary_status="${failed}"
            exit_code=1
        }
        echo
    done
}

function clean_cdk() {
    :
}

function clean_icarus_python3() {
    clean_icarus_root
    clean_macos
    clean_python

    if [[ "${clean_summary_status}" == "${failed}" ]]; then
        echo -e "${bold_red}${stop_sign} Environment cleanup failed!${end}"
        echo
    else
        echo -e "${bold_green}${broom} Environment cleanup completed!${end}"
        echo
    fi
}

function clean_icarus_cdk() {
    clean_icarus_root
    clean_macos
    clean_node
    clean_cdk

    if [[ "${clean_summary_status}" == "${failed}" ]]; then
        echo -e "${bold_red}${stop_sign} Environment cleanup failed!${end}"
        echo
    else
        echo -e "${bold_green}${broom} Environment cleanup completed!${end}"
        echo
    fi
}

function exec_cmd() {
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
function dispatch_icarus_python3() {
    local start_block end_block

    if [[ "${build}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Building Env"
        build_icarus_python3

        end_block=$(date +%s.%N)
        build_execution_time=$(echo "${build_execution_time}" + "${end_block} - ${start_block}" | bc)

        # Stop here if the only hook was build
        if [[ "${is_only_build_hook}" == "Y" ]]; then
            return
        fi
    fi

    if [[ "${clean}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Cleaning Env"
        clean_icarus_python3

        end_block=$(date +%s.%N)
        clean_execution_time=$(echo "${clean_execution_time}" + "${end_block} - ${start_block}" | bc)

        # Clean always runs alone!
        return
    fi

    # Tools that are run as composite and need build env access
    echo_title "Project & Env info"
    activate_icarus_python3

    if [[ "${exec}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running exec"
        exec_cmd

        end_block=$(date +%s.%N)
        exec_execution_time=$(echo "${exec_execution_time}" + "${end_block} - ${start_block}" | bc)

        # exec always runs alone but we can't return here as we need to deactivate the env
        # so we let the block run until the end
    fi

    if [[ "${isort}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running iSort"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_isort
        fi

        end_block=$(date +%s.%N)
        isort_execution_time=$(echo "${isort_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${black}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running Black"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_black
        fi

        end_block=$(date +%s.%N)
        black_execution_time=$(echo "${black_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${flake8}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running Flake8"
        run_flake8

        end_block=$(date +%s.%N)
        flake8_execution_time=$(echo "${flake8_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${mypy}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running mypy"
        run_mypy

        end_block=$(date +%s.%N)
        mypy_execution_time=$(echo "${mypy_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${shfmt}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running shfmt (bash formatter)"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_shfmt
        fi

        end_block=$(date +%s.%N)
        shfmt_execution_time=$(echo "${shfmt_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eolnorm}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running eol-norm (convert CR and CRLF to LF)"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_eolnorm
        fi

        end_block=$(date +%s.%N)
        eolnorm_execution_time=$(echo "${eolnorm_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${whitespaces}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Replacing non-breaking-space (NBSP) characters"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_char_replacement
        fi

        end_block=$(date +%s.%N)
        whitespaces_execution_time=$(echo "${whitespaces_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${trailing}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running trailing-whitespaces"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_trailingwhitespaces
        fi

        end_block=$(date +%s.%N)
        trailing_execution_time=$(echo "${trailing_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eofnewline}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running eof-newline"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_eofnewline
        fi

        end_block=$(date +%s.%N)
        eofnewline_execution_time=$(echo "${eofnewline_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${gitleaks}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running gitleaks"
        run_gitleaks

        end_block=$(date +%s.%N)
        gitleaks_execution_time=$(echo "${gitleaks_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${pytest}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Running pytest"
        run_pytest

        end_block=$(date +%s.%N)
        pytest_execution_time=$(echo "${pytest_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${docs}" == "Y" ]]; then
        start_block=$(date +%s.%N)

        echo_title "Generating documentation"
        if [[ "${python_full_version}" != "${python_default_full_version}" ]]; then
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        else
            run_documentation
        fi

        end_block=$(date +%s.%N)
        docs_execution_time=$(echo "${docs_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    echo_title "Deactivating Environment"
    deactivate_icarus_python3
}

function dispatch_icarus_cdk() {
    :
}

function dispatch_build_system() {
    local python_version_composite

    echo_running_hooks

    if [[ "${build_system_in_use}" == "icarus-python3" ]]; then
        if [[ "${clean}" == "Y" ]]; then
            set_icarus_python3_constants "${python_default_version}:${python_default_full_version}"
            dispatch_icarus_python3
        elif [[ "${exec}" == "Y" ]]; then
            set_icarus_python3_constants "${python_default_version}:${python_default_full_version}"
            dispatch_icarus_python3
        else
            for python_version_composite in "${python_versions[@]}"; do
                set_icarus_python3_constants "${python_version_composite}"
                echo_title "Running tools for: Python${python_version}" "header"
                dispatch_icarus_python3
            done
        fi
    elif [[ "${build_system_in_use}" == "icarus-cdk" ]]; then
        dispatch_icarus_cdk
    fi

    echo_summary
}

####################################################################################################
# MAIN
####################################################################################################
function main() {
    local start_block end_block elapsed_time

    validate_prerequisites

    # Setting constants, indexing workspace and benchmarking the execution
    start_block=$(date +%s.%N)
    set_constants "${@}"
    end_block=$(date +%s.%N)
    elapsed_time=$(echo "${end_block} - ${start_block}" | bc)
    if [[ $(echo "${elapsed_time} > 5" | bc) -eq 1 ]]; then
        index_summary_status="${warned}"
    fi
    index_execution_time=$(echo "${index_execution_time}" + "${elapsed_time}" | bc)

    dispatch_build_system "${@}"

    return "${exit_code}"
}

main "${@}"
