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

this_script_filename="$(basename -- "${BASH_SOURCE[0]}")"
declare -r this_script_filename
builder_path_script_abs="${cli_scripts_dir_abs}/builder_handler/path.sh"
declare -r builder_path_script_abs

# Sourcing base file
. "${cli_scripts_dir_abs}/base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"
. "${cli_scripts_dir_abs}/builder_handler/builder_base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source builder_base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

####################################################################################################
# SYSTEM
####################################################################################################
function validate_prerequisites() {
    validate_command "bc"
}

function echo_title() {
    local title="${1}"
    local header_mode="${2}"

    local total_width=100
    local gap=2
    local title_len=${#title}

    # How many "=" are still available once we subtract the title and the gaps?
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

function echo_icarus_python3_project_info() {
    if [[ -z "${FARMHOME}" ]]; then
        echo_error "Unable to resolve runtimefarm."
    fi

    # Display Project info
    echo -e "${bold_green}${green_circle} Workspace Root:${end}"
    echo "${project_root_dir_abs}"
    echo

    # Display env info
    echo -e "${bold_green}${green_circle} Runtime Environment:${end}"
    echo -e "Runtimefarm: ${FARMHOME}"
    echo -e "Platform ID: ${platform_identifier}"
    echo -e "Python Version: $("python${python_version}" -c 'import sys; print(sys.version)')"
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

    if [[ "${path_called}" == "Y" ]]; then
        all_running_hooks_name=("index" "path" "${running_hooks_name[@]}")
    else
        all_running_hooks_name=("index" "${running_hooks_name[@]}")
    fi

    for python_version_composite in "${python_versions[@]}"; do
        python_versions_pretty+="Python$(echo "${python_version_composite}" | cut -d ':' -f 2) "
    done

    echo_title "Icarus Builder Summary"

    echo -e "${bold_blue}${cli_name} builder:${end}"
    # We need to unset everything to get the real icarus running in the os
    unset FARMHOME PYTHONHOME PYTHONPATH PYTHONBIN __PYVENV_LAUNCHER__
    echo -e "$("${this_cli_fullpath}" --version)"
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
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "--------"
    printf "%-41s | %-7s | %-7s\n" "${bold_white}Tool${end}" "${bold_white}Status${end}" "${bold_white}Timings${end}"
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "--------"
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
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "--------"
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
    printf "%s-+-%s-+-%s\n" "------------------------------" "------" "--------"
    echo
}

####################################################################################################
# CONSTANTS
####################################################################################################
function should_ignore_path() {
    local path rel_path normalized_path ignored pat anchored dir_only anywhere need_anywhere p
    local -a patterns

    path="${1}"
    rel_path="${2}"
    normalized_path="${rel_path%/}"

    if [[ -z "${path}" || -z "${rel_path}" ]]; then
        echo_error "should_ignore_path() requires two arguments: path and rel_path" "errexit"
        exit 1
    fi

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
    local pat anchored dir_only has_glob path rel_path
    local -a find_cmd prune_patterns prune_expr

    echo -e "Reading constants"
    eval "${@}"

    # Capturing argv as array so we can use it to call the builder_path.
    # Do NOT quote $@ otherwise will be captured as a whole string
    argv=(${@})
    declare -r -g -a argv

    # Declaring global vars from `builder_base`
    # This must be done after the `eval "${@}"` call
    declare_global_vars

    exit_code=0

    passed="${bold_black}${bg_green} PASS ${end}"
    failed="${bold_black}${bg_red} FAIL ${end}"
    warned="${bold_black}${bg_yellow} WARN ${end}"
    declare -g -r passed
    declare -g -r failed
    declare -g -r warned

    path_called="N"
    path_to_path_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/env/path"
    declare -g -r path_to_path_root

    index_summary_status="${passed}"
    path_summary_status="${passed}"
    build_summary_status="${passed}"
    merge_summary_status="${passed}"
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
    sphinx_summary_status="${passed}"
    readthedocs_summary_status="${passed}"
    pypi_summary_status="${passed}"
    exectool_summary_status="${passed}"
    execrun_summary_status="${passed}"
    execdev_summary_status="${passed}"

    index_execution_time=0
    path_execution_time=0
    build_execution_time=0
    merge_execution_time=0
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
    sphinx_execution_time=0
    readthedocs_execution_time=0
    pypi_execution_time=0
    exectool_execution_time=0
    execrun_execution_time=0
    execdev_execution_time=0

    declare -a -g active_dirs_d1=()
    declare -a -g active_py_files_d1=()
    declare -a -g active_sh_files_d1=()
    declare -a -g active_other_files_d1=()
    declare -a -g active_files_all=()

    echo -e "Walking package root"

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
    # We cannot lock these vars to GLOBAL READONLY because the for loop to
    # run multi-python versions needs to modify them.

    python_version="$(echo "${1}" | cut -d ':' -f 1)"
    python_full_version="$(echo "${1}" | cut -d ':' -f 2)"

    only_with_python_default=false

    if [[ "${python_full_version}" == "${python_default_full_version}" ]]; then
        is_python_default=true
    else
        is_python_default=false
    fi

    path_to_dist_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/dist/${package_name_snake_case}/CPython/${python_full_version}"
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
        if [[ "${ICARUS_ENV}" == "dev" && $(basename "${el}") == "${this_script_filename}" ]]; then
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
    local el counter last_byte fixed file_path penultimate_byte
    local -a elements

    counter=0
    elements=("${active_files_all[@]}")

    for el in "${elements[@]}"; do
        # Skip empty files – they already satisfy the "blank line" rule.
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
                        eofnewline_summary_status="${failed}"
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
        # Skip empty files – they already satisfy the "blank line" rule.
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
        # Skip empty files – they already satisfy the "blank line" rule.
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
            eolnorm_summary_status="${failed}"
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

function run_readthedocs() {
    local local_packages filename filepath

    if [[ -z "${read_the_docs_requirements_path}" ]]; then
        echo_error "read-the-docs requirements in icarus-python3 icarus.cfg must be a set."
        readthedocs_summary_status="${failed}"
        exit_code=1
        return
    fi

    filepath="${project_root_dir_abs}/${read_the_docs_requirements_path##/}"
    filename="$(basename "${read_the_docs_requirements_path}")"

    mkdir -p "$(dirname "${filepath}")" || {
        echo_error "Failed to create '$(dirname "${filepath}")'."
        readthedocs_summary_status="${failed}"
        exit_code=1
    }

    local_packages="$("${PYTHONBIN}" -m pip freeze | sed -n '/ @ file:\/\//{p;G;}')" || {
        echo_error "Failed to scan for local packages."
        readthedocs_summary_status="${failed}"
        exit_code=1
    }
    if [[ -n "${local_packages}" ]]; then
        echo_warning "Local packages found (excluded from '${filename}'):"
        echo "${local_packages}"
        echo
        readthedocs_summary_status="${warned}"
    fi

    # Creating requirements for Read the Docs
    printf '%s\n' \
        '#' \
        "# This file is autogenerated by ${cli_name} with Python ${python_version}" \
        '# by the following command:' \
        '#' \
        "#    python${python_version} -m pip freeze" \
        '#' \
        '# These packages are not runtime requirements for the project.' \
        '# They are listed here only so Read the Docs can build a' \
        '# reproducible environment.' \
        '#' \
        '' \
        >"${filepath}" || {
        echo_error "Failed to create '${filepath}'."
        readthedocs_summary_status="${failed}"
        exit_code=1
    }

    "${PYTHONBIN}" -m pip freeze | sed '/ @ file:\/\//d' >>"${filepath}" || {
        echo_error "Failed to generate '${filepath}'."
        readthedocs_summary_status="${failed}"
        exit_code=1
    }
}

function run_documentation_sphinx() {
    validate_command "sphinx-apidoc" || {
        sphinx_summary_status="${failed}"
        exit_code=1
        return
    }

    validate_command "sphinx-build" || {
        sphinx_summary_status="${failed}"
        exit_code=1
        return
    }

    if [[ ! -d "${project_root_dir_abs}/docs" ]]; then
        sphinx_summary_status="${failed}"
        exit_code=1
        echo_error "No \`${project_root_dir_abs}/docs\` directory found.\n To enable documentation create a \`docs\` directory in the project root directory."
        return
    fi

    # Cleaning docs env
    rm -rf "${project_root_dir_abs}/docs/_apidoc"
    rm -rf "${project_root_dir_abs}/docs/html"

    # Generating Sphinx sources
    sphinx-apidoc --force -d 1000 --separate --module-first -o "${project_root_dir_abs}/docs/_apidoc" "${project_root_dir_abs}/src" || {
        sphinx_summary_status="${failed}"
        exit_code=1
    }

    # Generating HTML docs
    sphinx-build -v --color --fail-on-warning --builder html "${project_root_dir_abs}/docs" "${project_root_dir_abs}/docs/html" || {
        sphinx_summary_status="${failed}"
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

function run_pypi() {
    local f

    if [[ -z "${ICARUS_PYPI_TEST_API_TOKEN}" || -z "${ICARUS_PYPI_PROD_API_TOKEN}" ]]; then
        echo_error "ICARUS_PYPI_TEST_API_TOKEN and ICARUS_PYPI_PROD_API_TOKEN environment variables must both be set." "errexit"
    fi

    for f in "${path_to_dist_root}/${package_name_snake_case}"*.{tar.gz,whl}; do
        if [[ ! -e "${f}" ]]; then
            echo_error "Package artifact '${f}' not found! Have you built it?"
            pypi_summary_status="${failed}"
            exit_code=1
        fi
    done

    # Upload package artifact to TEST PyPi
    echo -e "${bold_green}${network_world} Uploading package artifact to TEST PyPi${end}"
    "${PYTHONBIN}" -m twine upload \
        --repository testpypi \
        --username __token__ \
        --password "${ICARUS_PYPI_TEST_API_TOKEN}" \
        --verbose \
        "${path_to_dist_root}/${package_name_snake_case}"*.{tar.gz,whl} || {
        echo_error "Failed to upload package artifact to TEST PyPi."
        pypi_summary_status="${failed}"
        exit_code=1
        return
    }
    echo

    # Upload package artifact to PROD PyPi
    echo -e "${bold_green}${network_world} Uploading package artifact to PROD PyPi${end}"
    "${PYTHONBIN}" -m twine upload \
        --username __token__ \
        --password "${ICARUS_PYPI_PROD_API_TOKEN}" \
        --verbose \
        "${path_to_dist_root}/${package_name_snake_case}"*.{tar.gz,whl} || {
        echo_error "Failed to upload package artifact to PROD PyPi."
        pypi_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function run_build_icarus_python3() {
    # Single run status is used to monitor the outcome of a single run in
    # the for loop of python versions, if a previous run version but the
    # current succeed we do not wat to show the overall failure but we
    # want to show the succeed of the single run.
    build_single_run_status=0

    # We export ICARUS_PACKAGE_VERSION at build time. we need to inject
    # the ICARUS_PACKAGE_VERSION var in the env for the setup.py to find it.
    export ICARUS_PACKAGE_VERSION="${package_version_full}"

    # We need the tool.runtimefarm to build the pkg.
    resolve_path "${path_tool_runtimefarm_name}"

    # Cleanup silently
    # We are about to rebuild the dist so make sure the env is clean to accommodate the new one.
    rm -rf "${path_to_dist_root}"
    rm -rf "${project_root_dir_abs}/src/"*".egg-info"

    # Building local package.
    echo -e "${bold_green}${hammer_and_wrench}  Building '${package_name_snake_case}' package${end}"
    "${PYTHONBIN}" -m build --no-isolation --outdir "${path_to_dist_root}" "${project_root_dir_abs}" || {
        echo_error "Failed to build '${project_root_dir_abs}'."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    echo

    for f in "${path_to_dist_root}/${package_name_snake_case}"*.{tar.gz,whl}; do
        if [[ ! -e "${f}" ]]; then
            echo_error "Package artifact '${f}' not found!"
            build_summary_status="${failed}"
            exit_code=1
        fi
    done

    echo -e "${bold_green}${package} Checking package health${end}"
    "${PYTHONBIN}" -m twine check "${path_to_dist_root}/${package_name_snake_case}"*.{tar.gz,whl} || {
        echo_error "Failed to check package health."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    echo

    # Unpack sdist
    mkdir -p "${path_to_dist_root}/sdist" || {
        echo_error "Failed to create sdist dir."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }
    tar -xzf "${path_to_dist_root}/${package_name_snake_case}"*.tar.gz -C "${path_to_dist_root}/sdist" || {
        echo_error "Failed to unpack sdist."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # Cleanup
    mv "${project_root_dir_abs}/src/${package_name_snake_case}"*".egg-info" "${path_to_dist_root}" || {
        echo_error "Failed to move egg-info dir to dist dir."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    }

    # This will install the pkg just built in the pkg.runtimefarm.
    echo -e "${bold_green}${sparkles} Installing '${package_name_snake_case}' package${end}"
    if resolve_path "${path_pkg_runtimefarm_name}"; then
        echo -e "Installed $(basename "${path_to_dist_root}"/*.whl)"
        echo
    else
        echo_error "Failed to install '${package_name_snake_case}' package."
        build_summary_status="${failed}"
        build_single_run_status=1
        exit_code=1
    fi

    # Unsetting ICARUS_PACKAGE_VERSION var from the env.
    unset ICARUS_PACKAGE_VERSION

    if [[ "${build_single_run_status}" -eq 0 ]]; then
        # Build complete!
        echo -e "${bold_green}${green_check_mark} Build completed!${end}"
        echo
    else
        # Build failed!
        echo -e "${bold_red}${stop_sign} Build failed!${end}"
        echo
    fi
}

function exec_tool_cmd() {
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_exectool_command_received[*]}"
    echo

    "${initial_exectool_command_received[@]}" || {
        exectool_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function exec_run_cmd() {
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_execrun_command_received[*]}"
    echo

    "${initial_execrun_command_received[@]}" || {
        execrun_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function exec_dev_cmd() {
    echo -e "${bold_blue}Executing command:${end}\n--| ${initial_execdev_command_received[*]}"
    echo

    "${initial_execdev_command_received[@]}" || {
        execdev_summary_status="${failed}"
        exit_code=1
    }
    echo
}

function resolve_path() {
    local p_name path_runtime path_bin path_python_home pkg_pythonpath

    # path_called is a global var DO NOT set as local.
    path_called="Y"

    p_name=$1

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'path_name'"
        path_summary_status="${failed}"
        exit_code=1
    fi

    # Clear previous exports
    unset FARMHOME PYTHONHOME PYTHONPATH PYTHONBIN __PYVENV_LAUNCHER__
    set -a
    PATH="${_OLD_PATH}"
    set +a

    # If there isn't a path, then we incur the risk of using system binaries,
    # therefore this is a hard stop, using errexit.

    case "${p_name}" in
    "${path_pkg_runtimefarm_name}")
        path_runtime="$(_internal_icarus_builder_path_cmd "${path_pkg_runtimefarm_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_pkg_runtimefarm_name}." "errexit"
        }
        path_bin="$(_internal_icarus_builder_path_cmd "${path_pkg_bin_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_pkg_bin_name}." "errexit"
        }
        path_python_home="$(_internal_icarus_builder_path_cmd "${path_pkg_pythonhome_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_pkg_pythonhome_name}." "errexit"
        }
        ;;
    "${path_tool_runtimefarm_name}")
        path_runtime="$(_internal_icarus_builder_path_cmd "${path_tool_runtimefarm_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_tool_runtimefarm_name}." "errexit"
        }
        path_bin="$(_internal_icarus_builder_path_cmd "${path_tool_bin_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_tool_bin_name}." "errexit"
        }
        path_python_home="$(_internal_icarus_builder_path_cmd "${path_tool_pythonhome_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_tool_pythonhome_name}." "errexit"
        }
        ;;
    "${path_run_runtimefarm_name}")
        path_runtime="$(_internal_icarus_builder_path_cmd "${path_run_runtimefarm_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_run_runtimefarm_name}." "errexit"
        }
        path_bin="$(_internal_icarus_builder_path_cmd "${path_run_bin_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_run_bin_name}." "errexit"
        }
        path_python_home="$(_internal_icarus_builder_path_cmd "${path_run_pythonhome_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_run_pythonhome_name}." "errexit"
        }
        ;;
    "${path_devrun_runtimefarm_name}")
        path_runtime="$(_internal_icarus_builder_path_cmd "${path_devrun_runtimefarm_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_devrun_runtimefarm_name}." "errexit"
        }
        path_bin="$(_internal_icarus_builder_path_cmd "${path_devrun_bin_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_devrun_bin_name}." "errexit"
        }
        path_python_home="$(_internal_icarus_builder_path_cmd "${path_devrun_pythonhome_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_devrun_pythonhome_name}." "errexit"
        }
        ;;
    "${path_devrun_excluderoot_runtimefarm_name}")
        path_runtime="$(_internal_icarus_builder_path_cmd "${path_pkg_runtimefarm_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_pkg_runtimefarm_name}." "errexit"
        }
        pkg_pythonpath="$(_internal_icarus_builder_path_cmd "${path_pkg_pythonhome_name}")/lib/python${python_version}/site-packages" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_pkg_pythonhome_name}." "errexit"
        }
        path_runtime="$(_internal_icarus_builder_path_cmd "${path_devrun_excluderoot_runtimefarm_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_devrun_excluderoot_runtimefarm_name}." "errexit"
        }
        path_bin="$(_internal_icarus_builder_path_cmd "${path_devrun_excluderoot_bin_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_devrun_excluderoot_bin_name}." "errexit"
        }
        path_python_home="$(_internal_icarus_builder_path_cmd "${path_devrun_excluderoot_pythonhome_name}")" || {
            path_summary_status="${failed}"
            exit_code=1
            echo_error "Failed to resolve path ${path_devrun_excluderoot_pythonhome_name}." "errexit"
        }
        ;;
    *)
        echo_error "Unknown path name: '${p_name}'" "errexit"
        ;;
    esac

    set -a
    PATH="${path_bin:+${path_bin}:}${PATH}"
    FARMHOME="${path_runtime}"
    PYTHONHOME="${path_python_home}"
    PYTHONPATH="${pkg_pythonpath:+${pkg_pythonpath}:}${PYTHONPATH:+${PYTHONPATH}}"
    PYTHONBIN="${path_python_home}/bin/python${python_version}"
    set +a
}

function workspace_merge() (
    # Using a subshell to avoid mutating existing variables from the ready-* file.
    local farm_ready p_name
    local -a farms_to_merge

    farms_to_merge=()

    echo -e "Checking workspace"
    for farm_ready in "${path_to_path_root}/"*"/farm-info/ready-"*; do
        if [[ ! -e "${farm_ready}" ]]; then
            continue
        fi
        # shellcheck disable=SC1090
        . <(head -n 11 "${farm_ready}") || {
            echo_error "Failed to merge workspace."
            merge_summary_status="${failed}"
            exit_code=1
        }
        farms_to_merge+=("${farm_name}")
    done

    if (("${#farms_to_merge[@]}" == 0)); then
        echo -e "Detected farms: [NONE]"
        echo -e "Done!"
        echo
        return
    fi

    echo -e "Detected farms: ${farms_to_merge[*]}"

    echo -e "Merging workspace"
    rm -rf "${path_to_path_root}" || {
        echo_error "Failed to merge workspace."
        merge_summary_status="${failed}"
        exit_code=1
    }

    for p_name in "${farms_to_merge[@]}"; do
        resolve_path "${p_name}"
    done

    echo -e "Done!"
    echo
)

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

function store_paths() {
    _OLD_PATH="${PATH}"
    # Locking entry path to prevent overwrite
    declare -g -r _OLD_PATH
}

function restore_paths() {
    export PATH="${_OLD_PATH}"
}

function _internal_icarus_builder_path_cmd() {
    local p_name response path_response stderr_target
    local -a new_argv

    p_name="${1}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'path_name'"
        path_summary_status="${failed}"
        exit_code=1
        return 1
    fi

    # The builder.sh receives the same args from the python cli parser
    # and path_name is an empty string as default. We need to remove it
    # from the original argv and replace it with the passed in path_name.

    # We also need to force a single run for a specific python version,
    # preventing to build the path for the whole python versions loop.
    # So to do it, we need to override the python_versions array passed
    # in by the cli.

    # Overwrite values MUST be at the end so that they can overwrite any
    # previous value!
    new_argv=("${argv[@]}")
    new_argv+=("path_name='${p_name}'")
    new_argv+=("python_versions=( '${python_version}:${python_full_version}' )")

    if [[ "${verbose}" == "Y" ]]; then
        stderr_target="/dev/stderr"
    else
        stderr_target="/dev/null"
    fi

    bash "${builder_path_script_abs}" "${new_argv[@]}" 2>"${stderr_target}" || {
        response="${?}"
        if [[ "${response}" == 1 ]]; then
            path_summary_status="${failed}"
            exit_code=1
            return 1
        elif [[ "${response}" == 2 ]]; then
            path_summary_status="${warned}"
        fi
    }
}

####################################################################################################
# DISPATCHERS
####################################################################################################
function dispatch_icarus_python3_before_plugins() {
    local start_block end_block
    echo_title "Before Plugins [GLOBAL]"
    # Global plugins python-default is NOT set yet!
    echo -e "${bold_yellow}[plugins] Executing commands for: before-all${end}"
    echo -e "running: store_paths"
    store_paths
    echo
}

function dispatch_icarus_python3_after_plugins() {
    echo_title "After Plugins [GLOBAL]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: after-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
    echo -e "${bold_yellow}[plugins] Executing commands for: after-all${end}"
    echo -e "running: restore_paths"
    restore_paths
    echo
}

function dispatch_icarus_python3_before_build_plugins() {
    local start_block end_block
    echo_title "Before Plugins [BUILD]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: before-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
    echo -e "${bold_yellow}[plugins] Executing commands for: before-all${end}"
    start_block=$(date +%s.%N)
    echo -e "running: resolve_path ${path_tool_runtimefarm_name}"
    resolve_path "${path_tool_runtimefarm_name}"
    end_block=$(date +%s.%N)
    path_execution_time=$(echo "${path_execution_time}" + "${end_block} - ${start_block}" | bc)
    echo
}

function dispatch_icarus_python3_after_build_plugins() {
    echo_title "After Plugins [BUILD]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: after-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
    echo -e "${bold_yellow}[plugins] Executing commands for: after-all${end}"
    echo -e "nothing to do here - skipping"
    echo
}

function dispatch_icarus_python3_before_exectool_plugins() {
    local start_block end_block
    echo_title "Before Plugins [EXEC-TOOL]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: before-default${end}"
        start_block=$(date +%s.%N)
        echo -e "running: resolve_path ${path_tool_runtimefarm_name}"
        resolve_path "${path_tool_runtimefarm_name}"
        end_block=$(date +%s.%N)
        path_execution_time=$(echo "${path_execution_time}" + "${end_block} - ${start_block}" | bc)
        echo

        echo_title "Project & Env info"
        echo_icarus_python3_project_info
    else
        # This is only entered for NON python-default version
        :
    fi
}

function dispatch_icarus_python3_after_exectool_plugins() {
    echo_title "After Plugins [EXEC-TOOL]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: after-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
}

function dispatch_icarus_python3_before_execrun_plugins() {
    local start_block end_block
    echo_title "Before Plugins [EXEC-RUN]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: before-default${end}"
        start_block=$(date +%s.%N)
        echo -e "running: resolve_path ${path_run_runtimefarm_name}"
        resolve_path "${path_run_runtimefarm_name}"
        end_block=$(date +%s.%N)
        path_execution_time=$(echo "${path_execution_time}" + "${end_block} - ${start_block}" | bc)
        echo

        echo_title "Project & Env info"
        echo_icarus_python3_project_info
    else
        # This is only entered for NON python-default version
        :
    fi
}

function dispatch_icarus_python3_after_execrun_plugins() {
    echo_title "After Plugins [EXEC-RUN]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: after-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
}

function dispatch_icarus_python3_before_execdev_plugins() {
    local start_block end_block
    echo_title "Before Plugins [EXEC-DEV]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: before-default${end}"
        start_block=$(date +%s.%N)
        echo -e "running: resolve_path ${path_devrun_runtimefarm_name}"
        resolve_path "${path_devrun_runtimefarm_name}"
        end_block=$(date +%s.%N)
        path_execution_time=$(echo "${path_execution_time}" + "${end_block} - ${start_block}" | bc)
        echo

        echo_title "Project & Env info"
        echo_icarus_python3_project_info
    else
        # This is only entered for NON python-default version
        :
    fi
}

function dispatch_icarus_python3_after_execdev_plugins() {
    echo_title "After Plugins [EXEC-DEV]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: after-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
}

function dispatch_icarus_python3_before_tools_plugins() {
    local start_block end_block
    echo_title "Before Plugins [TOOLS]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: before-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
    echo -e "${bold_yellow}[plugins] Executing commands for: before-all${end}"
    start_block=$(date +%s.%N)
    echo -e "running: resolve_path ${path_devrun_excluderoot_runtimefarm_name}"
    resolve_path "${path_devrun_excluderoot_runtimefarm_name}"
    end_block=$(date +%s.%N)
    path_execution_time=$(echo "${path_execution_time}" + "${end_block} - ${start_block}" | bc)
    echo

    echo_title "Project & Env info"
    echo_icarus_python3_project_info
}

function dispatch_icarus_python3_after_tools_plugins() {
    echo_title "After Plugins [TOOLS]"
    if [[ "${is_python_default}" == true ]]; then
        echo -e "${bold_yellow}[plugins] Executing commands for: after-default${end}"
        echo -e "nothing to do here - skipping"
        echo
    else
        # This is only entered for NON python-default version
        :
    fi
    echo -e "${bold_yellow}[plugins] Executing commands for: after-all${end}"
    echo -e "nothing to do here - skipping"
    echo
}

function dispatch_icarus_python3_tools() {
    local start_block end_block

    if [[ "${merge}" == "Y" ]]; then
        only_with_python_default=true

        start_block=$(date +%s.%N)
        echo_title "Merging Workspace"
        workspace_merge
        end_block=$(date +%s.%N)
        merge_execution_time=$(echo "${merge_execution_time}" + "${end_block} - ${start_block}" | bc)

        # Merge always runs alone!
        return
    fi

    if [[ "${clean}" == "Y" ]]; then
        only_with_python_default=true

        start_block=$(date +%s.%N)
        echo_title "Cleaning"
        clean_icarus_python3
        end_block=$(date +%s.%N)
        clean_execution_time=$(echo "${clean_execution_time}" + "${end_block} - ${start_block}" | bc)

        # Clean always runs alone!
        return
    fi

    if [[ "${exectool}" == "Y" ]]; then
        only_with_python_default=true

        dispatch_icarus_python3_before_exectool_plugins

        start_block=$(date +%s.%N)
        echo_title "Running exec ${path_tool_runtimefarm_name}"
        exec_tool_cmd
        end_block=$(date +%s.%N)
        exectool_execution_time=$(echo "${exectool_execution_time}" + "${end_block} - ${start_block}" | bc)

        dispatch_icarus_python3_after_exectool_plugins

        # Exec always runs alone!
        return
    fi

    if [[ "${execrun}" == "Y" ]]; then
        only_with_python_default=true

        dispatch_icarus_python3_before_execrun_plugins

        start_block=$(date +%s.%N)
        echo_title "Running exec ${path_run_runtimefarm_name}"
        exec_run_cmd
        end_block=$(date +%s.%N)
        execrun_execution_time=$(echo "${execrun_execution_time}" + "${end_block} - ${start_block}" | bc)

        dispatch_icarus_python3_after_execrun_plugins

        # Exec always runs alone!
        return
    fi

    if [[ "${execdev}" == "Y" ]]; then
        only_with_python_default=true

        dispatch_icarus_python3_before_execdev_plugins

        start_block=$(date +%s.%N)
        echo_title "Running exec ${path_devrun_runtimefarm_name}"
        exec_dev_cmd
        end_block=$(date +%s.%N)
        execdev_execution_time=$(echo "${execdev_execution_time}" + "${end_block} - ${start_block}" | bc)

        dispatch_icarus_python3_after_execdev_plugins

        # Exec always runs alone!
        return
    fi

    if [[ "${build}" == "Y" ]]; then
        dispatch_icarus_python3_before_build_plugins

        start_block=$(date +%s.%N)
        echo_title "Building"
        run_build_icarus_python3
        end_block=$(date +%s.%N)
        build_execution_time=$(echo "${build_execution_time}" + "${end_block} - ${start_block}" | bc)

        dispatch_icarus_python3_after_build_plugins

        # Stop here if the only hook was build
        if [[ "${is_only_build_hook}" == "Y" ]]; then
            return
        fi
    fi

    dispatch_icarus_python3_before_tools_plugins

    if [[ "${isort}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running iSort"
        if [[ "${is_python_default}" == true ]]; then
            run_isort
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        isort_execution_time=$(echo "${isort_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${black}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running Black"
        if [[ "${is_python_default}" == true ]]; then
            run_black
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
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
        if [[ "${is_python_default}" == true ]]; then
            run_shfmt
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        shfmt_execution_time=$(echo "${shfmt_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eolnorm}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running eol-norm (convert CR and CRLF to LF)"
        if [[ "${is_python_default}" == true ]]; then
            run_eolnorm
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        eolnorm_execution_time=$(echo "${eolnorm_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${whitespaces}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Replacing non-breaking-space (NBSP) characters"
        if [[ "${is_python_default}" == true ]]; then
            run_char_replacement
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        whitespaces_execution_time=$(echo "${whitespaces_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${trailing}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running trailing-whitespaces"
        if [[ "${is_python_default}" == true ]]; then
            run_trailingwhitespaces
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        trailing_execution_time=$(echo "${trailing_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${eofnewline}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running eof-newline"
        if [[ "${is_python_default}" == true ]]; then
            run_eofnewline
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
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

    if [[ "${sphinx}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Generating documentation"
        if [[ "${is_python_default}" == true ]]; then
            run_documentation_sphinx
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        sphinx_execution_time=$(echo "${sphinx_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${readthedocs}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running ReadTheDocs"
        if [[ "${is_python_default}" == true ]]; then
            run_readthedocs
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        readthedocs_execution_time=$(echo "${readthedocs_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    if [[ "${pypi}" == "Y" ]]; then
        start_block=$(date +%s.%N)
        echo_title "Running PyPi"
        if [[ "${is_python_default}" == true ]]; then
            run_pypi
        else
            echo_warning "Skipping Python${python_version} because it is not the python-default (in icarus.cfg)"
        fi
        end_block=$(date +%s.%N)
        pypi_execution_time=$(echo "${pypi_execution_time}" + "${end_block} - ${start_block}" | bc)
    fi

    dispatch_icarus_python3_after_tools_plugins
}

function dispatch_icarus_cdk_before_plugins() {
    :
}

function dispatch_icarus_cdk_after_plugins() {
    :
}

function dispatch_icarus_cdk_tools() {
    :
}

function dispatch_set_constants() {
    local start_block end_block elapsed_time

    # Setting constants, indexing workspace and benchmarking the execution.
    start_block=$(date +%s.%N)

    echo_title "Indexing workspace"
    set_constants "${@}"

    end_block=$(date +%s.%N)
    elapsed_time=$(echo "${end_block} - ${start_block}" | bc)

    # Indexing time greater than 5 seconds is considered slow.
    if [[ $(echo "${elapsed_time} > 5" | bc) -eq 1 ]]; then
        index_summary_status="${warned}"
    fi

    index_execution_time=$(echo "${index_execution_time}" + "${elapsed_time}" | bc)
}

function dispatch_build_system() {
    local python_version_composite

    echo_running_hooks

    if [[ "${build_system_in_use}" == "icarus-python3" ]]; then
        dispatch_icarus_python3_before_plugins
        for python_version_composite in "${python_versions[@]}"; do
            set_icarus_python3_constants "${python_version_composite}"
            echo_title "Running tools for: Python${python_version}" "header"
            dispatch_icarus_python3_tools
            if [[ "${only_with_python_default}" == true ]]; then
                # Those command that set only_with_python_default, only runs
                # with the python-default which is the first in the loop.
                break
            fi
        done
        dispatch_icarus_python3_after_plugins
    elif [[ "${build_system_in_use}" == "icarus-cdk" ]]; then
        set_icarus_cdk_constants
        dispatch_icarus_cdk_before_plugins
        dispatch_icarus_cdk_tools
        dispatch_icarus_cdk_after_plugins
    fi

    echo_summary
}

####################################################################################################
# MAIN
####################################################################################################
function main() {
    validate_prerequisites

    dispatch_set_constants "${@}"
    dispatch_build_system "${@}"

    return "${exit_code}"
}

main "${@}"
