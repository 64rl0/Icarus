#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/build_runtime.sh
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

function validate_prerequisites() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo_error "This script must be run with sudo." "errexit"
    fi

    if [[ -z "${SUDO_USER}" ]]; then
        echo_error "This script must be run with sudo not as root." "errexit"
    fi
}

function set_constants() {
    platform_identifier="${1}"

    exit_code=0

    # Python version
    python_full_version=$(echo "${version_string}" | cut -d ':' -f 1)
    python_version=$(echo "${python_full_version}" | cut -d '.' -f 1,2)

    # OpenSSL version
    openssl_version=$(echo "${version_string}" | cut -d ':' -f 2)
    openssl_version_under=$(echo "${openssl_version}" | tr '.' '_')

    # Tcl & TK version
    tcltk_full_version=$(echo "${version_string}" | cut -d ':' -f 3)
    tcltk_version=$(echo "${tcltk_full_version}" | cut -d '.' -f 1,2)

    # Xz version
    xz_version=$(echo "${version_string}" | cut -d ':' -f 4)

    # Gdbm version
    gdbm_version=$(echo "${version_string}" | cut -d ':' -f 5)

    # SQLite3 version
    sqlite3_version=$(echo "${version_string}" | cut -d ':' -f 6)
    sqlite3_full_version=$(echo "${version_string}" | cut -d ':' -f 7)

    # Readline version
    readline_version=$(echo "${version_string}" | cut -d ':' -f 8)

    # Ncurses version
    ncurses_version=$(echo "${version_string}" | cut -d ':' -f 9)

    # Libffi version
    libffi_version=$(echo "${version_string}" | cut -d ':' -f 10)

    # OSSp uuid version
    ossp_uuid_version=$(echo "${version_string}" | cut -d ':' -f 11)

    # Find max available cores
    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS
        ncpu="$(sysctl -n hw.ncpu)" || ncpu=4
    else
        # Linux
        ncpu="$(grep -c ^processor /proc/cpuinfo)" || ncpu=4
    fi

    python_builds="/tmp/builds_python"

    python_build_root="${python_builds}/build-workspace"
    path_to_log_root="${python_build_root}/log"
    path_to_cache_root="${python_build_root}/cache"
    path_to_tmpwork_root="${python_build_root}/tmp/${platform_identifier}"
    path_to_runtime_root="${python_build_root}/runtime/${platform_identifier}"
    path_to_python_home="${path_to_runtime_root}/CPython/${python_full_version}"
    path_to_sysroot="${path_to_python_home}/sysroot"
    path_to_local="${path_to_python_home}/local"

    # Optimize space while cleaning the python build and remove additional dirs
    optimize_space=false

    python_pkg_name="cpython-${python_full_version}-${platform_identifier}"
    python_pkg_full_name="${python_pkg_name}.tar.gz"
}

function prepare_workspace() {
    echo_time
    echo -e "${bold_green}${sparkles} Preparing Workspace${end}"
    for dir in "${path_to_log_root}" "${path_to_cache_root}" "${path_to_tmpwork_root}" "${path_to_sysroot}" "${path_to_local}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'."
            exit_code=1
        }
    done
    echo -e "done!"
    echo
}

function prepare_local() {
    echo_time
    echo -e "${bold_green}${sparkles} Creating local tree${end}"

    local -a local_tree=("bin" "include" "lib" "share")

    for d in "${local_tree[@]}"; do
        mkdir -p "${path_to_local}/${d}" || {
            echo_error "Failed to create '${path_to_local}/${d}'."
            exit_code=1
        }
    done
    echo -e "done!"
    echo
}

function prepare_sysroot_macos() {
    rsync -aHE "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/" "${path_to_sysroot}/" || {
        echo_error "Failed to copy 'sysroot'."
        exit_code=1
    }

    export SDKROOT="${path_to_sysroot}"
}

function prepare_sysroot_linux() {
    # TODO: implement this
    echo_error "Not implemented yet!" "errexit"
}

function prepare_sysroot() {
    echo_time
    echo -e "${bold_green}${sparkles} Cleaning env for fresh build${end}"
    rm -rf "${path_to_python_home}" || {
        echo_error "Failed to remove env '${path_to_python_home}'."
        exit_code=1
    }
    echo -e "done!"
    echo

    echo_time
    echo -e "${bold_green}${sparkles} Creating sysroot tree${end}"
    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS
        prepare_sysroot_macos
    else
        # Linux
        prepare_sysroot_linux
    fi
    echo -e "done!"
    echo
}

function build_generic() {
    local display_name="${1}"                                                               # PostgreSQL${postgres_version}
    local package_dir_name="${2}"                                                           # PostgreSQL
    local package_download_filename="${3}"                                                  # postgresql-${postgres_version}.tar.gz
    local unpacked_dir_name="${4}"                                                          # postgresql-${postgres_version}
    local package_make_path="${5}"                                                          # postgresql-${postgres_version}/unix
    local package_url="${6}"                                                                # XXX${postgres_version}/postgresql-${postgres_version}.tar.gz
    IFS=':' read -r -a configure_options <<<"$(echo "${7}" | sed -e 's/[[:space:]]*:/:/g')" # separate them by :

    # Create log directory
    mkdir -p "${path_to_log_root}" || {
        echo_error "Failed to create '${path_to_log_root}'."
        exit_code=1
    }

    # Create fresh Local env space
    echo_time
    echo -e "${bold_green}${sparkles} Preparing '${display_name}'${end}"
    rm -rf "${path_to_tmpwork_root:?}/${package_dir_name:?}" || {
        echo_error "Failed to remove '${path_to_tmpwork_root}/${package_dir_name}'."
        exit_code=1
    }

    mkdir -p "${path_to_cache_root}/${package_dir_name}" || {
        echo_error "Failed to create '${path_to_cache_root}/${package_dir_name}'."
        exit_code=1
    }
    mkdir -p "${path_to_tmpwork_root}/${package_dir_name}" || {
        echo_error "Failed to create '${path_to_tmpwork_root}/${package_dir_name}'."
        exit_code=1
    }
    echo -e "done!"

    # Downloading Generic into cache space if not there already
    if [[ ! -e "${path_to_cache_root}/${package_dir_name}/${package_download_filename}" ]]; then
        echo
        echo_time
        echo -e "${bold_green}${sparkles} Downloading '${display_name}'${end}"
        curl -L "${package_url}" -o "${path_to_cache_root}/${package_dir_name}/${package_download_filename}" || {
            echo_error "Failed to download '${display_name}'."
            exit_code=1
        }
    else
        echo
        echo_time
        echo -e "${bold_green}${sparkles} Using cached '${display_name}'${end}"
        echo -e "done!"
    fi

    # Unpack Generic and move to work dir
    cd "${path_to_cache_root}/${package_dir_name}" || {
        echo_error "Failed to change directory to '${path_to_cache_root}/${package_dir_name}'."
        exit_code=1
    }
    tar -xzf "${path_to_cache_root}/${package_dir_name}/${package_download_filename}" || {
        echo_error "Failed to unpack '${package_download_filename}'."
        exit_code=1
    }
    mv "${unpacked_dir_name}" "${path_to_tmpwork_root}/${package_dir_name}" || {
        echo_error "Failed to move '${display_name}' to work space."
        exit_code=1
    }

    # Configure Generic
    echo
    echo_time
    echo -e "${bold_green}${sparkles} Configuring '${display_name}'${end}"
    cd "${path_to_tmpwork_root}/${package_dir_name}/${package_make_path}" || {
        echo_error "Failed to change directory to '${path_to_tmpwork_root}/${package_dir_name}/${package_make_path}'."
        exit_code=1
    }
    echo Received configure params:
    for conf in "${configure_options[@]}"; do
        echo -e "--| ${conf}"
    done
    echo -e "Redirecting output to '${path_to_log_root}/${unpacked_dir_name}.configure.log'"
    # Only for OpenSSl
    if [[ "${package_download_filename}" =~ [oO]pen[sS][sS][lL] ]]; then
        ./config "${configure_options[@]}" >"${path_to_log_root}/${unpacked_dir_name}.configure.log" 2>&1 || {
            echo_error "Failed to configure '${display_name}'."
            exit_code=1
        }
    else
        ./configure "${configure_options[@]}" >"${path_to_log_root}/${unpacked_dir_name}.configure.log" 2>&1 || {
            echo_error "Failed to configure '${display_name}'."
            exit_code=1
        }
    fi
    echo -e "done!"

    # Install Generic
    echo
    echo_time
    echo -e "${bold_green}${sparkles} Installing '${display_name}'${end}"
    echo -e "Installing using ${ncpu} cores"
    echo -e "This can take a while"
    echo -e "Redirecting output to '${path_to_log_root}/${unpacked_dir_name}.make.log'"
    make -j "${ncpu:?}" >"${path_to_log_root}/${unpacked_dir_name}.make.log" 2>&1 || {
        echo_error "Failed to make '${display_name}'."
        exit_code=1
    }
    echo -e "Redirecting output to '${path_to_log_root}/${unpacked_dir_name}.install.log'"
    sudo -E make -j "${ncpu:?}" install >"${path_to_log_root}/${unpacked_dir_name}.install.log" 2>&1 || {
        echo_error "Failed to install '${display_name}'."
        exit_code=1
    }
    echo -e "done!"
    echo
}

function build_tcltk() {
    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS
        declare -g tcltk_libs_flags="-framework Tcl -framework Tk"
        local os="macosx"
    else
        # Linux
        local os="unix"
        declare -g tcltk_libs_flags=""
    fi

    build_generic \
        "Tcl${tcltk_full_version}" \
        "Tcl" \
        "tcl${tcltk_full_version}-src.tar.gz" \
        "tcl${tcltk_full_version}" \
        "tcl${tcltk_full_version}/${os}" \
        "http://prdownloads.sourceforge.net/tcl/tcl${tcltk_full_version}-src.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"

    if [[ $(uname -s) == "Darwin" ]]; then
        mkdir -p "${path_to_local}/Frameworks" || {
            echo_error "Failed to create 'Frameworks'."
            exit_code=1
        }
        mv "${path_to_tmpwork_root}/Tcl/build/tcl" "${path_to_local}/Frameworks/Tcl" || {
            echo_error "Failed to move 'Tcl'."
            exit_code=1
        }

        echo_time
        echo -e "${bold_green}${sparkles} Creating symlink for 'Tcl'${end}"
        rm -rf "${path_to_local}/Frameworks/Tcl/Development/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "../../../Tcl" "${path_to_local}/Frameworks/Tcl/Development/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        rm -rf "${path_to_local}/Frameworks/Tcl/Development/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "../../../../Tcl" "${path_to_local}/Frameworks/Tcl/Development/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }

        rm -rf "${path_to_local}/Frameworks/Tcl/Deployment/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "../../../Tcl" "${path_to_local}/Frameworks/Tcl/Deployment/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        rm -rf "${path_to_local}/Frameworks/Tcl/Deployment/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "../../../../Tcl" "${path_to_local}/Frameworks/Tcl/Deployment/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }

        ln -s -f "./Deployment/tcltest" "${path_to_local}/Frameworks/Tcl" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "./Tcl/Tcl.framework" "${path_to_local}/Frameworks/Tcl.framework" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }

        ln -s -f "../Frameworks/Tcl/Tcl.framework/Versions/${tcltk_version}/Tcl" "${path_to_local}/lib" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "../Frameworks/Tcl/Tcl.framework/Versions/${tcltk_version}/Tcl_debug" "${path_to_local}/lib" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        ln -s -f "../Frameworks/Tcl/Tcl.framework/Versions/${tcltk_version}/libtclstub${tcltk_version}.a" "${path_to_local}/lib" || {
            echo_error "Failed to create symlink for 'Tcl'."
            exit_code=1
        }
        find "${path_to_local}/Frameworks/Tcl/Tcl.framework/Versions/${tcltk_version}/Headers" -mindepth 1 -maxdepth 1 -print0 \
            | while IFS= read -r -d '' file; do
                ln -s -f "../Frameworks/Tcl/Tcl.framework/Versions/${tcltk_version}/Headers/$(basename "${file}")" "${path_to_local}/include" || {
                    echo_error "Failed to create symlink for 'Tcl'."
                    exit_code=1
                }
            done

        echo -e "done!"
        echo
    fi

    build_generic \
        "Tk${tcltk_full_version}" \
        "Tk" \
        "tk${tcltk_full_version}-src.tar.gz" \
        "tk${tcltk_full_version}" \
        "tk${tcltk_full_version}/${os}" \
        "http://prdownloads.sourceforge.net/tcl/tk${tcltk_full_version}-src.tar.gz" \
        "--prefix=${path_to_local} \
        :--with-tcl=${path_to_tmpwork_root}/Tcl/tcl${tcltk_full_version}/${os} \
        :--enable-shared"

    if [[ $(uname -s) == "Darwin" ]]; then
        mkdir -p "${path_to_local}/Frameworks" || {
            echo_error "Failed to create 'Frameworks'."
            exit_code=1
        }
        mv "${path_to_tmpwork_root}/Tk/build/tk" "${path_to_local}/Frameworks/Tk" || {
            echo_error "Failed to move 'Tk'."
            exit_code=1
        }

        echo_time
        echo -e "${bold_green}${sparkles} Creating symlink for 'Tk'${end}"
        rm -rf "${path_to_local}/Frameworks/Tk/Development/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "../../../Tk" "${path_to_local}/Frameworks/Tk/Development/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        rm -rf "${path_to_local}/Frameworks/Tk/Development/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "../../../../Tk" "${path_to_local}/Frameworks/Tk/Development/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        rm -rf "${path_to_local}/Frameworks/Tk/Development/Tk.framework/Versions/8.6/Resources/Tk.rsrc" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }

        rm -rf "${path_to_local}/Frameworks/Tk/Deployment/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "../../../Tk" "${path_to_local}/Frameworks/Tk/Deployment/Library/Frameworks" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        rm -rf "${path_to_local}/Frameworks/Tk/Deployment/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "../../../../Tk" "${path_to_local}/Frameworks/Tk/Deployment/usr/local/bin" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        rm -rf "${path_to_local}/Frameworks/Tk/Deployment/Tk.framework/Versions/8.6/Resources/Tk.rsrc" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }

        ln -s -f "./Deployment/tktest" "${path_to_local}/Frameworks/Tk" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "./Tk/Tk.framework" "${path_to_local}/Frameworks/Tk.framework" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }

        ln -s -f "../Frameworks/Tk/Tk.framework/Versions/${tcltk_version}/Tk" "${path_to_local}/lib" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "../Frameworks/Tk/Tk.framework/Versions/${tcltk_version}/Tk_debug" "${path_to_local}/lib" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        ln -s -f "../Frameworks/Tk/Tk.framework/Versions/${tcltk_version}/libtkstub${tcltk_version}.a" "${path_to_local}/lib" || {
            echo_error "Failed to create symlink for 'Tk'."
            exit_code=1
        }
        find "${path_to_local}/Frameworks/Tk/Tk.framework/Versions/${tcltk_version}/Headers" -mindepth 1 -maxdepth 1 -print0 \
            | while IFS= read -r -d '' file; do
                ln -s -f "../Frameworks/Tk/Tk.framework/Versions/${tcltk_version}/Headers/$(basename "${file}")" "${path_to_local}/include" || {
                    echo_error "Failed to create symlink for 'Tk'."
                    exit_code=1
                }
            done

        echo -e "done!"
        echo
    fi
}

function build_openssl() {
    if [[ "${openssl_version}" == "1."* ]]; then
        build_generic \
            "OpenSSL${openssl_version}" \
            "OpenSSL" \
            "openssl-${openssl_version}.tar.gz" \
            "openssl-${openssl_version}" \
            "openssl-${openssl_version}" \
            "https://github.com/openssl/openssl/releases/download/OpenSSL_${openssl_version_under}/openssl-${openssl_version}.tar.gz" \
            "shared \
            :--prefix=${path_to_local}"

    elif [[ "${openssl_version}" == "3."* ]]; then
        build_generic \
            "OpenSSL${openssl_version}" \
            "OpenSSL" \
            "openssl-${openssl_version}.tar.gz" \
            "openssl-${openssl_version}" \
            "openssl-${openssl_version}" \
            "https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz" \
            "shared \
            :--prefix=${path_to_local}"

    else
        echo_error "Unsupported OpenSSL version: ${openssl_version}"
    fi
}

function build_libffi() {
    build_generic \
        "Libffi${libffi_version}" \
        "Libffi" \
        "libffi-${libffi_version}.tar.gz" \
        "libffi-${libffi_version}" \
        "libffi-${libffi_version}" \
        "https://github.com/libffi/libffi/releases/download/v${libffi_version}/libffi-${libffi_version}.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"
}

function build_ncurses() {
    build_generic \
        "Ncurses${ncurses_version}" \
        "Ncurses" \
        "ncurses-${ncurses_version}.tar.gz" \
        "ncurses-${ncurses_version}" \
        "ncurses-${ncurses_version}" \
        "https://ftp.gnu.org/gnu/ncurses/ncurses-${ncurses_version}.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"
}

function build_readline() {
    build_generic \
        "Readline${readline_version}" \
        "Readline" \
        "readline-${readline_version}.tar.gz" \
        "readline-${readline_version}" \
        "readline-${readline_version}" \
        "https://ftp.gnu.org/gnu/readline/readline-${readline_version}.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"
}

function build_xz() {
    build_generic \
        "Xz${xz_version}" \
        "Xz" \
        "xz-${xz_version}.tar.gz" \
        "xz-${xz_version}" \
        "xz-${xz_version}" \
        "https://github.com/tukaani-project/xz/releases/download/v${xz_version}/xz-${xz_version}.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"
}

function build_gdbm() {
    build_generic \
        "Gdbm${gdbm_version}" \
        "Gdbm" \
        "gdbm-${gdbm_version}.tar.gz" \
        "gdbm-${gdbm_version}" \
        "gdbm-${gdbm_version}" \
        "https://ftp.gnu.org/gnu/gdbm/gdbm-${gdbm_version}.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"
}

function build_sqlite3() {
    build_generic \
        "SQLite${sqlite3_version}" \
        "SQLite" \
        "sqlite-autoconf-${sqlite3_full_version}.tar.gz" \
        "sqlite-autoconf-${sqlite3_full_version}" \
        "sqlite-autoconf-${sqlite3_full_version}" \
        "https://www.sqlite.org/2025/sqlite-autoconf-${sqlite3_full_version}.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-all \
        :--enable-shared"
}

function build_ossp_uuid() {
    build_generic \
        "Ossp_uuid${ossp_uuid_version}" \
        "Ossp_uuid" \
        "ossp-uuid_${ossp_uuid_version}.orig.tar.gz" \
        "uuid-${ossp_uuid_version}" \
        "uuid-${ossp_uuid_version}" \
        "https://ftp.debian.org/debian/pool/main/o/ossp-uuid/ossp-uuid_${ossp_uuid_version}.orig.tar.gz" \
        "--prefix=${path_to_local} \
        :--enable-shared"
}

function build_python_runtime() {
    local prefix ldflags_rpath

    # C compiler and Linker options for python dependencies
    export CPPFLAGS="--sysroot=${path_to_sysroot} -I${path_to_local}/include"
    export LDFLAGS="-L${path_to_local}/lib"

    # C compiler and Linker rpath option for Python
    if [[ $(uname) == "Darwin" ]]; then
        # macOS
        ldflags_rpath="-Wl,-rpath,@loader_path/../"
    else
        # Linux
        ldflags_rpath="-Wl,-rpath,\$ORIGIN/../local/lib"
    fi

    if [[ "${python_full_version}" == "3.13."* ]]; then
        # Install Python Dependencies
        if [[ $(uname) == "Darwin" ]]; then
            # macOS
            build_tcltk
            build_openssl
            build_readline
            build_gdbm
            build_xz
            build_sqlite3
        else
            # Linux
            build_sqlite3
        fi

        prefix="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

        # C compiler and Linker options for Python
        export CPPFLAGS="--sysroot=${path_to_sysroot} -I${path_to_local}/include"
        export LDFLAGS="-L${path_to_local}/lib ${ldflags_rpath}"

    elif [[ "${python_full_version}" == "3.12."* ]]; then
        # Install Python Dependencies
        if [[ $(uname) == "Darwin" ]]; then
            # macOS
            build_tcltk
            build_openssl
            build_readline
            build_gdbm
            build_xz
            build_sqlite3
        else
            # Linux
            build_sqlite3
        fi

        prefix="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

        # C compiler and Linker options for Python
        export CPPFLAGS="--sysroot=${path_to_sysroot} -I${path_to_local}/include"
        export LDFLAGS="-L${path_to_local}/lib ${ldflags_rpath}"

    elif [[ "${python_full_version}" == "3.11."* ]]; then
        # Install Python Dependencies
        if [[ $(uname) == "Darwin" ]]; then
            # macOS
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_sqlite3
        else
            # Linux
            build_sqlite3
        fi

        prefix="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

        # C compiler and Linker options for Python
        export CPPFLAGS="--sysroot=${path_to_sysroot} -I${path_to_local}/include"
        export LDFLAGS="-L${path_to_local}/lib ${ldflags_rpath}"

    elif [[ "${python_full_version}" == "3.10."* ]]; then
        # Install Python Dependencies
        if [[ $(uname) == "Darwin" ]]; then
            # macOS
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_sqlite3
            build_ossp_uuid
        else
            # Linux
            build_sqlite3
        fi

        prefix="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

        # C compiler and Linker options for Python
        export CPPFLAGS="--sysroot=${path_to_sysroot} -I${path_to_local}/include -I${path_to_sysroot}/usr/include"
        export LDFLAGS="-L${path_to_local}/lib -L${path_to_sysroot}/usr/lib ${ldflags_rpath}"

    elif [[ "${python_full_version}" == "3.9."* ]]; then
        # Install Python Dependencies
        if [[ $(uname) == "Darwin" ]]; then
            # macOS
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_sqlite3
            build_ossp_uuid
        else
            # Linux
            build_sqlite3
        fi

        prefix="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

        # C compiler and Linker options for Python
        export CPPFLAGS="--sysroot=${path_to_sysroot} -I${path_to_local}/include -I${path_to_sysroot}/usr/include"
        export LDFLAGS="-L${path_to_local}/lib -L${path_to_sysroot}/usr/lib ${ldflags_rpath}"

    else
        echo_error "Unsupported Python version: ${python_full_version}"
    fi

    # Options for third-party dependencies
    export TCLTK_CFLAGS="-I${path_to_local}/include"
    export TCLTK_LIBS="-L${path_to_local}/lib -ltclstub${tcltk_version} -ltkstub${tcltk_version} ${tcltk_libs_flags}"

    build_generic \
        "CPython${python_full_version}" \
        "CPython/${python_full_version}" \
        "Python-${python_full_version}.tgz" \
        "Python-${python_full_version}" \
        "Python-${python_full_version}" \
        "https://www.python.org/ftp/python/${python_full_version}/Python-${python_full_version}.tgz" \
        "${prefix}"
}

function check_python_build_logs() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking logs after build${end}"

    grep -E -n \
        -e '[fF]ollowing modules built successfully but were removed because they could not be imported' \
        -e '[fF]ailed to build' \
        -e 'to build these optional modules were not found' \
        -e '[tT]o find the necessary bits, look in configure' \
        -e '[cC]ould not build the' \
        -e '[pP]ython requires' \
        -e '[cC]ould not build the' \
        -e 'since importing it failed' \
        -e '[tT]raceback ' \
        -e '[eE]rror 1$' \
        "${path_to_log_root}/Python-${python_full_version}.configure.log" \
        "${path_to_log_root}/Python-${python_full_version}.make.log" \
        "${path_to_log_root}/Python-${python_full_version}.install.log" && {
        echo_error "Found errors in build logs."
        exit_code=1
    }

    echo -e "done!"
    echo
}

function clean_build() {
    echo_time
    echo -e "${bold_green}${sparkles} Cleaning env after build${end}"

    rm -rf "${path_to_sysroot:?}" || {
        echo_error "Failed to remove '${path_to_sysroot}'."
        exit_code=1
    }

    local dirs_to_clean=(
        ".mypy_cache"
        ".pytest_cache"
        "__pycache__"
    )
    for dir in "${dirs_to_clean[@]}"; do
        find "${path_to_python_home}" -type d -name "${dir}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${dir}'."
            exit_code=1
        }
    done

    local files_to_clean=(
        ".DS_Store"
        "Thumbs.db"
        "*.pyc"
    )
    for file in "${files_to_clean[@]}"; do
        find "${path_to_python_home}" -type f -name "${file}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${file}'."
            exit_code=1
        }
    done

    if [[ "${optimize_space}" == true ]]; then
        rm -rf "${path_to_local:?}/share" || {
            echo_error "Failed to remove '${path_to_local}/share'."
            exit_code=1
        }
    fi

    echo -e "done!"
    echo
}

function make_tar() {
    echo_time
    echo -e "${bold_green}${sparkles} Packing up '${python_pkg_name}'${end}"
    tar -czf "${path_to_runtime_root}/${python_pkg_full_name}" -C "${path_to_runtime_root}/CPython" "${python_full_version}" || {
        echo_error "Failed to pack up '${python_pkg_name}'."
        exit_code=1
    }
    rm -rf "${python_builds:?}/${python_pkg_full_name:?}" || {
        echo_error "Failed to remove '${python_builds}/${python_pkg_full_name}'."
        exit_code=1
    }
    mv "${path_to_runtime_root}/${python_pkg_full_name}" "${python_builds}/" || {
        echo_error "Failed to move '${python_pkg_full_name}'."
        exit_code=1
    }
    echo -e "done!"
    echo
}

function fix_runtime_paths_macos() {
    # Make every dylib install-name relative @rpath
    find "${path_to_python_home}" \
        \( -path "${path_to_python_home}/sysroot" -prune \) -o \
        \( \( -type f -o -type l \) \
        \( -perm -111 \
        -o -name '*.so*' \
        -o -name '*.dylib' \
        -o -name '*.bundle' \
        -o -name '*.sl' \) \
        -print0 \
        \) \
        | while IFS= read -r -d '' bin; do
            if file "${bin}" | grep -q 'Mach-O'; then
                extension=$(echo "${bin}" | sed "s|${path_to_python_home}/||g")
                install_name_tool -id "@rpath/${extension}" "${bin}"

                if otool -L "${bin}" | tail -n +2 | grep -q "${path_to_local}/lib/"; then
                    otool -L "${bin}" | tail -n +2 | grep "${path_to_local}/lib/" | awk '{print $1}' \
                        | while read -r lib; do
                            extension=$(echo "${lib}" | sed "s|${path_to_local}/lib/||g")
                            install_name_tool -change "${lib}" "@rpath/local/lib/${extension}" "${bin}"
                        done
                fi

                if otool -L "${bin}" | tail -n +2 | grep -q '^[[:space:]]*/Library/Frameworks/'; then
                    otool -L "${bin}" | tail -n +2 | grep '^[[:space:]]*/Library/Frameworks/' | awk '{print $1}' \
                        | while read -r fw; do
                            extension=$(echo "${fw}" | sed "s|/Library/Frameworks/||g")
                            install_name_tool -change "${fw}" "@rpath/local/Frameworks/${extension}" "${bin}"
                        done
                fi
            fi
        done

    # Add rpath to the python launcher if it is missing
    for exe in "${path_to_python_home}/bin/"*; do
        # only operate on Mach-O executables, not text scripts
        if file "${exe}" | grep -q 'Mach-O'; then
            # check if @loader_path/../ is already in its RPATH
            if ! otool -l "${exe}" | grep -q '@loader_path/../'; then
                install_name_tool -add_rpath "@loader_path/../" "${exe}"
            fi
        fi
    done
}

function fix_runtime_paths_linux() {
    if [[ -z "$(command -v patchelf 2>/dev/null)" ]]; then
        echo_error "[NOT FOUND] \`patchelf\` not found in PATH" "errexit"
        exit_code=1
    fi

    local new_path='$ORIGIN/../local/lib'

    # Make all .so files look for libraries in $ORIGIN/../local/lib
    find "${path_to_python_home}" \
        \( -path "${path_to_python_home}/sysroot" -prune \) -o \
        \( \( -type f -o -type l \) \
        \( -perm -111 -o -name '*.so' \) \
        -print0 \
        \) \
        | while IFS= read -r -d '' so; do
            if file "${so}" | grep -q 'ELF'; then
                patchelf --set-rpath "${new_path}" "${so}"
            fi
        done

    # Add RPATH to all ELF executables in bin/ if missing
    for exe in "${path_to_python_home}/bin/"*; do
        # only operate on ELF executables, not scripts
        if file "${exe}" | grep -q 'ELF'; then
            # check if ${new_path} is already in its RPATH
            if ! patchelf --print-rpath "${exe}" | grep -qF "${new_path}"; then
                local current
                current=$(patchelf --print-rpath "${exe}")
                patchelf --set-rpath "${current:+${current}:}${new_path}" "${exe}"
            fi
        fi
    done
}

function fix_runtime_paths() {
    echo_time
    echo -e "${bold_green}${sparkles} Fixing id’s and rpaths${end}"
    local extension lib fw

    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS
        fix_runtime_paths_macos

    elif [[ $(uname -s) == "Linux" ]]; then
        # Linux
        fix_runtime_paths_linux

    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    echo -e "done!"
    echo
}

function check_loadable_refs() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking loadable Mach-O / ELF object${end}"

    local file lib
    local forbidden_paths=("/Library/Developer/CommandLineTools")

    find "${path_to_python_home}" -type f \
        \( -perm -111 \
        -o -name '*.so*' \
        -o -name '*.dylib' \
        -o -name '*.bundle' \
        -o -name '*.sl' \) \
        -print0 \
        | while IFS= read -r -d '' file; do
            # Skip the header line from otool -L, grab only the referenced install names
            if [[ $(uname -s) == "Darwin" ]]; then
                # macOS
                otool -L "${file}" | tail -n +2 | awk '{print $1}'
            else
                # Linux
                ldd -v "${file}" | awk '/=>/ {print $3}'
            fi \
                | while read -r lib; do
                    case "${lib}" in
                    @*)
                        echo -e "${lib}"
                        # relative reference – OK
                        ;;
                    /System/* | /usr/lib/*)
                        # system lib – OK
                        ;;
                    "${path_to_sysroot}"/*)
                        echo -e "'${file}' links to '${lib}'"
                        exit_code=1
                        ;;
                    *)
                        # any extra “forbidden” prefixes passed on the command line
                        for p in "${forbidden_paths[@]}"; do
                            if [[ "${lib}" == "${p}"* ]]; then
                                echo -e "'${file}' links to '${lib}'"
                                exit_code=1
                            fi
                        done
                        if [[ "${file}" == *".a" ]]; then
                            # static library – OK
                            continue
                        fi
                        # Not sure what this is so let's log it
                        echo -e "'${file}' links to '${lib}'"
                        exit_code=1
                        ;;
                    esac
                done
        done

    echo -e "done!"
    echo
}

function check_broken_links() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking for broken links${end}"

    local file broken_links

    find "${path_to_python_home}" -type l -print0 \
        | while IFS= read -r -d '' file; do
            if [[ ! -e "${file}" ]]; then
                echo -e "'${file}' is broken"
                exit_code=1
                broken_links=1
            fi
        done

    if [[ "${broken_links}" -eq 1 ]]; then
        echo_error "Broken links found."
    fi

    echo -e "done!"
    echo
}

function fix_python_runtime_bin_dir() {
    echo_time
    echo -e "${bold_green}${sparkles} Fixing Python runtime bin dir${end}"

    local pybin_dir="${path_to_python_home}/bin"

    rm -rf "${pybin_dir:?}/idle"* || {
        echo_error "Failed to remove 'idle*'."
        exit_code=1
    }
    rm -rf "${pybin_dir:?}/2to3"* || {
        echo_error "Failed to remove '2to3*'."
        exit_code=1
    }
    rm -rf "${pybin_dir:?}/pydoc"* || {
        echo_error "Failed to remove 'pydoc*'."
        exit_code=1
    }
    rm -rf "${pybin_dir:?}/python"*"-config" || {
        echo_error "Failed to remove 'python*-config'."
        exit_code=1
    }
    cp "${pybin_dir}/pip3" "${pybin_dir}/pip" || {
        echo_error "Failed to copy 'pip3'."
        exit_code=1
    }

    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS
        sed -i '' "1s|.*|#!/usr/bin/env python${python_version}|" \
            "${pybin_dir}/pip" \
            "${pybin_dir}/pip3" \
            "${pybin_dir}/pip${python_version}" || {
            echo_error "Failed to update shebang line."
            exit_code=1
        }
    else
        # Linux
        sed -i "1s|.*|#!/usr/bin/env python${python_version}|" \
            "${pybin_dir}/pip" \
            "${pybin_dir}/pip3" \
            "${pybin_dir}/pip${python_version}" || {
            echo_error "Failed to update shebang line."
            exit_code=1
        }
    fi

    echo -e "done!"
    echo
}

function check_python_runtime() {
    local pybin="${path_to_python_home}/bin/python3"

    echo_time
    echo -e "${bold_green}${sparkles} Checking Python runtime${end}"

    "$pybin" - <<'PYTEST' || py_test_failed=1
import importlib, sys

tests = {
    "ssl":      lambda m: m.OPENSSL_VERSION,
    "hashlib":  lambda m: "sha256 OK" if "sha256" in m.algorithms_available else "MISSING sha256",
    "sqlite3":  lambda m: m.sqlite_version,
    "tkinter":  lambda m: m.TkVersion,
    "dbm.gnu":  lambda m: getattr(m, "__doc__", "").splitlines()[0] or "OK",
    "lzma":     lambda m: getattr(m, "__doc__", "").splitlines()[0] or "OK",
    "readline": lambda m: getattr(m, "__doc__", "").splitlines()[0] or "OK",
    "zlib":     lambda m: getattr(m, "__doc__", "").splitlines()[0] or "OK",
    "bz2":      lambda m: getattr(m, "__doc__", "").splitlines()[0] or "OK",
}

print('CPython  :', sys.version)

failed = False
for name, getver in tests.items():
    try:
        mod = importlib.import_module(name)
        ver = getver(mod) or "Imported OK"
        print(f"{name:<9}: {ver}")
    except Exception as exc:
        print(f"{name:<9}: **FAILED** – {exc}", file=sys.stderr)
        failed = True

if failed:
    sys.exit(1)
PYTEST

    if [[ "${py_test_failed}" -eq 1 ]]; then
        echo_error "Python test failed."
        exit_code=1
    fi

    echo -e "done!"
    echo
}

function set_ownership() {
    echo_time
    echo -e "${bold_green}${sparkles} Setting ownership for '${python_builds}'${end}"
    sudo chown -R "${SUDO_USER}":"staff" "${python_builds}" || {
        echo_error "Failed to set ownership for '${python_builds}'."
        exit_code=1
    }
    echo -e "done!"
    echo
}

function push_gh_release() {
    echo_time
    echo -e "${bold_green}${sparkles} Pushing GitHub Release for '${python_pkg_name}'${end}"
    echo -e "Cleaning up previous release…"
    gh release delete \
        "${python_pkg_name}" \
        --cleanup-tag \
        --repo "64rl0/PythonRuntime" \
        --yes || :

    echo
    echo -e "Pushing release…"
    gh release create \
        "${python_pkg_name}" \
        --latest=false \
        --repo "64rl0/PythonRuntime" \
        --title "" \
        --notes "" \
        "${python_builds}/${python_pkg_full_name}" || {
        echo_error "Failed to push GitHub Release for '${python_pkg_name}'."
        exit_code=1
    }
    echo -e "done!"
    echo
}

function update_final_response() {
    local ex_co_colored

    if [[ "${exit_code}" -eq 0 ]]; then
        col="${bold_green}"
    else
        col="${bold_red}"
    fi

    final_response+="${python_pkg_name} -> ${col}Completed with exit code: ${exit_code}${end}\n"
}

function echo_final_response() {
    echo_time
    echo -e "${bold_green}${sparkles} Final response${end}"
    echo -e "${final_response}"
    echo
}

function read_build_versions() {
    declare -g -r verv=(
        # PYTHON 3.13
        #        "3.13.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #        "3.13.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #        "3.13.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #        "3.13.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #        "3.13.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # PYTHON 3.12
        "3.12.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.12.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # PYTHON 3.11
        "3.11.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.11.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # PYTHON 3.10
        "3.10.18:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.17:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.16:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        "3.10.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # PYTHON 3.9
        #"3.9.23:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.22:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.21:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.20:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.19:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.18:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.17:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.16:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        #"3.9.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
        # "3.9.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:1.6.2"
    )
}

function main() {
    validate_prerequisites

    read_build_versions
    local final_response=""

    for version_string in "${verv[@]}"; do
        set_constants "${@}"

        local title="Building Python ${python_full_version} runtime"
        echo -e "\n${bold_black}${bg_white}${left_pad} ${title} ${right_pad}${end}\n"

        prepare_workspace
        prepare_sysroot
        prepare_local

        build_python_runtime
        if [[ ! "${python_full_version}" == "3.10."* && ! "${python_full_version}" == "3.9."* ]]; then
            check_python_build_logs
        fi

        set_ownership
        fix_runtime_paths
        check_loadable_refs
        check_broken_links
        clean_build

        fix_python_runtime_bin_dir
        check_python_runtime
        make_tar

        if [[ "${exit_code}" -eq 0 ]]; then
            push_gh_release
        fi

        update_final_response
    done

    echo_final_response

    return "${exit_code}"
}

main "${@}"
