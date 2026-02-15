#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/builder_path.sh
# Created 5/15/25 - 11:55 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs

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
    # Nothing to do here
    :
}

####################################################################################################
# CONSTANTS
####################################################################################################
function set_constants() {
    eval "${@}"

    declare -r -g verbose
    declare -r -g all_hooks
    declare -r -g icarus_config_filename
    declare -r -g icarus_config_filepath
    declare -r -g project_root_dir_abs
    declare -r -g package_name_pascal_case
    declare -r -g package_name_snake_case
    declare -r -g package_name_dashed
    declare -r -g package_language
    declare -r -g package_version_full
    declare -r -g package_version_major
    declare -r -g package_version_minor
    declare -r -g package_version_patch
    declare -r -g build_system_in_use
    declare -r -g platform_identifier
    declare -r -g build_root_dir
    declare -r -g python_version_default_for_icarus
    declare -r -g python_versions_for_icarus
    declare -r -g tool_requirements_paths
    declare -r -g run_requirements_paths
    declare -r -g run_requirements_pyproject_toml
    declare -r -g dev_requirements_paths
    declare -r -g icarus_ignore_array
    declare -r -g build
    declare -r -g is_only_build_hook
    declare -r -g is_release
    declare -r -g merge
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
    declare -r -g sphinx
    declare -r -g readthedocs
    declare -r -g exectool
    declare -r -g execrun
    declare -r -g execdev
    declare -r -g initial_command_received
    declare -r -g initial_exectool_command_received
    declare -r -g initial_execrun_command_received
    declare -r -g initial_execdev_command_received
    declare -r -g running_hooks_name
    declare -r -g running_hooks_count
    declare -r -g python_default_version
    declare -r -g python_default_full_version
    declare -r -g python_versions
    declare -r -g path_name
    declare -r -g list_paths

    exit_code=0
    response=''
}

function ensure_icarus_build_root_env() {
    local dir
    local -a root_tree

    # Cache stays in the system tmp
    path_to_cache_root="${tmp_root}/builder/cache"

    path_to_runtime_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/runtime"
    path_to_path_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/env/path"
    path_to_path_cache_root="${path_to_path_root}/path-cache"

    root_tree=(
        "${path_to_cache_root}"
        "${path_to_runtime_root}"
        "${path_to_path_root}"
        "${path_to_path_cache_root}"
    )

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            exit_code=1
        }
    done

    tool_runtimefarm_root="${path_to_path_root}/${path_tool_runtimefarm_name}"
    pkg_runtimefarm_root="${path_to_path_root}/${path_pkg_runtimefarm_name}"
    run_runtimefarm_root="${path_to_path_root}/${path_run_runtimefarm_name}"
    run_excluderoot_runtimefarm_root="${path_to_path_root}/${path_run_excluderoot_runtimefarm_name}"
    devrun_runtimefarm_root="${path_to_path_root}/${path_devrun_runtimefarm_name}"
    devrun_excluderoot_runtimefarm_root="${path_to_path_root}/${path_devrun_excluderoot_runtimefarm_name}"

    declare -g -r path_to_cache_root
    declare -g -r path_to_runtime_root
    declare -g -r path_to_path_root
    declare -g -r path_to_path_cache_root
    declare -g -r tool_runtimefarm_root
    declare -g -r pkg_runtimefarm_root
    declare -g -r run_runtimefarm_root
    declare -g -r run_excluderoot_runtimefarm_root
    declare -g -r devrun_runtimefarm_root
    declare -g -r devrun_excluderoot_runtimefarm_root
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
function link_prefix_to_farm() {
    local source_prefix dest_prefix subdir name conflict conflict_files old_dotglob old_nullglob
    local -a excludes

    source_prefix=$1
    dest_prefix=$2
    shift 2
    excludes=("$@")
    conflict=false

    # Initial validations
    if [[ -z "${source_prefix}" || -z "${dest_prefix}" ]]; then
        echo_error "Missing arguments: 'source_prefix' and/or 'dest_prefix'"
        exit_code=1
        return 1
    fi

    if [[ ! -d "${source_prefix}" ]]; then
        echo_error "Source prefix does not exist: '${source_prefix}'"
        exit_code=1
        return 1
    fi

    # Make sure the destination exists
    mkdir -p "${dest_prefix}" || {
        echo_error "Failed to create '${dest_prefix}'."
        exit_code=1
        return 1
    }

    # Build associative check for excludes (bash 3 compatible)
    function _is_excluded() {
        local check="$1" ex
        for ex in "${excludes[@]}"; do
            if [[ "${check}" == "${ex}" ]]; then
                return 0
            fi
        done
        return 1
    }

    # We need to expand hidden files and null with the * here in the loop.
    old_dotglob=$(shopt -p dotglob) || :
    old_nullglob=$(shopt -p nullglob) || :
    shopt -s dotglob nullglob

    # Process each top-level item in source
    for subdir in "${source_prefix}"/*; do
        if [[ ! -e "${subdir}" ]]; then
            continue
        fi

        name="$(basename "${subdir}")"
        conflict_files=""

        # Skip excluded directories
        if _is_excluded "${name}"; then
            continue
        fi

        # Use cp -asn for fast recursive symlink creation
        # -a: archive mode (preserves structure, recursive)
        # -s: create symlinks instead of copying
        # -n: no-clobber (first source wins)
        # Note: BSD cp may return exit 1 on "File exists" even with -n.
        # Lines that do not contain -> should be errors
        conflict_files=$(cp -a -s -n -v "${subdir}" "${dest_prefix}/" | grep -v -- '->')

        if [[ -n "${conflict_files}" ]]; then
            echo "${conflict_files}"
            conflict=true
        fi
    done

    eval "${old_dotglob}"
    eval "${old_nullglob}"

    if [[ "${conflict}" == true ]]; then
        echo_warninging "Destination file exists"
        exit_code=2
    fi
}

function install_user_space_runtime() {
    local dir user_space_runtime
    local -a root_tree

    user_space_runtime="${path_to_runtime_root}/local"

    root_tree=(
        "${user_space_runtime}/bin"
        "${user_space_runtime}/config"
        "${user_space_runtime}/include"
        "${user_space_runtime}/lib"
        "${user_space_runtime}/private"
        "${user_space_runtime}/share"
        "${user_space_runtime}/src"
    )

    echo -e "${bold_green}${sparkles} Installing 'User Space'${end}"

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            exit_code=1
        }
    done

    # Make lib64 → lib symlink
    ln -f -s -n "./lib" "${user_space_runtime}/lib64" || {
        echo_error "Failed to create '${user_space_runtime}/lib64' symlink."
        exit_code=1
    }

    # Setting envroot
    touch "${user_space_runtime}/.envroot" || {
        echo_error "Failed to create '${user_space_runtime}/.envroot'."
        exit_code=1
    }

    echo -e "Done!"
    echo
}

function link_user_space_runtime() {
    local runtimefarm_path runtimefarm_name excluded

    runtimefarm_path="$1"
    runtimefarm_name="$2"

    excluded=("lib64" ".envroot")

    echo -e "${bold_green}${sparkles} Symlinking 'User Space'${end}"

    # If there isn't a symlink farm, then we incur the risk of using system binaries,
    # therefore this is a hard stop.

    link_prefix_to_farm "${path_to_runtime_root}/local" "${runtimefarm_path}" "${excluded[@]}" || {
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${runtimefarm_path}"
        echo_error "Failed to build ${runtimefarm_name}." "errexit"
    }

    echo -e "Completed!"
    echo
}

# TODO(carlogtt): optimize these two functions as they are the same
function fix_shebang_shim() {
    local runtimefarm_path python_dir filepath first_line tmp shebang

    runtimefarm_path="$1"
    python_dir="${runtimefarm_path}/CPython/${python_full_version}"

    if [[ -z "${runtimefarm_path}" ]]; then
        echo_error "Missing argument: 'runtimefarm_path'"
        exit_code=1
        return 1
    fi

    if [[ ! -d "${python_dir}" ]]; then
        echo_error "Missing runtimefarm directory: '${python_dir}'"
        exit_code=1
        return 1
    fi

    echo -e "${bold_green}${sparkles} Fixing shebang shim for executables${end}"

    while IFS= read -r -d '' filepath; do
        if [[ ! -e "${filepath}" ]]; then
            continue
        fi
        if ! grep -Iq . "${filepath}" 2>/dev/null; then
            continue
        fi

        IFS= read -r first_line <"${filepath}" || continue

        if [[ "${first_line}" != "#!/"* ]]; then
            continue
        fi
        if [[ "${first_line}" != *"python3"* ]]; then
            continue
        fi

        tmp="${filepath}.shim"
        shebang="#!/${cli_name}/bin/envroot \"\$ENVROOT/CPython/${python_full_version}/bin/python${python_version}\""

        echo -e "Fixing ${filepath}"

        {
            printf '%s\n' "${shebang}"
            tail -n +2 "${filepath}"
        } >"${tmp}" || {
            echo_error "Failed to update shebang for '${filepath}'."
            exit_code=1
        }

        cat "${tmp}" >"${filepath}" || {
            echo_error "Failed to update shebang for '${filepath}'."
            exit_code=1
        }

        rm -rf "${tmp}" || {
            echo_error "Failed to remove '${tmp}'."
            exit_code=1
        }
    done < <(
        find "${python_dir}" \
            \( -path "${python_dir}/include" \
            -o -path "${python_dir}/lib" \
            -o -path "${python_dir}/lib64" \
            -o -path "${python_dir}/local" \
            -o -path "${python_dir}/share" \) -prune -o \
            \( -type f -o -type l \) \
            -print0
    )

    echo -e "Done!"
    echo
}

function fix_shebang_python_runtime() {
    local python_dir filepath first_line tmp shebang

    python_dir="${path_to_runtime_root}/CPython/${python_full_version}/runtime"

    if [[ ! -d "${python_dir}" ]]; then
        echo_error "Missing runtimefarm directory: '${python_dir}'"
        exit_code=1
        return 1
    fi

    echo -e "${bold_green}${sparkles} Fixing shebang shim for executables${end}"

    while IFS= read -r -d '' filepath; do
        if [[ ! -e "${filepath}" ]]; then
            continue
        fi
        if ! grep -Iq . "${filepath}" 2>/dev/null; then
            continue
        fi

        IFS= read -r first_line <"${filepath}" || continue

        if [[ "${first_line}" != "#!/"* ]]; then
            continue
        fi
        if [[ "${first_line}" != *"python3"* ]]; then
            continue
        fi

        tmp="${filepath}.shim"
        shebang="#!/${cli_name}/bin/envroot \"\$ENVROOT/CPython/${python_full_version}/bin/python${python_version}\""

        echo -e "Fixing ${filepath}"

        {
            printf '%s\n' "${shebang}"
            tail -n +2 "${filepath}"
        } >"${tmp}" || {
            echo_error "Failed to update shebang for '${filepath}'."
            exit_code=1
        }

        cat "${tmp}" >"${filepath}" || {
            echo_error "Failed to update shebang for '${filepath}'."
            exit_code=1
        }

        rm -rf "${tmp}" || {
            echo_error "Failed to remove '${tmp}'."
            exit_code=1
        }
    done < <(
        find "${python_dir}" \
            \( -path "${python_dir}/include" \
            -o -path "${python_dir}/lib64" \
            -o -path "${python_dir}/local" \
            -o -path "${python_dir}/share" \) -prune -o \
            \( -type f -o -type l \) \
            -print0
    )

    echo -e "Done!"
    echo
}

function install_python_runtime() {
    local dir compression dest_tar single_run_status build_info_file
    local -a root_tree

    single_run_status=0
    dest_tar="${path_to_cache_root}/CPython/${python_pkg_full_name}"
    build_info_file="${path_to_runtime_root}/CPython/${python_full_version}/build-py${python_full_version}"
    root_tree=(
        "${path_to_cache_root}/CPython"
        "${path_to_runtime_root}/CPython/${python_full_version}"
    )

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            single_run_status=1
            exit_code=1
        }
    done

    echo -e "${bold_green}${sparkles} Installing 'Python${python_full_version}'${end}"

    # If the runtime already exists, use cached
    if [[ -f "${build_info_file}" ]]; then
        echo -e "Using cached installation"
        echo
        return
    fi

    # TODO(carlogtt): this should be wrapped in a lock system to prevent race in the cache dir.
    #  The wrapper should start from the download and end after the tar extract.

    # If the tar is in icarus cache, skip the download and unpack
    if [[ ! -e "${dest_tar}" ]]; then
        curl -L "${python_pkg_download_url}" -o "${dest_tar}" || {
            echo_error "Failed to download '${python_pkg_name}'."
            single_run_status=1
            exit_code=1
        }
        echo
    fi

    # Clean any partial or old dir left there before moving to runtime root.
    rm -rf "${path_to_runtime_root}/CPython/${python_full_version}/${python_full_version}" || {
        echo_error "Failed to remove '${path_to_runtime_root}/CPython/${python_full_version}/${python_full_version}'."
        single_run_status=1
        exit_code=1
    }
    rm -rf "${path_to_runtime_root}/CPython/${python_full_version}/runtime" || {
        echo_error "Failed to remove '${path_to_runtime_root}/CPython/${python_full_version}/runtime'."
        single_run_status=1
        exit_code=1
    }

    # Unpacking.
    compression="$(file "${dest_tar}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')" || {
        echo_error "Failed to detect '${dest_tar}' compression type."
        exit_code=1
    }
    tar -v -x --"${compression}" -f "${dest_tar}" -C "${path_to_runtime_root}/CPython/${python_full_version}" || {
        echo_error "Failed to unpack '${python_pkg_name}'."
        single_run_status=1
        exit_code=1
    }

    # Unpack by default in ${python_full_version} we need to rename it to: 'runtime' dir.
    mv "${path_to_runtime_root}/CPython/${python_full_version}/${python_full_version}" "${path_to_runtime_root}/CPython/${python_full_version}/runtime" || {
        echo_error "Failed to move '${path_to_runtime_root}/CPython/${python_full_version}/${python_full_version}' to '${path_to_runtime_root}/CPython/${python_full_version}/runtime'."
        single_run_status=1
        exit_code=1
    }

    if [[ "${single_run_status}" -eq 0 ]]; then
        echo -e "Done!"
        echo
    fi

    # Fixing runtime shebang
    fix_shebang_python_runtime

    # Save the build release info
    printf '%s\n' \
        "# The path command creates build variables from a graph of dependencies defined in package." \
        "# It is strongly recommended that you use the ${cli_name} builder path command to manage" \
        "# your environments." \
        "" \
        "build_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "python_version=${python_version}" \
        "python_full_version=${python_full_version}" \
        "platform_identifier=${platform_identifier}" \
        "python_pkg_name=${python_pkg_name}" \
        "python_pkg_full_name=${python_pkg_full_name}" \
        "python_pkg_download_url=${python_pkg_download_url}" \
        "runtime_root=${path_to_runtime_root}/CPython/${python_full_version}" \
        >"${build_info_file}" || {
        echo_error "Failed to create '${build_info_file}'."
        exit_code=1
    }
}

function link_python_runtime() {
    local runtimefarm_path runtimefarm_name path_to_python_runtime path_to_python_farm excluded

    runtimefarm_path="$1"
    runtimefarm_name="$2"
    path_to_python_runtime="${path_to_runtime_root}/CPython/${python_full_version}/runtime"
    path_to_python_farm="${runtimefarm_path}/CPython/${python_full_version}"

    excluded=("lib64" ".envroot")

    echo -e "${bold_green}${sparkles} Symlinking 'Python${python_full_version}'${end}"

    # If there isn't a symlink farm, then we incur the risk of using system binaries,
    # therefore this is a hard stop.

    link_prefix_to_farm "${path_to_python_runtime}" "${path_to_python_farm}" "${excluded[@]}" || {
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${runtimefarm_path}"
        echo_error "Failed to build ${runtimefarm_name}." "errexit"
    }

    # Make lib64 → lib symlink
    ln -f -s -n "./lib" "${path_to_python_farm}/lib64" || {
        echo_error "Failed to create '${path_to_python_farm}/lib64' symlink."
        exit_code=1
    }

    echo -e "Completed!"
    echo
}

function build_runtimefarm_tree() {
    local dir farm_path
    local -a root_tree

    farm_path=$1
    if [[ -z "${farm_path}" ]]; then
        echo_error "Missing argument: 'farm_path'"
        exit_code=1
    fi

    # Do NOT rm -rf the existing tree because when performing the
    # python versions loop will remove the previous version env ready file.
    mkdir -p "${farm_path}" || {
        echo_error "Failed to create '${farm_path}'."
        exit_code=1
    }

    root_tree=(
        "${farm_path}/bin"
        "${farm_path}/config"
        "${farm_path}/include"
        "${farm_path}/lib"
        "${farm_path}/private"
        "${farm_path}/farm-info"
        "${farm_path}/share"
        "${farm_path}/src"
    )

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            exit_code=1
        }
    done

    # Make lib64 → lib symlink
    ln -f -s -n "./lib" "${farm_path}/lib64" || {
        echo_error "Failed to create '${farm_path}/lib64' symlink."
        exit_code=1
    }

    # Setting envroot
    touch "${farm_path}/.envroot" || {
        echo_error "Failed to create '${farm_path}/.envroot'."
        exit_code=1
    }
}

function build_runtimefarm_icarus_python3() {
    local runtimefarm_path path_to_python_runtime path_to_python_farm

    runtimefarm_path="$1"
    path_to_python_runtime="${path_to_runtime_root}/CPython/${python_full_version}"
    path_to_python_farm="${runtimefarm_path}/CPython/${python_full_version}"

    echo -e "${bold_green}${sparkles} Building farm${end}"
    build_runtimefarm_tree "${runtimefarm_path}"
    echo -e "Done!"

    # icarus builder path do not need to set PYTHONPATH, this could be done by the
    # icarus builder if a composition is needed.
    pythonpath=""
    pythonpath_line="# PYTHONPATH='${pythonpath}'"

    printf '%s\n' \
        "# The path command creates build variables from a graph of dependencies defined in package." \
        "# It is strongly recommended that you use the ${cli_name} builder path command to manage" \
        "# your environments." \
        "" \
        "# The pathname to the farm." \
        "FARMHOME='${runtimefarm_path}'" \
        "" \
        "# The PATH for the farm." \
        "FARMPATH='${runtimefarm_path}/bin:${path_to_python_farm}/bin'" \
        "" \
        "# Change the location of the standard Python libraries." \
        "# By default, the libraries are searched in prefix/lib/pythonversion and exec_prefix/lib/pythonversion," \
        "# where prefix and exec_prefix are installation-dependent directories, both defaulting to /usr/local." \
        "#" \
        "# When PYTHONHOME is set to a single directory, its value replaces both prefix and exec_prefix." \
        "# To specify different values for these, set PYTHONHOME to prefix:exec_prefix." \
        "PYTHONHOME='${path_to_python_farm}'" \
        "" \
        "# Augment the default search path for module files. The format is the same as the shell’s PATH:" \
        "# one or more directory pathnames separated by os.pathsep (e.g. colons on Unix or semicolons on Windows). " \
        "# Non-existent directories are silently ignored." \
        "#" \
        "# In addition to normal directories, individual PYTHONPATH entries may refer to zipfiles containing" \
        "# pure Python modules (in either source or compiled form). Extension modules cannot be imported" \
        "# from zipfiles." \
        "#" \
        "# The default search path is installation dependent, but generally begins with prefix/lib/pythonversion" \
        "# (see PYTHONHOME above). It is always appended to PYTHONPATH." \
        "#" \
        "# An additional directory will be inserted in the search path in front of PYTHONPATH as described" \
        "# above under Interface options. The search path can be manipulated from within a Python program" \
        "# as the variable sys.path." \
        "${pythonpath_line}" \
        "" \
        "# The pathname of the executable Python binary." \
        "PYTHONBIN='${path_to_python_farm}/bin/python${python_version}'" \
        >"${runtimefarm_path}/farm-info/path-py${python_full_version}" || {
        exit_code=1
        echo_error "Failed to create 'path-py${python_full_version}'."
    }

    echo
}

function pip_pip() {
    local p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    report_path="${path_to_path_cache_root}/pip_${p_graph}_${p_recipe}_${p_ver}"

    echo -e "${bold_green}${sparkles} Caching [${installation_type}] [pip] dependencies graph${end}"
    "${PYTHONBIN}" -m pip install \
        --dry-run \
        --ignore-installed \
        --report "${report_path}.${installation_type}" \
        pip || {
        echo_error "Failed to cache [${installation_type}] dependencies graph."
        exit_code=1
    }
    echo

    if [[ "${installation_type}" == "build" ]]; then
        echo -e "${bold_green}${sparkles} Installing pip${end}"
        "${PYTHONBIN}" -m pip install \
            --force-reinstall \
            --no-warn-script-location \
            pip || {
            echo_error "Failed to install pip."
            exit_code=1
        }
    elif [[ "${installation_type}" == "sync" ]]; then
        echo -e "${bold_green}${sparkles} Syncing pip${end}"
        if [[ ! -f "${report_path}.build" ]]; then
            echo_warning "No [build] dependencies graph found."
            pip_pip "${p_name}" "build"
        elif ! diff -q "${report_path}.build" "${report_path}.sync" >/dev/null 2>&1; then
            echo_warning "Requirements changed."
            pip_pip "${p_name}" "build"
        else
            echo -e "Sync complete!"
        fi
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi

    echo
}

function pip_target_package() {
    local p_name p_graph p_recipe p_ver installation_type report_path
    local -a pkg

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    report_path="${path_to_path_cache_root}/${package_name_dashed}_${p_graph}_${p_recipe}_${p_ver}"
    pkg=("${path_to_dist_root}/${package_name_snake_case}"*.whl)

    if [[ ! -f "${pkg[0]}" ]]; then
        echo_error "Package '${package_name_snake_case}' not found! Have you built it?."
        exit_code=1
        return
    fi
    if [[ "${#pkg[@]}" -gt 1 ]]; then
        echo_error "Multiple wheels found for '${package_name_snake_case}'."
        exit_code=1
        return
    fi

    echo -e "${bold_green}${sparkles} Caching [${installation_type}] [target:${package_name_snake_case}] dependencies graph${end}"
    "${PYTHONBIN}" -m pip install \
        --no-deps \
        --dry-run \
        --ignore-installed \
        --report "${report_path}.${installation_type}" \
        "${path_to_dist_root}/${package_name_snake_case}"*.whl || {
        echo_error "Failed to cache [${installation_type}] dependencies graph."
        exit_code=1
    }
    echo

    if [[ "${installation_type}" == "build" ]]; then
        echo -e "${bold_green}${sparkles} Installing ${package_name_snake_case}${end}"
        "${PYTHONBIN}" -m pip install \
            --force-reinstall \
            --no-deps \
            --no-compile \
            --no-warn-script-location \
            "${path_to_dist_root}/${package_name_snake_case}"*.whl || {
            echo_error "Failed to install ${package_name_snake_case}."
            exit_code=1
        }
    elif [[ "${installation_type}" == "sync" ]]; then
        echo_error "Sync unavailable for target packages."
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi

    echo
}

function pip_tool_dependencies() {
    local requirements_path requirements_path_basename p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    for requirements_path in "${tool_requirements_paths[@]}"; do
        requirements_path="${requirements_path##/}"
        requirements_path_basename="$(basename "${requirements_path}")"
        report_path="${path_to_path_cache_root}/$(basename "$(echo "${requirements_path}" | tr '.' '-')_${p_graph}_${p_recipe}_${p_ver}")"

        echo -e "${bold_green}${sparkles} Caching [${installation_type}] [tool:${requirements_path_basename}] dependencies graph${end}"
        "${PYTHONBIN}" -m pip install \
            --dry-run \
            --ignore-installed \
            --report "${report_path}.${installation_type}" \
            --requirement "${project_root_dir_abs}/${requirements_path}" || {
            echo_error "Failed to cache [${installation_type}] dependencies graph."
            exit_code=1
        }
        echo

        if [[ "${installation_type}" == "build" ]]; then
            echo -e "${bold_green}${sparkles} Installing ${requirements_path_basename}${end}"
            "${PYTHONBIN}" -m pip install \
                --force-reinstall \
                --no-compile \
                --no-warn-script-location \
                --requirement "${project_root_dir_abs}/${requirements_path}" || {
                echo_error "Failed to install requirements ${requirements_path_basename}."
                exit_code=1
            }
        elif [[ "${installation_type}" == "sync" ]]; then
            echo -e "${bold_green}${sparkles} Syncing ${requirements_path_basename}${end}"
            if [[ ! -f "${report_path}.build" ]]; then
                echo_warning "No [build] dependencies graph found."
                pip_tool_dependencies "${p_name}" "build"
            elif ! diff -q "${report_path}.build" "${report_path}.sync" >/dev/null 2>&1; then
                echo_warning "Requirements changed."
                pip_tool_dependencies "${p_name}" "build"
            else
                echo -e "Sync complete!"
            fi
        else
            echo_error "Unknown installation type: '${installation_type}'"
            exit_code=1
        fi
    done

    echo
}

function pip_run_dependencies() {
    local p_name p_graph p_recipe p_ver installation_type report_path
    local -a pkg

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    report_path="${path_to_path_cache_root}/run_${p_graph}_${p_recipe}_${p_ver}"

    echo -e "${bold_green}${sparkles} Caching [${installation_type}] [run] dependencies graph${end}"
    "${PYTHONBIN}" -m pip install \
        --dry-run \
        --ignore-installed \
        --report "${report_path}.${installation_type}" \
        "${run_requirements_pyproject_toml[@]}" || {
        echo_error "Failed to cache [${installation_type}] dependencies graph."
        exit_code=1
    }
    echo

    if [[ "${installation_type}" == "build" ]]; then
        echo -e "${bold_green}${sparkles} Installing run dependencies${end}"
        "${PYTHONBIN}" -m pip install \
            --force-reinstall \
            --no-compile \
            --no-warn-script-location \
            "${run_requirements_pyproject_toml[@]}" || {
            echo_error "Failed to install run dependencies."
            exit_code=1
        }
    elif [[ "${installation_type}" == "sync" ]]; then
        echo -e "${bold_green}${sparkles} Syncing run dependencies${end}"
        if [[ ! -f "${report_path}.build" ]]; then
            echo_warning "No [build] dependencies graph found."
            pip_run_dependencies "${p_name}" "build"
        elif ! diff -q "${report_path}.build" "${report_path}.sync" >/dev/null 2>&1; then
            echo_warning "Requirements changed."
            pip_run_dependencies "${p_name}" "build"
        else
            echo -e "Sync complete!"
        fi
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi

    echo
}

function pip_run_dependencies_legacy() {
    local requirements_path requirements_path_basename p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    for requirements_path in "${run_requirements_paths[@]}"; do
        requirements_path="${requirements_path##/}"
        requirements_path_basename="$(basename "${requirements_path}")"
        report_path="${path_to_path_cache_root}/$(basename "$(echo "${requirements_path}" | tr '.' '-')_${p_graph}_${p_recipe}_${p_ver}")"

        echo -e "${bold_green}${sparkles} Caching [${installation_type}] [run-legacy:${requirements_path_basename}] dependencies graph${end}"
        "${PYTHONBIN}" -m pip install \
            --dry-run \
            --ignore-installed \
            --report "${report_path}.${installation_type}" \
            --requirement "${project_root_dir_abs}/${requirements_path}" || {
            echo_error "Failed to cache [${installation_type}] dependencies graph."
            exit_code=1
        }
        echo

        if [[ "${installation_type}" == "build" ]]; then
            echo -e "${bold_green}${sparkles} Installing ${requirements_path_basename}${end}"
            "${PYTHONBIN}" -m pip install \
                --force-reinstall \
                --no-compile \
                --no-warn-script-location \
                --requirement "${project_root_dir_abs}/${requirements_path}" || {
                echo_error "Failed to install requirements ${requirements_path_basename}."
                exit_code=1
            }
        elif [[ "${installation_type}" == "sync" ]]; then
            echo -e "${bold_green}${sparkles} Syncing ${requirements_path_basename}${end}"
            if [[ ! -f "${report_path}.build" ]]; then
                echo_warning "No [build] dependencies graph found."
                pip_run_dependencies_legacy "${p_name}" "build"
            elif ! diff -q "${report_path}.build" "${report_path}.sync" >/dev/null 2>&1; then
                echo_warning "Requirements changed."
                pip_run_dependencies_legacy "${p_name}" "build"
            else
                echo -e "Sync complete!"
            fi
        else
            echo_error "Unknown installation type: '${installation_type}'"
            exit_code=1
        fi
    done

    echo
}

function pip_dev_dependencies() {
    local requirements_path requirements_path_basename p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    for requirements_path in "${dev_requirements_paths[@]}"; do
        requirements_path="${requirements_path##/}"
        requirements_path_basename="$(basename "${requirements_path}")"
        report_path="${path_to_path_cache_root}/$(basename "$(echo "${requirements_path}" | tr '.' '-')_${p_graph}_${p_recipe}_${p_ver}")"

        echo -e "${bold_green}${sparkles} Caching [${installation_type}] [dev:${requirements_path_basename}] dependencies graph${end}"
        "${PYTHONBIN}" -m pip install \
            --dry-run \
            --ignore-installed \
            --report "${report_path}.${installation_type}" \
            --requirement "${project_root_dir_abs}/${requirements_path}" || {
            echo_error "Failed to cache [${installation_type}] dependencies graph."
            exit_code=1
        }
        echo

        if [[ "${installation_type}" == "build" ]]; then
            echo -e "${bold_green}${sparkles} Installing ${requirements_path_basename}${end}"
            "${PYTHONBIN}" -m pip install \
                --force-reinstall \
                --no-compile \
                --no-warn-script-location \
                --requirement "${project_root_dir_abs}/${requirements_path}" || {
                echo_error "Failed to install requirements ${requirements_path_basename}."
                exit_code=1
            }
        elif [[ "${installation_type}" == "sync" ]]; then
            echo -e "${bold_green}${sparkles} Syncing ${requirements_path_basename}${end}"
            if [[ ! -f "${report_path}.build" ]]; then
                echo_warning "No [build] dependencies graph found."
                pip_dev_dependencies "${p_name}" "build"
            elif ! diff -q "${report_path}.build" "${report_path}.sync" >/dev/null 2>&1; then
                echo_warning "Requirements changed."
                pip_dev_dependencies "${p_name}" "build"
            else
                echo -e "Sync complete!"
            fi
        else
            echo_error "Unknown installation type: '${installation_type}'"
            exit_code=1
        fi
    done

    echo
}

function write_python_packages_release_info() {
    if [[ -z "${FARMHOME}" ]]; then
        echo_error "Failed to resolve FARMHOME."
        exit_code=1
    fi

    "${PYTHONBIN}" -m pip freeze --all >"${FARMHOME}/farm-info/packages-py${python_full_version}" || {
        echo_error "Failed to create 'packages-py${python_full_version}'."
        exit_code=1
    }
}

function mark_farm_ready_icarus_python3() {
    local farm_path installation_type farm_ready_file

    farm_path=$1
    installation_type=$2
    farm_ready_file="${farm_path}/farm-info/ready-py${python_full_version}"

    if [[ -z "${farm_path}" ]] || [[ -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return 1
    fi

    # path_name is the global env passed in by the cli.

    if [[ "${installation_type}" == "build" ]]; then
        printf '%s\n' \
            "# The path command creates build variables from a graph of dependencies defined in package." \
            "# It is strongly recommended that you use the ${cli_name} builder path command to manage" \
            "# your environments." \
            "" \
            "ready=true" \
            "timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
            "python_version=${python_version}" \
            "python_full_version=${python_full_version}" \
            "farm_name=${path_name}" \
            "farm_path=${farm_path}" \
            >"${farm_ready_file}" || {
            # We invalidate the farm and error
            clean_farm "${farm_path}"
            echo_error "Failed to [${installation_type}] '${farm_ready_file}'."
            exit_code=1
        }
    elif [[ "${installation_type}" == "sync" ]]; then
        printf '%s\n' \
            "" \
            "action=${installation_type}" \
            "timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
            >>"${farm_ready_file}" || {
            # We invalidate the farm and error
            clean_farm "${farm_path}"
            echo_error "Failed to [${installation_type}] '${farm_ready_file}'."
            exit_code=1
        }
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi
}

function clean_farm() {
    local farm_path

    farm_path=$1

    rm -rf "${farm_path}" || {
        echo_error "Failed to remove '${farm_path}'."
        exit_code=1
    }
}

function activate_farm_icarus_python3() {
    local runtimefarm_path

    runtimefarm_path=$1

    # Clear previous exports
    deactivate_farm_icarus_python3

    # If there isn't a farm, then we incur the risk of using system binaries,
    # therefore this is a hard stop, using errexit.

    if [[ -f "${runtimefarm_path}/farm-info/path-py${python_full_version}" ]]; then
        set -a
        # shellcheck disable=SC1090
        . "${runtimefarm_path}/farm-info/path-py${python_full_version}" || {
            exit_code=1
            # We invalidate the farm and error
            clean_farm "${runtimefarm_path}"
            echo_error "Failed to activate farm." "errexit"
        }
        set +a
    else
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${runtimefarm_path}"
        echo_error "Failed to activate farm." "errexit"
    fi
}

function deactivate_farm_icarus_python3() {
    unset FARMHOME FARMPATH PYTHONHOME PYTHONPATH PYTHONBIN
}

####################################################################################################
# DISPATCHERS
####################################################################################################
function build_path_icarus_python3() {
    local path installation_type

    path="${1}"
    installation_type=""

    if [[ -z "${path}" ]]; then
        echo_error "Missing argument: 'path'"
        exit_code=1
    fi

    case "${path}" in
    "${path_platform_identifier_name}")
        only_with_python_default=true
        response="${platform_identifier}"
        ;;
    "${path_pkg_name_pascal_name}")
        only_with_python_default=true
        response="${package_name_pascal_case}"
        ;;
    "${path_pkg_name_snake_name}")
        only_with_python_default=true
        response="${package_name_snake_case}"
        ;;
    "${path_pkg_name_dashed_name}")
        only_with_python_default=true
        response="${package_name_dashed}"
        ;;
    "${path_pkg_language_name}")
        only_with_python_default=true
        response="${package_language}"
        ;;
    "${path_pkg_version_full_name}")
        only_with_python_default=true
        response="${package_version_full}"
        ;;
    "${path_pkg_version_major_name}")
        only_with_python_default=true
        response="${package_version_major}"
        ;;
    "${path_pkg_version_minor_name}")
        only_with_python_default=true
        response="${package_version_minor}"
        ;;
    "${path_pkg_version_patch_name}")
        only_with_python_default=true
        response="${package_version_patch}"
        ;;
    "${path_ws_root_name}")
        only_with_python_default=true
        response="${project_root_dir_abs}"
        ;;
    "${path_ws_src_root_name}")
        only_with_python_default=true
        response="${project_root_dir_abs}/src"
        ;;
    "${path_ws_build_root_name}")
        only_with_python_default=true
        response="${project_root_dir_abs}/${build_root_dir}"
        ;;
    "${path_ws_user_space_root_name}")
        only_with_python_default=true
        response="${path_to_runtime_root}/local"
        ;;
    "${path_tool_runtimefarm_name}")
        if [[ ! -f "${tool_runtimefarm_root}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_tool_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${tool_runtimefarm_root}"
            install_user_space_runtime
            link_user_space_runtime "${tool_runtimefarm_root}" "${path_tool_runtimefarm_name}"
            install_python_runtime
            link_python_runtime "${tool_runtimefarm_root}" "${path_tool_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_tool_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${tool_runtimefarm_root}"
        pip_pip "${path_tool_runtimefarm_name}" "${installation_type}"
        pip_tool_dependencies "${path_tool_runtimefarm_name}" "${installation_type}"
        write_python_packages_release_info
        fix_shebang_shim "${tool_runtimefarm_root}"
        mark_farm_ready_icarus_python3 "${tool_runtimefarm_root}" "${installation_type}"
        deactivate_farm_icarus_python3
        response="${tool_runtimefarm_root}"
        ;;
    "${path_pkg_runtimefarm_name}")
        if [[ ! -f "${pkg_runtimefarm_root}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_pkg_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${pkg_runtimefarm_root}"
            install_user_space_runtime
            link_user_space_runtime "${pkg_runtimefarm_root}" "${path_pkg_runtimefarm_name}"
            install_python_runtime
            link_python_runtime "${pkg_runtimefarm_root}" "${path_pkg_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_pkg_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${pkg_runtimefarm_root}"
        pip_pip "${path_pkg_runtimefarm_name}" "${installation_type}"
        pip_target_package "${path_pkg_runtimefarm_name}" "build" # We never sync pkg_only
        write_python_packages_release_info
        fix_shebang_shim "${pkg_runtimefarm_root}"
        mark_farm_ready_icarus_python3 "${pkg_runtimefarm_root}" "${installation_type}"
        deactivate_farm_icarus_python3
        response="${pkg_runtimefarm_root}"
        ;;
    "${path_run_runtimefarm_name}")
        if [[ ! -f "${run_runtimefarm_root}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_run_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${run_runtimefarm_root}"
            install_user_space_runtime
            link_user_space_runtime "${run_runtimefarm_root}" "${path_run_runtimefarm_name}"
            install_python_runtime
            link_python_runtime "${run_runtimefarm_root}" "${path_run_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_run_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${run_runtimefarm_root}"
        pip_pip "${path_run_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_run_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_run_runtimefarm_name}" "${installation_type}"
        pip_target_package "${path_run_runtimefarm_name}" "build" # This will install a fresh pkg
        write_python_packages_release_info
        fix_shebang_shim "${run_runtimefarm_root}"
        mark_farm_ready_icarus_python3 "${run_runtimefarm_root}" "${installation_type}"
        deactivate_farm_icarus_python3
        response="${run_runtimefarm_root}"
        ;;
    "${path_run_excluderoot_runtimefarm_name}")
        if [[ ! -f "${run_excluderoot_runtimefarm_root}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_run_excluderoot_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${run_excluderoot_runtimefarm_root}"
            install_user_space_runtime
            link_user_space_runtime "${run_excluderoot_runtimefarm_root}" "${path_run_excluderoot_runtimefarm_name}"
            install_python_runtime
            link_python_runtime "${run_excluderoot_runtimefarm_root}" "${path_run_excluderoot_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_run_excluderoot_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${run_excluderoot_runtimefarm_root}"
        pip_pip "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        write_python_packages_release_info
        fix_shebang_shim "${run_excluderoot_runtimefarm_root}"
        mark_farm_ready_icarus_python3 "${run_excluderoot_runtimefarm_root}" "${installation_type}"
        deactivate_farm_icarus_python3
        response="${run_excluderoot_runtimefarm_root}"
        ;;
    "${path_devrun_runtimefarm_name}")
        if [[ ! -f "${devrun_runtimefarm_root}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_devrun_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${devrun_runtimefarm_root}"
            install_user_space_runtime
            link_user_space_runtime "${devrun_runtimefarm_root}" "${path_devrun_runtimefarm_name}"
            install_python_runtime
            link_python_runtime "${devrun_runtimefarm_root}" "${path_devrun_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_devrun_runtimefarm_name}${end}"
            deactivate_farm_icarus_python3
        fi
        activate_farm_icarus_python3 "${devrun_runtimefarm_root}"
        pip_pip "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_dev_dependencies "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_target_package "${path_devrun_runtimefarm_name}" "build" # This will install a fresh pkg
        write_python_packages_release_info
        fix_shebang_shim "${devrun_runtimefarm_root}"
        mark_farm_ready_icarus_python3 "${devrun_runtimefarm_root}" "${installation_type}"
        deactivate_farm_icarus_python3
        response="${devrun_runtimefarm_root}"
        ;;
    "${path_devrun_excluderoot_runtimefarm_name}")
        if [[ ! -f "${devrun_excluderoot_runtimefarm_root}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_devrun_excluderoot_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${devrun_excluderoot_runtimefarm_root}"
            install_user_space_runtime
            link_user_space_runtime "${devrun_excluderoot_runtimefarm_root}" "${path_devrun_excluderoot_runtimefarm_name}"
            install_python_runtime
            link_python_runtime "${devrun_excluderoot_runtimefarm_root}" "${path_devrun_excluderoot_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_devrun_excluderoot_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${devrun_excluderoot_runtimefarm_root}"
        pip_pip "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_dev_dependencies "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        write_python_packages_release_info
        fix_shebang_shim "${devrun_excluderoot_runtimefarm_root}"
        mark_farm_ready_icarus_python3 "${devrun_excluderoot_runtimefarm_root}" "${installation_type}"
        deactivate_farm_icarus_python3
        response="${devrun_excluderoot_runtimefarm_root}"
        ;;
    "${path_tool_pythonhome_name}")
        response="${response:+${response}:}${tool_runtimefarm_root}/CPython/${python_full_version}"
        ;;
    "${path_pkg_pythonhome_name}")
        response="${response:+${response}:}${pkg_runtimefarm_root}/CPython/${python_full_version}"
        ;;
    "${path_run_pythonhome_name}")
        response="${response:+${response}:}${run_runtimefarm_root}/CPython/${python_full_version}"
        ;;
    "${path_run_excluderoot_pythonhome_name}")
        response="${response:+${response}:}${run_excluderoot_runtimefarm_root}/CPython/${python_full_version}"
        ;;
    "${path_devrun_pythonhome_name}")
        response="${response:+${response}:}${devrun_runtimefarm_root}/CPython/${python_full_version}"
        ;;
    "${path_devrun_excluderoot_pythonhome_name}")
        response="${response:+${response}:}${devrun_excluderoot_runtimefarm_root}/CPython/${python_full_version}"
        ;;
    *)
        echo_error "Unknown path: '${path}'"
        exit_code=1
        ;;
    esac
}

function build_path_icarus_cdk() {
    :
}

function dispatch_build_system() {
    local python_version_composite path

    if [[ "${list_paths}" == "Y" ]]; then
        for path in "${path_all_names[@]}"; do
            echo "${path}"
        done
        return
    fi

    # We wrap this in a group and redirect to stderr to avoid environment pollution
    # and only print on stdout the path response so the caller can capture it.
    {
        if [[ "${build_system_in_use}" == "icarus-python3" ]]; then
            for python_version_composite in "${python_versions[@]}"; do
                set_icarus_python3_constants "${python_version_composite}"
                build_path_icarus_python3 "${path_name}"
                if [[ "${only_with_python_default}" == true ]]; then
                    # Those command that set only_with_python_default, only runs
                    # with the python-default which is the first in the loop.
                    break
                fi
            done
        elif [[ "${build_system_in_use}" == "icarus-cdk" ]]; then
            set_icarus_cdk_constants
            build_path_icarus_cdk
        fi
    } 2>/dev/stderr 1>&2

    if [[ "${exit_code}" != 1 ]]; then
        printf '%s\n' "${response}"
    fi
}

####################################################################################################
# MAIN
####################################################################################################
function main() {
    validate_prerequisites

    set_constants "${@}"
    ensure_icarus_build_root_env

    dispatch_build_system

    return "${exit_code}"
}

main "${@}"
