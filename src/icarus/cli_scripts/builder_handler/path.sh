#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/path.sh
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

    # Declaring global vars from `builder_base`
    # This must be done after the `eval "${@}"` call
    declare_global_vars

    exit_code=0
    response=''
}

function ensure_icarus_build_root_env() {
    local dir
    local -a root_tree

    runtime_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/runtime"
    path_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/env/path"
    path_cache_root="${path_root}/path-cache"

    root_tree=(
        "${path_to_cache_root}"
        "${runtime_root}"
        "${path_root}"
        "${path_cache_root}"
    )

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            exit_code=1
        }
    done

    declare -g -r runtime_root
    declare -g -r path_root
    declare -g -r path_cache_root
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

    artifact_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/dist/CPython/${python_full_version}/${package_name_snake_case}-${package_version_full}"

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
        echo_warning "Destination file exists"
        exit_code=2
    fi
}

function install_user_space_runtime() {
    local dir user_space_runtime
    local -a root_tree

    user_space_runtime="${runtime_root}/local"

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

function link_user_space_runtime_into_runtimefarm() {
    local farm_path p_name
    local -a excluded

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    excluded=("lib64" ".envroot")

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    echo -e "${bold_green}${sparkles} Symlinking 'User Space' into ${p_name}${end}"

    # If there isn't a symlink farm, then we incur the risk of using system binaries,
    # therefore this is a hard stop.

    link_prefix_to_farm "${runtime_root}/local" "${farm_path}" "${excluded[@]}" || {
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${p_name}"
        echo_error "Failed to symlink 'User Space' into ${p_name}." "errexit"
    }

    echo -e "Completed!"
    echo
}

function fix_shebang_shim_core() {
    local python_dir filepath first_line tmp shebang d
    local -a prune_dirs prune_expr

    python_dir="$1"
    shift
    prune_dirs=("$@")

    if [[ ! -d "${python_dir}" ]]; then
        echo_error "Missing directory: '${python_dir}'"
        exit_code=1
        return 1
    fi

    echo -e "${bold_green}${sparkles} Fixing shebang shim${end}"

    # Build find prune expression
    prune_expr=()
    for d in "${prune_dirs[@]}"; do
        if ((${#prune_expr[@]} > 0)); then
            prune_expr+=("-o")
        fi
        prune_expr+=("-path" "${python_dir}/${d}")
    done

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
        if ((${#prune_expr[@]} > 0)); then
            find "${python_dir}" \( "${prune_expr[@]}" \) -prune -o \( -type f -o -type l \) -print0
        else
            find "${python_dir}" \( -type f -o -type l \) -print0
        fi
    )

    echo -e "Done!"
    echo
}

function fix_shebang_shim() {
    local p_name farm_path python_dir

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    python_dir="${farm_path}/CPython/${python_full_version}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    fix_shebang_shim_core "${python_dir}" "include" "lib" "lib64" "local" "share"
}

function install_python_runtime() {
    local dir compression dest_tar single_run_status build_info_file python_dir retries max_retries
    local -a root_tree

    # Initializing single_run_status per python version.
    single_run_status=0

    dest_tar="${path_to_cache_root}/CPython/${python_pkg_full_name}"
    build_info_file="${runtime_root}/CPython/${python_full_version}/build-py${python_full_version}"
    python_dir="${runtime_root}/CPython/${python_full_version}/runtime"
    root_tree=(
        "${path_to_cache_root}/CPython"
        "${runtime_root}/CPython/${python_full_version}"
    )

    # 30 min -> 2 sec sleep * 900 secs
    retries=0
    max_retries=900

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            single_run_status=1
            exit_code=1
        }
    done

    echo -e "${bold_green}${sparkles} Installing 'Python${python_full_version}'${end}"

    # If the runtime is already created, use it
    if [[ -f "${build_info_file}" ]]; then
        echo -e "Using cached runtime"
        echo
        return
    fi

    # Download or use cached one
    # The while loop is used to prevent race conditions.
    while true; do
        # File exists, assume download complete.
        if [[ -f "${dest_tar}" && ! -d "${dest_tar}.lock" ]]; then
            echo -e "Using cached ${python_pkg_full_name}"
            echo
            break

        # mkdir is atomic—only one process will succeed.
        # Successfully acquired lock; perform the download.
        elif mkdir "${dest_tar}.lock" 2>/dev/null; then
            echo -e "Downloading ${python_pkg_full_name}"
            echo
            # Cleanup / Remove partial download just in case was left there
            rm -rf "${dest_tar}" || {
                echo_error "Failed to remove '${dest_tar}'."
                single_run_status=1
                exit_code=1
            }
            # Check if python version is available on https://github.com/64rl0/PythonRuntime
            if curl -s -f -L -I "${python_pkg_download_url}" -o "/dev/null"; then
                # Download
                curl -L "${python_pkg_download_url}" -o "${dest_tar}" || {
                    echo_error "Failed to download '${python_pkg_name}'."
                    single_run_status=1
                    exit_code=1
                    # Remove partial download
                    rm -rf "${dest_tar}" || {
                        echo_error "Failed to remove '${dest_tar}'."
                    }
                }
                echo
            else
                echo_error "${python_pkg_full_name} not available on https://github.com/64rl0/PythonRuntime"
                single_run_status=1
                exit_code=1
            fi
            # Always release the lock before breaking the loop
            rm -rf "${dest_tar}.lock" || {
                echo_error "Failed to remove '${dest_tar}.lock'."
                single_run_status=1
                exit_code=1
            }
            break

        # Someone else is downloading; wait for them to finish.
        else
            ((retries = retries + 1))
            if ((retries >= max_retries)); then
                echo_error "Timed out waiting for ${python_pkg_name} download lock."
                single_run_status=1
                exit_code=1
                break
            fi
            echo -e "Waiting for download own by another process to complete..."
            sleep 2
        fi
    done

    # After the download process we verify the single_run_status to check if
    # the download was successful.
    if [[ "${single_run_status}" -ne 0 ]]; then
        single_run_status=1
        exit_code=1
        return
    fi

    # Clean any partial or old dir left there before moving to runtime root.
    rm -rf "${runtime_root}/CPython/${python_full_version}/${python_full_version}" || {
        echo_error "Failed to remove '${runtime_root}/CPython/${python_full_version}/${python_full_version}'."
        single_run_status=1
        exit_code=1
    }
    rm -rf "${runtime_root}/CPython/${python_full_version}/runtime" || {
        echo_error "Failed to remove '${runtime_root}/CPython/${python_full_version}/runtime'."
        single_run_status=1
        exit_code=1
    }

    # Unpacking.
    compression="$(file "${dest_tar}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')" || {
        echo_error "Failed to detect '${dest_tar}' compression type."
        exit_code=1
    }
    tar -v -x --"${compression}" -f "${dest_tar}" -C "${runtime_root}/CPython/${python_full_version}" || {
        echo_error "Failed to unpack '${python_pkg_name}'."
        single_run_status=1
        exit_code=1
    }

    # Unpack by default in ${python_full_version} we need to rename it to: 'runtime' dir.
    mv "${runtime_root}/CPython/${python_full_version}/${python_full_version}" "${runtime_root}/CPython/${python_full_version}/runtime" || {
        echo_error "Failed to move '${runtime_root}/CPython/${python_full_version}/${python_full_version}' to '${runtime_root}/CPython/${python_full_version}/runtime'."
        single_run_status=1
        exit_code=1
    }

    if [[ "${single_run_status}" -eq 0 ]]; then
        echo -e "Done!"
        echo
    fi

    # Fixing runtime shebang.
    fix_shebang_shim_core "${python_dir}" "include" "lib64" "local" "share"

    # Save the build release info.
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
        "runtime_root=${runtime_root}/CPython/${python_full_version}" \
        >"${build_info_file}" || {
        echo_error "Failed to create '${build_info_file}'."
        exit_code=1
    }
}

function link_python_runtime_into_python_farm() {
    local farm_path p_name path_to_python_runtime path_to_python_farm
    local -a excluded

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    path_to_python_farm="${farm_path}/CPython/${python_full_version}"
    path_to_python_runtime="${runtime_root}/CPython/${python_full_version}/runtime"
    excluded=("lib64" ".envroot")

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    echo -e "${bold_green}${sparkles} Symlinking 'Python${python_full_version}'${end}"

    # If there isn't a symlink farm, then we incur the risk of using system binaries,
    # therefore this is a hard stop.

    link_prefix_to_farm "${path_to_python_runtime}" "${path_to_python_farm}" "${excluded[@]}" || {
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${p_name}"
        echo_error "Failed to symlink 'Python${python_full_version}." "errexit"
    }

    # Make lib64 → lib symlink
    ln -f -s -n "./lib" "${path_to_python_farm}/lib64" || {
        echo_error "Failed to create '${path_to_python_farm}/lib64' symlink."
        exit_code=1
    }

    echo -e "Completed!"
    echo
}

function link_python_runtime_into_runtimefarm() {
    local farm_path p_name path_to_python_farm
    local -a excluded

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    path_to_python_farm="${farm_path}/CPython/${python_full_version}"
    excluded=("lib64" "local" ".envroot")

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    # This function is exclusively allowed if python is the default one!
    if [[ "${is_python_default}" != true ]]; then
        echo_error "The python runtime is not the default one!"
        exit_code=1
        return
    fi

    echo -e "${bold_green}${sparkles} Symlinking 'Python${python_full_version}' [python-default] into ${p_name}${end}"

    link_prefix_to_farm "${path_to_python_farm}" "${farm_path}" "${excluded[@]}" || {
        echo_error "Failed to symlink 'Python${python_full_version}' into ${p_name}."
        exit_code=1
    }

    echo -e "Completed!"
    echo
}

function build_runtimefarm_tree() {
    local p_name dir farm_path
    local -a root_tree

    p_name=$1
    farm_path="${path_root}/${p_name}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
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
    local p_name farm_path path_to_python_farm

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    path_to_python_farm="${farm_path}/CPython/${python_full_version}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    echo -e "${bold_green}${sparkles} Building farm${end}"
    build_runtimefarm_tree "${p_name}"
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
        "FARMHOME='${farm_path}'" \
        "" \
        "# The PATH for the farm." \
        "FARMPATH='${farm_path}/bin:${path_to_python_farm}/bin'" \
        "" \
        "# Change the location of the standard Python libraries." \
        "# By default, the libraries are searched in prefix/lib/pythonversion and exec_prefix/lib/pythonversion," \
        "# where prefix and exec_prefix are installation-dependent directories, both defaulting to /usr/local." \
        "#" \
        "# When PYTHONHOME is set to a single directory, its value replaces both prefix and exec_prefix." \
        "# To specify different values for these, set PYTHONHOME to prefix:exec_prefix." \
        "PYTHONHOME='${path_to_python_farm}'" \
        "" \
        "# Augment the default search path for module files. The format is the same as the shell's PATH:" \
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
        >"${farm_path}/farm-info/path-py${python_full_version}" || {
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
        return
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    report_path="${path_cache_root}/pip_${p_graph}_${p_recipe}_${p_ver}"

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
        echo
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
            echo
        fi
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi
}

function pip_target_package() {
    local p_name p_graph p_recipe p_ver installation_type report_path
    local -a pkg

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    report_path="${path_cache_root}/${package_name_dashed}_${p_graph}_${p_recipe}_${p_ver}"
    pkg=("${artifact_root}/${package_name_snake_case}"*.whl)

    if [[ ! -f "${pkg[0]}" ]]; then
        echo_error "Package artifact '${package_name_snake_case}' not found! Have you built it?"
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
        "${artifact_root}/${package_name_snake_case}"*.whl || {
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
            "${artifact_root}/${package_name_snake_case}"*.whl || {
            echo_error "Failed to install ${package_name_snake_case}."
            exit_code=1
        }
        echo
    elif [[ "${installation_type}" == "sync" ]]; then
        echo_error "Sync unavailable for target packages."
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi
}

function pip_tool_dependencies() {
    local requirements_path requirements_path_basename p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    for requirements_path in "${tool_requirements_paths[@]}"; do
        requirements_path="${requirements_path##/}"
        requirements_path_basename="$(basename "${requirements_path}")"
        report_path="${path_cache_root}/$(basename "$(echo "${requirements_path}" | tr '.' '-')_${p_graph}_${p_recipe}_${p_ver}")"

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
            echo
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
                echo
            fi
        else
            echo_error "Unknown installation type: '${installation_type}'"
            exit_code=1
        fi
    done
}

function pip_run_dependencies() {
    local p_name p_graph p_recipe p_ver installation_type report_path
    local -a pkg

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    report_path="${path_cache_root}/run_${p_graph}_${p_recipe}_${p_ver}"

    echo -e "${bold_green}${sparkles} Caching [${installation_type}] [run:pyproject.toml] dependencies graph${end}"
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
        echo -e "${bold_green}${sparkles} Installing pyproject.toml dependencies${end}"
        "${PYTHONBIN}" -m pip install \
            --force-reinstall \
            --no-compile \
            --no-warn-script-location \
            "${run_requirements_pyproject_toml[@]}" || {
            echo_error "Failed to install pyproject.toml dependencies."
            exit_code=1
        }
        echo
    elif [[ "${installation_type}" == "sync" ]]; then
        echo -e "${bold_green}${sparkles} Syncing pyproject.toml dependencies${end}"
        if [[ ! -f "${report_path}.build" ]]; then
            echo_warning "No [build] dependencies graph found."
            pip_run_dependencies "${p_name}" "build"
        elif ! diff -q "${report_path}.build" "${report_path}.sync" >/dev/null 2>&1; then
            echo_warning "Requirements changed."
            pip_run_dependencies "${p_name}" "build"
        else
            echo -e "Sync complete!"
            echo
        fi
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi
}

function pip_run_dependencies_legacy() {
    local requirements_path requirements_path_basename p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    for requirements_path in "${run_requirements_paths[@]}"; do
        requirements_path="${requirements_path##/}"
        requirements_path_basename="$(basename "${requirements_path}")"
        report_path="${path_cache_root}/$(basename "$(echo "${requirements_path}" | tr '.' '-')_${p_graph}_${p_recipe}_${p_ver}")"

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
            echo
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
                echo
            fi
        else
            echo_error "Unknown installation type: '${installation_type}'"
            exit_code=1
        fi
    done
}

function pip_dev_dependencies() {
    local requirements_path requirements_path_basename p_name p_graph p_recipe p_ver installation_type report_path

    p_name=$1
    installation_type=$2

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return
    fi

    p_graph="$(echo "${p_name}" | cut -d'.' -f 1)"
    p_recipe="$(echo "${p_name}" | cut -d'.' -f 2)"
    p_ver="py-${python_full_version}"

    for requirements_path in "${dev_requirements_paths[@]}"; do
        requirements_path="${requirements_path##/}"
        requirements_path_basename="$(basename "${requirements_path}")"
        report_path="${path_cache_root}/$(basename "$(echo "${requirements_path}" | tr '.' '-')_${p_graph}_${p_recipe}_${p_ver}")"

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
            echo
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
                echo
            fi
        else
            echo_error "Unknown installation type: '${installation_type}'"
            exit_code=1
        fi
    done
}

function write_python_packages_release_info() {
    local p_name farm_path packages_file

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    packages_file="${farm_path}/farm-info/packages-py${python_full_version}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    printf '%s\n' \
        "# The path command creates build variables from a graph of dependencies defined in package." \
        "# It is strongly recommended that you use the ${cli_name} builder path command to manage" \
        "# your environments." \
        "" \
        >"${packages_file}" || {
        echo_error "Failed to create 'packages-py${python_full_version}'."
        exit_code=1
    }

    "${PYTHONBIN}" -m pip freeze --all >>"${packages_file}" || {
        echo_error "Failed to create 'packages-py${python_full_version}'."
        exit_code=1
    }
}

function mark_farm_ready_icarus_python3() {
    local p_name farm_path installation_type farm_ready_file

    p_name="$1"
    installation_type=$2
    farm_path="${path_root}/${p_name}"
    farm_ready_file="${farm_path}/farm-info/ready-py${python_full_version}"

    if [[ -z "${p_name}" || -z "${installation_type}" ]]; then
        echo_error "Missing arguments."
        exit_code=1
        return
    fi

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
            "farm_name=${p_name}" \
            "farm_path=${farm_path}" \
            >"${farm_ready_file}" || {
            echo_error "Failed to [${installation_type}] '${farm_ready_file}'."
            exit_code=1
        }
    elif [[ "${installation_type}" == "sync" ]]; then
        printf '%s\n' \
            "" \
            "action=${installation_type}" \
            "timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
            >>"${farm_ready_file}" || {
            echo_error "Failed to [${installation_type}] '${farm_ready_file}'."
            exit_code=1
        }
    else
        echo_error "Unknown installation type: '${installation_type}'"
        exit_code=1
    fi
}

function validate_farm_integrity() {
    local p_name farm_path

    p_name="$1"
    farm_path="${path_root}/${p_name}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    # We MUST NOT use != 0 because when we return exit_code = 2
    # we do not want to fail the integrity check.
    if [[ "${exit_code}" == 1 ]]; then
        echo_error "Farm integrity check failed!"
        # We invalidate the farm and error
        clean_farm "${p_name}"
        exit_code=1
    fi
}

function clean_farm() {
    local p_name farm_path

    p_name="$1"
    farm_path="${path_root}/${p_name}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    rm -rf "${farm_path}" || {
        echo_error "Failed to remove '${farm_path}'."
        exit_code=1
    }
}

function activate_farm_icarus_python3() {
    local p_name farm_path farm_path_file

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    farm_path_file="${farm_path}/farm-info/path-py${python_full_version}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    # If there isn't a farm, then we incur the risk of using system binaries,
    # therefore this is a hard stop, using errexit.

    if [[ ! -f "${farm_path_file}" ]]; then
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${p_name}"
        echo_error "Failed to activate farm." "errexit"
    fi

    # Clear previous exports
    deactivate_farm_icarus_python3

    set -a
    # shellcheck disable=SC1090
    . "${farm_path_file}" || {
        exit_code=1
        # We invalidate the farm and error
        clean_farm "${p_name}"
        echo_error "Failed to activate farm." "errexit"
    }
    set +a
}

function deactivate_farm_icarus_python3() {
    unset FARMHOME FARMPATH PYTHONHOME PYTHONPATH PYTHONBIN __PYVENV_LAUNCHER__
}

function join_deps() {
    local p_name farm_path python_packages_release_info farm_ready_file

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    farm_ready_file="${farm_path}/farm-info/ready-py${python_full_version}"
    python_packages_release_info="${farm_path}/farm-info/packages-py${python_full_version}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    if [[ ! -f "${farm_ready_file}" ]]; then
        echo_error "Farm not built!"
        exit_code=1
        return 1
    fi

    # Split on space so local imports will be clean
    # exclude empty lines and lines starting with #
    cut -d ' ' -f 1 "${python_packages_release_info}" | grep '^[a-zA-Z]' | paste -s -d ';' -
}

join_deps_names() {
    local p_name farm_path python_packages_release_info farm_ready_file

    p_name="$1"
    farm_path="${path_root}/${p_name}"
    farm_ready_file="${farm_path}/farm-info/ready-py${python_full_version}"
    python_packages_release_info="${farm_path}/farm-info/packages-py${python_full_version}"

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
        return
    fi

    if [[ ! -f "${farm_ready_file}" ]]; then
        echo_error "Farm not built!"
        exit_code=1
        return 1
    fi

    # Split on space so local imports will be clean
    # exclude empty lines and lines starting with #
    cut -d ' ' -f 1 "${python_packages_release_info}" | cut -d '=' -f 1 | grep '^[a-zA-Z]' | paste -s -d ';' -
}

####################################################################################################
# DISPATCHERS
####################################################################################################
function build_path_icarus_python3() {
    local p_name installation_type

    p_name="${1}"
    installation_type=""

    if [[ -z "${p_name}" ]]; then
        echo_error "Missing argument: 'p_name'"
        exit_code=1
    fi

    case "${p_name}" in
    # #############
    # SIMPLE RECIPE
    # #############
    "${path_platform_identifier_name}")
        only_with_python_default=true
        response="${platform_identifier}"
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
        response="${runtime_root}/local"
        ;;
    # #############
    # CONFIG RECIPE
    # #############
    "${path_pkg_config_name}")
        only_with_python_default=true
        response="${project_root_dir_abs}/icarus.cfg"
        ;;
    # ###############
    # LANGUAGE RECIPE
    # ###############
    "${path_pkg_language_name}")
        only_with_python_default=true
        response="${package_language}"
        ;;
    # ###########
    # NAME RECIPE
    # ###########
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
    "${path_tool_name_name}")
        only_with_python_default=true
        response="$(join_deps_names "${path_tool_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_run_name_name}")
        only_with_python_default=true
        response="$(join_deps_names "${path_run_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_run_excluderoot_name_name}")
        only_with_python_default=true
        response="$(join_deps_names "${path_run_excluderoot_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_devrun_name_name}")
        only_with_python_default=true
        response="$(join_deps_names "${path_devrun_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_devrun_excluderoot_name_name}")
        only_with_python_default=true
        response="$(join_deps_names "${path_devrun_excluderoot_runtimefarm_name}")" || exit_code=1
        ;;
    # ##############
    # VERSION RECIPE
    # ##############
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
    "${path_tool_version_full_name}")
        only_with_python_default=true
        response="$(join_deps "${path_tool_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_run_version_full_name}")
        only_with_python_default=true
        response="$(join_deps "${path_run_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_run_excluderoot_version_full_name}")
        only_with_python_default=true
        response="$(join_deps "${path_run_excluderoot_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_devrun_version_full_name}")
        only_with_python_default=true
        response="$(join_deps "${path_devrun_runtimefarm_name}")" || exit_code=1
        ;;
    "${path_devrun_excluderoot_version_full_name}")
        only_with_python_default=true
        response="$(join_deps "${path_devrun_excluderoot_runtimefarm_name}")" || exit_code=1
        ;;
    # #################
    # PYTHONHOME RECIPE
    # #################
    "${path_tool_pythonhome_name}")
        response="${response:+${response}:}${path_root}/${path_tool_runtimefarm_name}/CPython/${python_full_version}"
        ;;
    "${path_pkg_pythonhome_name}")
        response="${response:+${response}:}${path_root}/${path_pkg_runtimefarm_name}/CPython/${python_full_version}"
        ;;
    "${path_run_pythonhome_name}")
        response="${response:+${response}:}${path_root}/${path_run_runtimefarm_name}/CPython/${python_full_version}"
        ;;
    "${path_run_excluderoot_pythonhome_name}")
        response="${response:+${response}:}${path_root}/${path_run_excluderoot_runtimefarm_name}/CPython/${python_full_version}"
        ;;
    "${path_devrun_pythonhome_name}")
        response="${response:+${response}:}${path_root}/${path_devrun_runtimefarm_name}/CPython/${python_full_version}"
        ;;
    "${path_devrun_excluderoot_pythonhome_name}")
        response="${response:+${response}:}${path_root}/${path_devrun_excluderoot_runtimefarm_name}/CPython/${python_full_version}"
        ;;
    # #################
    # PYTHONPATH RECIPE
    # #################
    "${path_tool_pythonpath_name}")
        response="${response:+${response}:}${path_root}/${path_tool_runtimefarm_name}/CPython/${python_full_version}/lib/python${python_version}/site-packages"
        ;;
    "${path_pkg_pythonpath_name}")
        response="${response:+${response}:}${path_root}/${path_pkg_runtimefarm_name}/CPython/${python_full_version}/lib/python${python_version}/site-packages"
        ;;
    "${path_run_pythonpath_name}")
        response="${response:+${response}:}${path_root}/${path_run_runtimefarm_name}/CPython/${python_full_version}/lib/python${python_version}/site-packages"
        ;;
    "${path_run_excluderoot_pythonpath_name}")
        response="${response:+${response}:}${path_root}/${path_run_excluderoot_runtimefarm_name}/CPython/${python_full_version}/lib/python${python_version}/site-packages"
        ;;
    "${path_devrun_pythonpath_name}")
        response="${response:+${response}:}${path_root}/${path_devrun_runtimefarm_name}/CPython/${python_full_version}/lib/python${python_version}/site-packages"
        ;;
    "${path_devrun_excluderoot_pythonpath_name}")
        response="${response:+${response}:}${path_root}/${path_devrun_excluderoot_runtimefarm_name}/CPython/${python_full_version}/lib/python${python_version}/site-packages"
        ;;
    # ##########
    # BIN RECIPE
    # ##########
    "${path_tool_bin_name}")
        response="${response:+${response}:}${path_root}/${path_tool_runtimefarm_name}/CPython/${python_full_version}/bin"
        # Only append the runtimefarm-level /bin on the first iteration.
        if [[ "${response}" != *"${path_root}/${path_tool_runtimefarm_name}/bin"* ]]; then
            response="${response}:${path_root}/${path_tool_runtimefarm_name}/bin"
        fi
        ;;
    "${path_pkg_bin_name}")
        response="${response:+${response}:}${path_root}/${path_pkg_runtimefarm_name}/CPython/${python_full_version}/bin"
        # Only append the runtimefarm-level /bin on the first iteration.
        if [[ "${response}" != *"${path_root}/${path_pkg_runtimefarm_name}/bin"* ]]; then
            response="${response}:${path_root}/${path_pkg_runtimefarm_name}/bin"
        fi
        ;;
    "${path_run_bin_name}")
        response="${response:+${response}:}${path_root}/${path_run_runtimefarm_name}/CPython/${python_full_version}/bin"
        # Only append the runtimefarm-level /bin on the first iteration.
        if [[ "${response}" != *"${path_root}/${path_run_runtimefarm_name}/bin"* ]]; then
            response="${response}:${path_root}/${path_run_runtimefarm_name}/bin"
        fi
        ;;
    "${path_run_excluderoot_bin_name}")
        response="${response:+${response}:}${path_root}/${path_run_excluderoot_runtimefarm_name}/CPython/${python_full_version}/bin"
        # Only append the runtimefarm-level /bin on the first iteration.
        if [[ "${response}" != *"${path_root}/${path_run_excluderoot_runtimefarm_name}/bin"* ]]; then
            response="${response}:${path_root}/${path_run_excluderoot_runtimefarm_name}/bin"
        fi
        ;;
    "${path_devrun_bin_name}")
        response="${response:+${response}:}${path_root}/${path_devrun_runtimefarm_name}/CPython/${python_full_version}/bin"
        # Only append the runtimefarm-level /bin on the first iteration.
        if [[ "${response}" != *"${path_root}/${path_devrun_runtimefarm_name}/bin"* ]]; then
            response="${response}:${path_root}/${path_devrun_runtimefarm_name}/bin"
        fi
        ;;
    "${path_devrun_excluderoot_bin_name}")
        response="${response:+${response}:}${path_root}/${path_devrun_excluderoot_runtimefarm_name}/CPython/${python_full_version}/bin"
        # Only append the runtimefarm-level /bin on the first iteration.
        if [[ "${response}" != *"${path_root}/${path_devrun_excluderoot_runtimefarm_name}/bin"* ]]; then
            response="${response}:${path_root}/${path_devrun_excluderoot_runtimefarm_name}/bin"
        fi
        ;;
    # ###############
    # ARTIFACT RECIPE
    # ###############
    "${path_pkg_artifact_name}")
        response="${response:+${response}:}${artifact_root}"
        ;;
    # ##################
    # RUNTIMEFARM RECIPE
    # ##################
    "${path_tool_runtimefarm_name}")
        if [[ ! -f "${path_root}/${path_tool_runtimefarm_name}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_tool_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${path_tool_runtimefarm_name}"
            install_user_space_runtime
            link_user_space_runtime_into_runtimefarm "${path_tool_runtimefarm_name}"
            install_python_runtime
            link_python_runtime_into_python_farm "${path_tool_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_tool_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${path_tool_runtimefarm_name}"
        pip_pip "${path_tool_runtimefarm_name}" "${installation_type}"
        pip_tool_dependencies "${path_tool_runtimefarm_name}" "${installation_type}"
        write_python_packages_release_info "${path_tool_runtimefarm_name}"
        fix_shebang_shim "${path_tool_runtimefarm_name}"
        mark_farm_ready_icarus_python3 "${path_tool_runtimefarm_name}" "${installation_type}"
        deactivate_farm_icarus_python3
        if [[ "${is_python_default}" == true ]]; then
            link_python_runtime_into_runtimefarm "${path_tool_runtimefarm_name}"
        fi
        validate_farm_integrity "${path_tool_runtimefarm_name}"
        response="${path_root}/${path_tool_runtimefarm_name}"
        ;;
    "${path_pkg_runtimefarm_name}")
        if [[ ! -f "${path_root}/${path_pkg_runtimefarm_name}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_pkg_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${path_pkg_runtimefarm_name}"
            install_user_space_runtime
            link_user_space_runtime_into_runtimefarm "${path_pkg_runtimefarm_name}"
            install_python_runtime
            link_python_runtime_into_python_farm "${path_pkg_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_pkg_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${path_pkg_runtimefarm_name}"
        pip_pip "${path_pkg_runtimefarm_name}" "${installation_type}"
        pip_target_package "${path_pkg_runtimefarm_name}" "build" # We never sync pkg_only
        write_python_packages_release_info "${path_pkg_runtimefarm_name}"
        fix_shebang_shim "${path_pkg_runtimefarm_name}"
        mark_farm_ready_icarus_python3 "${path_pkg_runtimefarm_name}" "${installation_type}"
        deactivate_farm_icarus_python3
        if [[ "${is_python_default}" == true ]]; then
            link_python_runtime_into_runtimefarm "${path_pkg_runtimefarm_name}"
        fi
        validate_farm_integrity "${path_pkg_runtimefarm_name}"
        response="${path_root}/${path_pkg_runtimefarm_name}"
        ;;
    "${path_run_runtimefarm_name}")
        if [[ ! -f "${path_root}/${path_run_runtimefarm_name}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_run_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${path_run_runtimefarm_name}"
            install_user_space_runtime
            link_user_space_runtime_into_runtimefarm "${path_run_runtimefarm_name}"
            install_python_runtime
            link_python_runtime_into_python_farm "${path_run_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_run_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${path_run_runtimefarm_name}"
        pip_pip "${path_run_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_run_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_run_runtimefarm_name}" "${installation_type}"
        pip_target_package "${path_run_runtimefarm_name}" "build" # This will install a fresh pkg
        write_python_packages_release_info "${path_run_runtimefarm_name}"
        fix_shebang_shim "${path_run_runtimefarm_name}"
        mark_farm_ready_icarus_python3 "${path_run_runtimefarm_name}" "${installation_type}"
        deactivate_farm_icarus_python3
        if [[ "${is_python_default}" == true ]]; then
            link_python_runtime_into_runtimefarm "${path_run_runtimefarm_name}"
        fi
        validate_farm_integrity "${path_run_runtimefarm_name}"
        response="${path_root}/${path_run_runtimefarm_name}"
        ;;
    "${path_run_excluderoot_runtimefarm_name}")
        if [[ ! -f "${path_root}/${path_run_excluderoot_runtimefarm_name}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_run_excluderoot_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${path_run_excluderoot_runtimefarm_name}"
            install_user_space_runtime
            link_user_space_runtime_into_runtimefarm "${path_run_excluderoot_runtimefarm_name}"
            install_python_runtime
            link_python_runtime_into_python_farm "${path_run_excluderoot_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_run_excluderoot_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${path_run_excluderoot_runtimefarm_name}"
        pip_pip "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        write_python_packages_release_info "${path_run_excluderoot_runtimefarm_name}"
        fix_shebang_shim "${path_run_excluderoot_runtimefarm_name}"
        mark_farm_ready_icarus_python3 "${path_run_excluderoot_runtimefarm_name}" "${installation_type}"
        deactivate_farm_icarus_python3
        if [[ "${is_python_default}" == true ]]; then
            link_python_runtime_into_runtimefarm "${path_run_excluderoot_runtimefarm_name}"
        fi
        validate_farm_integrity "${path_run_excluderoot_runtimefarm_name}"
        response="${path_root}/${path_run_excluderoot_runtimefarm_name}"
        ;;
    "${path_devrun_runtimefarm_name}")
        if [[ ! -f "${path_root}/${path_devrun_runtimefarm_name}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_devrun_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${path_devrun_runtimefarm_name}"
            install_user_space_runtime
            link_user_space_runtime_into_runtimefarm "${path_devrun_runtimefarm_name}"
            install_python_runtime
            link_python_runtime_into_python_farm "${path_devrun_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_devrun_runtimefarm_name}${end}"
            deactivate_farm_icarus_python3
        fi
        activate_farm_icarus_python3 "${path_devrun_runtimefarm_name}"
        pip_pip "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_dev_dependencies "${path_devrun_runtimefarm_name}" "${installation_type}"
        pip_target_package "${path_devrun_runtimefarm_name}" "build" # This will install a fresh pkg
        write_python_packages_release_info "${path_devrun_runtimefarm_name}"
        fix_shebang_shim "${path_devrun_runtimefarm_name}"
        mark_farm_ready_icarus_python3 "${path_devrun_runtimefarm_name}" "${installation_type}"
        deactivate_farm_icarus_python3
        if [[ "${is_python_default}" == true ]]; then
            link_python_runtime_into_runtimefarm "${path_devrun_runtimefarm_name}"
        fi
        validate_farm_integrity "${path_devrun_runtimefarm_name}"
        response="${path_root}/${path_devrun_runtimefarm_name}"
        ;;
    "${path_devrun_excluderoot_runtimefarm_name}")
        if [[ ! -f "${path_root}/${path_devrun_excluderoot_runtimefarm_name}/farm-info/ready-py${python_full_version}" ]]; then
            installation_type="build"
            echo -e "${bold_blue}${hammer_and_wrench} Building farm ${path_devrun_excluderoot_runtimefarm_name}${end}"
            build_runtimefarm_icarus_python3 "${path_devrun_excluderoot_runtimefarm_name}"
            install_user_space_runtime
            link_user_space_runtime_into_runtimefarm "${path_devrun_excluderoot_runtimefarm_name}"
            install_python_runtime
            link_python_runtime_into_python_farm "${path_devrun_excluderoot_runtimefarm_name}"
        else
            installation_type="sync"
            echo -e "${bold_blue}${hammer_and_wrench} Syncing farm ${path_devrun_excluderoot_runtimefarm_name}${end}"
        fi
        activate_farm_icarus_python3 "${path_devrun_excluderoot_runtimefarm_name}"
        pip_pip "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_run_dependencies_legacy "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        pip_dev_dependencies "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        write_python_packages_release_info "${path_devrun_excluderoot_runtimefarm_name}"
        fix_shebang_shim "${path_devrun_excluderoot_runtimefarm_name}"
        mark_farm_ready_icarus_python3 "${path_devrun_excluderoot_runtimefarm_name}" "${installation_type}"
        deactivate_farm_icarus_python3
        if [[ "${is_python_default}" == true ]]; then
            link_python_runtime_into_runtimefarm "${path_devrun_excluderoot_runtimefarm_name}"
        fi
        validate_farm_integrity "${path_devrun_excluderoot_runtimefarm_name}"
        response="${path_root}/${path_devrun_excluderoot_runtimefarm_name}"
        ;;
    *)
        echo_error "Unknown p_name: '${p_name}'"
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
