#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/build_runtime.sh
# Created 5/15/25 - 11:55 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs

# Sourcing base file
. "${cli_scripts_dir_abs}/base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

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

    if [[ -z "${GH_TOKEN}" ]]; then
        echo_error "GH_TOKEN environment variable is not set." "errexit"
    fi

    if [[ -z "${verv}" ]]; then
        echo_error "There isn't any selected version of Python to build!" "errexit"
    fi

    if ! command -v gh >/dev/null 2>&1; then
        echo_error "GitHub CLI (gh) is not installed or not in PATH." "errexit"
    fi

    if [[ $(uname -s) == "Darwin" ]]; then
        if ! command -v xcrun >/dev/null 2>&1; then
            echo_error "xcrun is not installed or not in PATH." "errexit"
        fi
    fi
}

function set_constants() {
    platform_identifier="${1}"

    exit_code=0

    # Python version
    python_full_version=$(echo "${version_string}" | cut -d ':' -f 1)
    declare -g python_full_version
    python_version=$(echo "${python_full_version}" | cut -d '.' -f 1,2)
    declare -g python_version

    # OpenSSL version
    openssl_version=$(echo "${version_string}" | cut -d ':' -f 2)
    declare -g openssl_version
    openssl_version_under=$(echo "${openssl_version}" | tr '.' '_')
    declare -g openssl_version_under

    # Tcl & TK version
    tcltk_full_version=$(echo "${version_string}" | cut -d ':' -f 3)
    declare -g tcltk_full_version
    tcltk_version=$(echo "${tcltk_full_version}" | cut -d '.' -f 1,2)
    declare -g tcltk_version

    # Xz version
    xz_version=$(echo "${version_string}" | cut -d ':' -f 4)
    declare -g xz_version

    # Gdbm version
    gdbm_version=$(echo "${version_string}" | cut -d ':' -f 5)
    declare -g gdbm_version

    # SQLite3 version
    sqlite3_version=$(echo "${version_string}" | cut -d ':' -f 6)
    declare -g sqlite3_version
    sqlite3_full_version=$(echo "${version_string}" | cut -d ':' -f 7)
    declare -g sqlite3_full_version

    # Readline version
    readline_version=$(echo "${version_string}" | cut -d ':' -f 8)
    declare -g readline_version

    # Ncurses version
    ncurses_version=$(echo "${version_string}" | cut -d ':' -f 9)
    declare -g ncurses_version

    # Libffi version
    libffi_version=$(echo "${version_string}" | cut -d ':' -f 10)
    declare -g libffi_version

    # Libnsl version
    libnsl_version=$(echo "${version_string}" | cut -d ':' -f 11)
    declare -g libnsl_version

    # zstd / Zstandard version
    zstd_version=$(echo "${version_string}" | cut -d ':' -f 12)
    declare -g zstd_version

    # Find max available cores
    if [[ $(uname -s) == "Darwin" ]]; then
        ncpu="$(sysctl -n hw.ncpu)" || ncpu=4
    elif [[ $(uname -s) == "Linux" ]]; then
        ncpu="$(grep -c ^processor /proc/cpuinfo)" || ncpu=4
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    python_builds="${tmp_root_sudo}/build-runtime"

    python_build_root="${python_builds}/workspace"
    python_version_build_root="${python_build_root}/${python_full_version}"
    path_to_cache_root="${python_build_root}/cache"
    path_to_log_root="${python_version_build_root}/log"
    path_to_log_build_master_file="${python_version_build_root}/build_${python_full_version}.log"
    path_to_tmpwork_root="${python_version_build_root}/tmp/${platform_identifier}"
    path_to_runtime_root="${python_version_build_root}/runtime/${platform_identifier}"
    path_to_python_home="${path_to_runtime_root}/CPython/${python_full_version}"
    path_to_sysroot="${path_to_python_home}/sysroot"
    path_to_linux_dependencies_root="${path_to_python_home}/linux-tmp-dependencies"
    path_to_local="${path_to_python_home}/local"

    python_pkg_name="cpython-${python_full_version}-${platform_identifier}"
    python_pkg_full_name="${python_pkg_name}.tar.gz"
}

function clean_workspace_shallow() {
    echo_time
    echo -e "${bold_green}${sparkles} Cleaning Workspace SHALLOW for fresh build${end}"

    rm -rf "${path_to_python_home}" || {
        echo_error "Failed to remove '${path_to_python_home}'."
        exit_code=1
    }

    echo -e "done!"
    echo
}

function clean_workspace_deep() {
    echo_time
    echo -e "${bold_green}${sparkles} Cleaning Workspace DEEP for fresh build${end}"

    rm -rf "${path_to_runtime_root}" || {
        echo_error "Failed to remove '${path_to_runtime_root}'."
        exit_code=1
    }

    rm -rf "${path_to_tmpwork_root}" || {
        echo_error "Failed to remove '${path_to_tmpwork_root}'."
        exit_code=1
    }

    rm -rf "${path_to_log_root}" || {
        echo_error "Failed to remove '${path_to_log_root}'."
        exit_code=1
    }

    echo -e "done!"
    echo
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

    # Make lib64 → lib symlink
    ln -sf "./lib" "${path_to_local}/lib64"

    echo -e "done!"
    echo
}

function prepare_sysroot_macos() {
    local version

    # We want to build the interpreter with the same version of the current macos running this
    # script, so if the skd for the same version of this macos is not available we stop
    version=$(sw_vers -productVersion 2>/dev/null | cut -d '.' -f1 || echo "error-finding-macos-version")
    sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX${version}.sdk/"

    if [[ ! -d "${sdk_path}" ]]; then
        echo_error "MacOS SDK not found for version '${version}' on this machine"
        exit_code=1
    fi

    rsync -aHE "${sdk_path}" "${path_to_sysroot}/" || {
        echo_error "Failed to copy 'sysroot'."
        exit_code=1
    }
}

function linux_pkg_family() {
    # Detect which package-manager family this Linux host belongs to.
    # Echoes 'apt' (Debian/Ubuntu) or 'yum' (Fedora/RHEL/CentOS/Amazon Linux).
    #
    # Gating on the family rather than on a hard-coded platform_identifier
    # (e.g. 'debian13-') means new releases of either family are picked up
    # without touching this script.

    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        echo "unknown"
    fi
}

function linux_multiarch_triplet() {
    # Echo the Debian multiarch triplet for this host, e.g.
    # 'aarch64-linux-gnu' or 'x86_64-linux-gnu'.
    #
    # On Debian, libraries and arch-specific headers live in
    # <prefix>/lib/<triplet> and <prefix>/include/<triplet> rather than in
    # the flat lib64/include layout used by the RPM distros, so several of
    # the Debian-only functions below need this value.
    #
    # `gcc -print-multiarch` is preferred over
    # `dpkg-architecture -qDEB_HOST_MULTIARCH` because gcc is already a
    # build prerequisite while dpkg-dev is not. Note this is the *compiler*
    # spelling of the architecture (aarch64-...), which differs from the
    # dpkg spelling (arm64) — the triplet is the one we need for paths.
    #
    # This is called via $(...), so it must signal failure through its exit
    # status: an `exit_code=1` assignment here would happen in the
    # substitution subshell and be discarded. Callers use "errexit" to abort.

    local triplet

    triplet="$(gcc -print-multiarch 2>/dev/null)" || triplet=""

    if [[ -z "${triplet}" ]]; then
        echo_error "Failed to determine multiarch triplet via 'gcc -print-multiarch'." "errexit"
        exit_code=1
    fi

    echo "${triplet}"
}

function prerequisites_for_debian() {
    echo -e "Redirecting output to '${path_to_log_root}/prepare_os_linux.log'"

    # Non-interactive so no package can stop the build on a debconf prompt,
    # and a generous dpkg lock timeout because `main` may launch several
    # builds concurrently and apt — unlike dnf — fails immediately rather
    # than waiting when another process holds the lock.
    export DEBIAN_FRONTEND=noninteractive

    sudo -E apt-get -y -o DPkg::Lock::Timeout=600 update \
        >"${path_to_log_root}/prepare_os_linux.log" 2>&1 || {
        echo_error "Failed to apt-get update."
        exit_code=1
    }

    # NOTE: deliberately no blanket `apt-get upgrade` here (the yum branch
    # does one). Upgrading every package on each invocation risks kernel and
    # initramfs churn on the build host for no build-related benefit.
    #
    # build-essential brings gcc, g++ and make in one package. g++ matters:
    # create_compiler_wrapper defaults REAL_CXX to g++, and the yum branch
    # installs gcc without gcc-c++, so that default can be missing there.
    sudo -E apt-get -y -o DPkg::Lock::Timeout=600 install \
        mmdebstrap \
        patchelf \
        perl \
        binutils \
        file \
        rsync \
        findutils \
        bash \
        git \
        coreutils \
        sed \
        tar \
        gzip \
        build-essential \
        libc6-dev \
        >>"${path_to_log_root}/prepare_os_linux.log" 2>&1 || {
        echo_error "Failed to apt-get install prerequisites."
        exit_code=1
    }
}

function prepare_sysroot_debian() {
    # Build the compile-time sysroot with mmdebstrap.
    #
    # Why mmdebstrap and not `apt-get -o RootDir=` or debootstrap:
    #   - `apt-get -o RootDir=` cannot bootstrap from an empty directory; it
    #     needs a pre-seeded dpkg status DB, sources.list and keyrings.
    #   - debootstrap runs maintainer scripts and takes host locks, which
    #     collides with building several Python versions in parallel.
    #   - mmdebstrap --variant=extract resolves dependencies and unpacks
    #     them without configuring anything, never consulting what is
    #     installed on the host. That is the closest match to
    #     `yum --installroot --setopt=tsflags=nodocs`.
    #
    # --variant=extract (not =custom) is required: =custom runs dpkg inside
    # the target and fails on an empty tree.
    #
    # This sysroot is intentionally far leaner than the yum one, which also
    # installs bash/coreutils/sed/tar/gzip/gcc/make. Nothing is ever
    # *executed* from the sysroot — it is consumed only via --sysroot at
    # compile and link time and is deleted before packaging — so shipping
    # only the C runtime is both sufficient and strictly more
    # pollution-proof: anything the build reaches for that is not glibc must
    # come from our own local/ tree or fail loudly.
    #
    # No `rpm --initdb` equivalent is needed; mmdebstrap requires no
    # pre-existing package database.

    local codename gcc_major

    rm -rf "${path_to_sysroot}" || {
        echo_error "Failed to remove '${path_to_sysroot}'."
        exit_code=1
    }

    mkdir -p "${path_to_sysroot}" || {
        echo_error "Failed to create '${path_to_sysroot}'."
        exit_code=1
    }

    codename="$(debian_codename)" || {
        exit_code=1
    }

    # libstdc++ dev headers are versioned after the compiler
    # (libstdc++-14-dev on trixie), so derive the major from the host gcc
    # rather than pinning a version that would silently break on the next
    # Debian release.
    gcc_major="$(gcc -dumpversion 2>/dev/null | cut -d '.' -f 1)" || gcc_major=""

    if [[ -z "${gcc_major}" ]]; then
        echo_error "Failed to determine gcc major version for libstdc++ dev package."
        exit_code=1
    fi

    # The --extract-hook recreates the merged-/usr symlinks. This is
    # required, not cosmetic: glibc ships libc.so and libm.so as ld scripts
    # holding *absolute* paths, e.g.
    #
    #   GROUP ( /lib/<triplet>/libc.so.6 ... AS_NEEDED ( /lib/ld-linux-<arch>.so.1 ) )
    #
    # and ld resolves those *inside* the sysroot. Without a lib -> usr/lib
    # symlink every link fails with "cannot find /lib/<triplet>/libc.so.6
    # inside <sysroot>", which autoconf reports only as the generic
    # "C compiler cannot create executables".
    #
    # Debian is fully merged-/usr (/lib, /bin and /sbin are symlinks into
    # /usr; there is no /lib64), but the symlinks are created by the usrmerge
    # maintainer scripts, and --variant=extract deliberately runs no
    # maintainer scripts. Neither the shipped merged-usr hook nor
    # --include=usrmerge helps: both only relocate a top-level dir that
    # already exists, and here everything is already unpacked under usr/.
    #
    # --extract-hook is the right phase: it runs after unpacking, which is
    # the last phase --variant=extract executes (a --customize-hook would
    # never fire). A failing hook makes mmdebstrap exit nonzero, so the
    # existing error check below covers it.
    echo -e "Redirecting output to '${path_to_log_root}/prepare_sysroot_linux.log'"
    sudo mmdebstrap \
        --variant=extract \
        --include="libc6-dev,linux-libc-dev,libgcc-s1,libstdc++-${gcc_major}-dev" \
        --extract-hook='for d in lib bin sbin; do ln -sfn "usr/${d}" "${1}/${d}"; done' \
        "${codename}" \
        "${path_to_sysroot}" \
        "http://deb.debian.org/debian" \
        >"${path_to_log_root}/prepare_sysroot_linux.log" 2>&1 || {
        echo_error "Failed to bootstrap sysroot with mmdebstrap."
        exit_code=1
    }
}

function debian_codename() {
    # Echo this host's Debian suite codename (e.g. 'trixie') for mmdebstrap.
    # Building against the running release keeps the produced runtime's
    # glibc requirement aligned with the host it was built on.
    #
    # Like linux_multiarch_triplet, this is called via $(...) and so reports
    # failure through its exit status rather than by setting exit_code, which
    # would be lost with the substitution subshell.

    local codename

    codename=$(grep '^VERSION_CODENAME=' /etc/os-release 2>/dev/null | head -n1 | cut -d= -f2 | tr -d '"') || codename=""

    if [[ -z "${codename}" ]]; then
        echo_error "Failed to determine Debian codename from /etc/os-release." "errexit"
        exit_code=1
    fi

    echo "${codename}"
}

function prerequisites_for_linux() {
    echo -e "Redirecting output to '${path_to_log_root}/prepare_os_linux.log'"

    sudo yum -y update >"${path_to_log_root}/prepare_os_linux.log" 2>&1 || {
        echo_error "Failed to yum update."
        exit_code=1
    }

    sudo yum -y upgrade >>"${path_to_log_root}/prepare_os_linux.log" 2>&1 || {
        echo_error "Failed to yum upgrade."
        exit_code=1
    }

    sudo yum -y install \
        patchelf \
        perl \
        binutils \
        file \
        rsync \
        findutils \
        glibc \
        glibc-headers \
        glibc-devel \
        bash \
        git \
        coreutils \
        which \
        sed \
        tar \
        gzip \
        gcc \
        make >>"${path_to_log_root}/prepare_os_linux.log" 2>&1 || {
        echo_error "Failed to yum install prerequisites."
        exit_code=1
    }
}

function prepare_sysroot_linux() {
    rm -rf "${path_to_sysroot}" || {
        echo_error "Failed to remove '${path_to_sysroot}'."
        exit_code=1
    }

    mkdir -p "${path_to_sysroot}" || {
        echo_error "Failed to create '${path_to_sysroot}'."
        exit_code=1
    }

    sudo rpm --root="${path_to_sysroot}" --initdb || {
        echo_error "Failed to create creates the empty RPM database."
        exit_code=1
    }

    echo -e "Redirecting output to '${path_to_log_root}/prepare_sysroot_linux.log'"
    sudo yum --releasever=latest \
        --installroot="${path_to_sysroot}" \
        --setopt=install_weak_deps=False \
        --setopt=tsflags=nodocs \
        -y install \
        glibc \
        glibc-headers \
        glibc-devel \
        bash \
        coreutils \
        which \
        sed \
        tar \
        gzip \
        gcc \
        make >"${path_to_log_root}/prepare_sysroot_linux.log" 2>&1 || {
        echo_error "Failed to installroot."
        exit_code=1
    }
}

function prepare_sysroot() {
    echo_time
    echo -e "${bold_green}${sparkles} Creating sysroot tree${end}"

    if [[ $(uname -s) == "Darwin" ]]; then
        prepare_sysroot_macos
    elif [[ $(uname -s) == "Linux" ]]; then
        case "$(linux_pkg_family)" in
        apt)
            prerequisites_for_debian
            prepare_sysroot_debian
            ;;
        yum)
            prerequisites_for_linux
            prepare_sysroot_linux
            ;;
        *)
            echo_error "Unsupported Linux package manager: neither apt-get nor yum found."
            exit_code=1
            ;;
        esac
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    echo -e "done!"
    echo
}

function echo_envs() {
    echo_time
    echo -e "${bold_green}${sparkles} System env now set to${end}"

    local -a cpp
    read -r -a cpp <<<"${CPPFLAGS}"

    local -a ld
    read -r -a ld <<<"${LDFLAGS}"

    echo -e "CPPFLAGS:"
    for cppflag in "${cpp[@]}"; do
        echo -e "--| ${cppflag}"
    done
    echo -e "LDFLAGS:"
    for ldflag in "${ld[@]}"; do
        echo -e "--| ${ldflag}"
    done
    echo -e "SDKROOT:"
    echo -e "--| ${SDKROOT}"
    echo -e "PY_SYSROOT:"
    echo -e "--| ${PY_SYSROOT}"
    echo -e "CC:"
    echo -e "--| ${CC}"
    echo -e "REAL_CC:"
    echo -e "--| ${REAL_CC}"
    echo -e "CXX:"
    echo -e "--| ${CXX}"
    echo -e "REAL_CXX:"
    echo -e "--| ${REAL_CXX}"
    echo -e "LDSHARED:"
    echo -e "--| ${LDSHARED}"
    echo -e "LD_LIBRARY_PATH:"
    echo -e "--| ${LD_LIBRARY_PATH}"
    echo -e "PKG_CONFIG_SYSROOT_DIR:"
    echo -e "--| ${PKG_CONFIG_SYSROOT_DIR}"
    echo -e "PKG_CONFIG_PATH:"
    echo -e "--| ${PKG_CONFIG_PATH}"
    echo -e "LIBRARY_PATH:"
    echo -e "--| ${LIBRARY_PATH}"
    echo -e "C_INCLUDE_PATH:"
    echo -e "--| ${C_INCLUDE_PATH}"
    echo -e "LIBS:"
    echo -e "--| ${LIBS}"

    echo
}

function build_generic() {
    local display_name package_dir_name package_download_filename unpacked_dir_name package_make_path package_url
    local configure_options retries max_retries compression

    display_name="${1}"                                                                     # PostgreSQL${postgres_version}
    package_dir_name="${2}"                                                                 # PostgreSQL
    package_download_filename="${3}"                                                        # postgresql-${postgres_version}.tar.gz
    unpacked_dir_name="${4}"                                                                # postgresql-${postgres_version}
    package_make_path="${5}"                                                                # postgresql-${postgres_version}/unix
    package_url="${6}"                                                                      # XXX${postgres_version}/postgresql-${postgres_version}.tar.gz
    IFS=':' read -r -a configure_options <<<"$(echo "${7}" | sed -e 's/[[:space:]]*:/:/g')" # separate them by :

    # 30 min -> 2 sec sleep * 900 secs
    retries=0
    max_retries=900

    echo_envs

    # Create fresh package_dir_name env space
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

    # Download Generic or use cached one
    while true; do
        # case 1 - the file is there and there is no lock indicating active downloading.
        #         - we use the file.

        # case 2 - the file is there and there is a lock.
        #        - the file is being downloaded.

        # case 3 - the file is not there and there is a lock.
        #        - the file is being downloaded.

        # case 4 - the file is not there and there is no lock.
        #        - acquire the lock and download.

        if [[ -f "${path_to_cache_root}/${package_dir_name}/${package_download_filename}" &&
            ! -d "${path_to_cache_root}/${package_dir_name}/${package_download_filename}.lock" ]]; then
            # File exists, assume download complete
            echo
            echo_time
            echo -e "${bold_green}${sparkles} Using cached '${display_name}'${end}"
            echo -e "done!"
            break
        # mkdir is atomic—only one process will succeed.
        elif mkdir "${path_to_cache_root}/${package_dir_name}/${package_download_filename}.lock" 2>/dev/null; then
            # Successfully acquired lock; perform the download
            echo
            echo_time
            echo -e "${bold_green}${sparkles} Downloading '${display_name}'${end}"
            # Cleanup / Remove partial download just in case was left there
            rm -rf "${path_to_cache_root:?}/${package_dir_name:?}/${package_download_filename:?}" || {
                echo_error "Failed to remove '${path_to_cache_root}/${package_dir_name}/${package_download_filename}'."
            }
            # Download
            curl -L "${package_url}" -o "${path_to_cache_root}/${package_dir_name}/${package_download_filename}" || {
                echo_error "Failed to download '${display_name}'."
                # Remove partial download
                rm -rf "${path_to_cache_root:?}/${package_dir_name:?}/${package_download_filename:?}" || {
                    echo_error "Failed to remove '${path_to_cache_root}/${package_dir_name}/${package_download_filename}'."
                }
            }
            # Always release the lock before breaking the loop
            rm -rf "${path_to_cache_root}/${package_dir_name}/${package_download_filename}.lock" || {
                echo_error "Failed to remove '${path_to_cache_root}/${package_dir_name}/${package_download_filename}.lock'."
            }
            break
        else
            # Someone else is downloading; wait for them to finish
            ((retries = retries + 1))
            if ((retries >= max_retries)); then
                echo_error "Timed out waiting for ${package_download_filename} download lock."
                exit_code=1
                break
            fi
            echo -e "Waiting for download..."
            sleep 2
        fi
    done

    # Making a copy of the tar into the tmp workspace
    rsync -a "${path_to_cache_root}/${package_dir_name}/${package_download_filename}" "${path_to_tmpwork_root}/${package_dir_name}/" || {
        echo_error "Failed to copy '${package_download_filename}' across to tmp workspace."
        exit_code=1
    }

    # Unpack Generic
    cd "${path_to_tmpwork_root}/${package_dir_name}" || {
        echo_error "Failed to change directory to '${path_to_tmpwork_root}/${package_dir_name}'."
        exit_code=1
    }
    compression="$(file "${path_to_tmpwork_root}/${package_dir_name}/${package_download_filename}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')" || {
        echo_error "Failed to detect '${package_download_filename}' compression type."
        exit_code=1
    }
    tar -x --"${compression}" -f "${path_to_tmpwork_root}/${package_dir_name}/${package_download_filename}" || {
        echo_error "Failed to unpack '${package_download_filename}'."
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
    # Only for zstd/Zstandard that uses a plain Makefile, not autotools, so there's no ./configure
    if [[ "${package_download_filename}" =~ [zZ]std ]]; then
        :
    # Only for OpenSSl that uses ./config to auto-detect platform
    elif [[ "${package_download_filename}" =~ [oO]pen[sS][sS][lL] ]]; then
        ./config "${configure_options[@]}" >"${path_to_log_root}/${unpacked_dir_name}.configure.log" 2>&1 || {
            echo_error "Failed to configure '${display_name}'."
            exit_code=1
        }
    # Any other build falls back to ./configure
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
        local os="macosx"
        export NATIVE_TCLSH="/usr/local/bin/tclsh${tcltk_version}"
    elif [[ $(uname -s) == "Linux" ]]; then
        local os="unix"
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
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

function build_zstd() {
    export PREFIX="${path_to_local}"
    build_generic \
        "Zstandard${zstd_version}" \
        "Zstandard" \
        "zstd-${zstd_version}.tar.gz" \
        "zstd-${zstd_version}" \
        "zstd-${zstd_version}" \
        "https://github.com/facebook/zstd/releases/download/v${zstd_version}/zstd-${zstd_version}.tar.gz" \
        ""
    unset PREFIX
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

function build_libnsl() {
    build_generic \
        "Libnsl${libnsl_version}" \
        "Libnsl" \
        "libnsl-${libnsl_version}.tar.xz" \
        "libnsl-${libnsl_version}" \
        "libnsl-${libnsl_version}" \
        "https://github.com/thkukuk/libnsl/releases/download/v${libnsl_version}/libnsl-${libnsl_version}.tar.xz" \
        "--prefix=${path_to_local} \
        :--enable-shared \
        :LIBS=-ltirpc"
}

function build_uuid_macos() {
    echo_time
    echo -e "${bold_green}${sparkles} Installing 'Uuid'${end}"

    rsync -a "${path_to_sysroot}/usr/include/uuid" "${path_to_local}/include/" || {
        echo_error "Failed to copy '${path_to_sysroot}/usr/include/uuid'."
        exit_code=1
    }

    echo -e "done!"
    echo
}

function build_debian_base_dependencies() {
    echo_time
    echo -e "${bold_green}${sparkles} Installing Debian dependencies${end}"

    local codename triplet

    rm -rf "${path_to_linux_dependencies_root}" || {
        echo_error "Failed to remove '${path_to_linux_dependencies_root}'."
        exit_code=1
    }

    mkdir -p "${path_to_linux_dependencies_root}" || {
        echo_error "Failed to create '${path_to_linux_dependencies_root}'."
        exit_code=1
    }

    codename="$(debian_codename)" || {
        exit_code=1
    }
    triplet="$(linux_multiarch_triplet)" || {
        exit_code=1
    }

    # Debian equivalents of the -devel packages used by the yum branch.
    #
    # Dependency resolution is mandatory, not incidental: extracting
    # e.g. libreadline-dev alone would give us the libreadline.so dev
    # symlink with no target, which rsync would copy as a dangling link and
    # check_broken_links would (correctly) reject. mmdebstrap pulls the
    # runtime packages alongside the -dev ones, so the SONAME chain
    # (libreadline.so -> .so.8 -> .so.8.2) arrives intact.
    #
    # Three entries have no counterpart in the yum list because Debian
    # splits things up differently, and each one would otherwise surface as
    # a missing module in check_python_build_logs:
    #   - libcrypt-dev         glibc no longer provides crypt(3) (libxcrypt) => _crypt
    #   - libgdbm-compat-dev   ndbm.h is split out of libgdbm-dev           => _dbm
    #   - libnsl-dev           Debian packages libnsl separately            => nis
    #
    # There is deliberately no pcre1 (libpcre3-dev): it is EOL and absent
    # from trixie onwards. pcre2 only.
    local debian_packages
    debian_packages="zlib1g-dev"
    debian_packages+=",libzstd-dev"
    debian_packages+=",libbz2-dev"
    debian_packages+=",liblzma-dev"
    debian_packages+=",libreadline-dev"
    debian_packages+=",libncurses-dev"
    debian_packages+=",libgdbm-dev"
    debian_packages+=",libgdbm-compat-dev"
    debian_packages+=",libffi-dev"
    debian_packages+=",libtirpc-dev"
    debian_packages+=",uuid-dev"
    debian_packages+=",libcrypt-dev"
    debian_packages+=",libnsl-dev"
    debian_packages+=",libgirepository1.0-dev"
    debian_packages+=",libpixman-1-dev"
    debian_packages+=",libpcre2-dev"
    debian_packages+=",libicu-dev"
    debian_packages+=",libharfbuzz-dev"
    debian_packages+=",libxext-dev"
    debian_packages+=",libxrender-dev"
    debian_packages+=",libxrandr-dev"
    debian_packages+=",libxi-dev"
    debian_packages+=",libxft-dev"
    debian_packages+=",libx11-dev"
    debian_packages+=",libxcb1-dev"
    debian_packages+=",libxau-dev"
    debian_packages+=",libxdmcp-dev"

    echo -e "Redirecting output to '${path_to_log_root}/build_linux_base_dependencies.log'"
    sudo mmdebstrap \
        --variant=extract \
        --include="${debian_packages}" \
        "${codename}" \
        "${path_to_linux_dependencies_root}" \
        "http://deb.debian.org/debian" \
        >"${path_to_log_root}/build_linux_base_dependencies.log" 2>&1 || {
        echo_error "Failed to extract Debian dependencies with mmdebstrap."
        exit_code=1
    }

    # Same allowlist as the yum branch, plus the two libraries that only
    # exist as separate packages on Debian (see the package list above).
    #
    # Note the bare "girepository" and "glib" entries the yum branch uses are
    # deliberately absent.
    local -a libs=(
        "libX11"
        "libXau"
        "libXdmcp"
        "libXext"
        "libXft"
        "libXi"
        "libXrandr"
        "libXrender"
        "libatomic"
        "libbrotli"
        "libbz2"
        # libtirpc links against the krb5/GSSAPI stack, and libnsl links
        # against libtirpc. Without these, ld cannot resolve the
        # libnsl -> libtirpc -> libgssapi_krb5 chain inside the sysroot, so
        # CPython's AC_SEARCH_LIBS([yp_match],[nsl]) probe fails and nis is
        # reported missing (<=3.12 only; nis was removed in 3.13).
        # The RPM sysroot happens to provide these already; Debian's minimal
        # one does not, so we ship them.
        "libcom_err"
        "libcrypt"
        "libcurse"
        "libexpat"
        "libffi"
        "libfontconfig"
        "libform"
        "libfreetype"
        "libgdbm"
        "libgdbm_compat"
        "libglib"
        "libgobject"
        "libgraphite2"
        "libgssapi_krb5"
        # ".so" suffix on purpose: the bare "libharfbuzz" prefix would also
        # match libharfbuzz-cairo, the one file here that needs libcairo,
        # which we do not ship (nor does the yum build). Only libharfbuzz.so
        # itself is ever linked against, so the -cairo/-gobject/-icu/-subset
        # variants would be unloadable dead ends.
        "libharfbuzz.so"
        "libhistory"
        "libicu"
        "libk5crypto"
        "libkeyutils"
        "libkrb5"
        "liblzma"
        "libncurse"
        "libnsl"
        "libpanel"
        "libpcre"
        "libpixman"
        "libpng"
        "libreadline"
        "libtinfo"
        "libtirpc"
        "libuuid"
        "libxcb"
        "libz"
        "libzstd"
    )

    # Copy only required dependencies to local dir.
    #
    # Unlike the RPM distros, Debian keeps arch-specific headers in
    # include/<triplet> (glibc's bits/*.h in particular), so that directory
    # comes across too and is added to CPPFLAGS by build_python_runtime.
    rsync -aHAXE "${path_to_linux_dependencies_root}/usr/include/" "${path_to_local}/include/" || {
        echo_error "Failed to copy '${path_to_linux_dependencies_root}/usr/include/'."
        exit_code=1
    }

    # Libraries live in usr/lib/<triplet> rather than usr/lib64. They are
    # flattened into local/lib exactly as the yum branch does, so nothing
    # downstream needs to know about the multiarch layout.
    for lib in "${libs[@]}"; do
        rsync -aHAXE "${path_to_linux_dependencies_root}/usr/lib/${triplet}/${lib}"* "${path_to_local}/lib/" || {
            echo_warning "Failed to copy '${path_to_linux_dependencies_root}/usr/lib/${triplet}/${lib}'."
        }
    done

    # Clean tmp dir
    rm -rf "${path_to_linux_dependencies_root}" || {
        echo_error "Failed to remove '${path_to_linux_dependencies_root}'."
        exit_code=1
    }

    echo -e "done!"
    echo

    # Fix rpath to the deps copied in from mmdebstrap.
    #
    # This is load-bearing, not cosmetic: the Debian .so files carry no
    # RPATH of their own, so without this a library such as libreadline
    # would resolve its own libtinfo dependency against the *host*
    # /usr/lib/<triplet> copy instead of the one in local/lib.
    fix_runtime_paths
}

function build_linux_base_dependencies() {
    echo_time
    echo -e "${bold_green}${sparkles} Installing Linux dependencies${end}"

    rm -rf "${path_to_linux_dependencies_root}" || {
        echo_error "Failed to remove '${path_to_linux_dependencies_root}'."
        exit_code=1
    }

    mkdir -p "${path_to_linux_dependencies_root}" || {
        echo_error "Failed to create '${path_to_linux_dependencies_root}'."
        exit_code=1
    }

    sudo rpm --root="${path_to_linux_dependencies_root}" --initdb || {
        echo_error "Failed to create creates the empty RPM database."
        exit_code=1
    }

    echo -e "Redirecting output to '${path_to_log_root}/build_linux_base_dependencies.log'"
    sudo yum --installroot="${path_to_linux_dependencies_root}" \
        --releasever=latest \
        --setopt=install_weak_deps=False \
        --setopt=tsflags=nodocs \
        -y install \
        zlib-devel \
        libzstd-devel \
        bzip2-devel \
        xz-devel \
        readline-devel \
        ncurses-devel \
        gdbm-devel \
        libffi-devel \
        libtirpc-devel \
        libuuid-devel \
        gobject-introspection-devel \
        pixman-devel \
        pcre-devel \
        pcre2-devel \
        libicu-devel \
        harfbuzz-devel \
        libXext-devel \
        libXrender-devel \
        libXrandr-devel \
        libXi-devel \
        libXft-devel \
        libX11-devel \
        libxcb-devel \
        libXau-devel \
        libXdmcp-devel >"${path_to_log_root}/build_linux_base_dependencies.log" 2>&1 || {
        echo_error "Failed to installroot."
        exit_code=1
    }

    local -a libs=(
        "X11"
        "girepository"
        "glib"
        "libX11"
        "libXau"
        "libXdmcp"
        "libXext"
        "libXft"
        "libXi"
        "libXrandr"
        "libXrender"
        "libbrotli"
        "libbz2"
        "libcurse"
        "libexpat"
        "libffi"
        "libfontconfig"
        "libform"
        "libfreetype"
        "libgdbm"
        "libglib"
        "libgobject"
        "libgraphite2"
        # ".so" suffix on purpose: the bare "libharfbuzz" prefix also matches
        # libharfbuzz-cairo, which needs libcairo — not shipped here and not
        # present on the build hosts, so it arrives permanently unloadable.
        # Only libharfbuzz.so itself is ever linked against, so the
        # -cairo/-gobject/-icu/-subset variants are dead weight.
        "libharfbuzz.so"
        "libicu"
        "liblzma"
        "libncurse"
        "libnsl"
        "libpanel"
        "libpcre"
        "libpixman"
        "libpng"
        "libreadline"
        "libtinfo"
        "libtirpc"
        "libuuid"
        "libxcb"
        "libxml2"
        "libz"
        "libzstd"
    )

    # Copy only required dependencies to local dir
    rsync -aHAXE "${path_to_linux_dependencies_root}/usr/include/" "${path_to_local}/include/" || {
        echo_error "Failed to copy '${path_to_linux_dependencies_root}/usr/include/'."
        exit_code=1
    }
    for lib in "${libs[@]}"; do
        rsync -aHAXE "${path_to_linux_dependencies_root}/usr/lib64/${lib}"* "${path_to_local}/lib/" || {
            echo_warning "Failed to copy '${path_to_linux_dependencies_root}/usr/lib64/${lib}'."
        }
    done

    # This only seems to be needed on AL2
    if [[ "${platform_identifier}" == *'amzn2-'* ]]; then
        # Fix some broken links that could cause lib not found later on
        #TODO: fix this hard coded version
        ln -s -f "libreadline.so.6" "${path_to_local}/lib/libreadline.so" || {
            echo_error "Failed to fix broken links."
            exit_code=1
        }
        ln -s -f "libnsl.so.1" "${path_to_local}/lib/libnsl.so" || {
            echo_error "Failed to fix broken links."
            exit_code=1
        }
    fi

    # Clean tmp dir
    rm -rf "${path_to_linux_dependencies_root}" || {
        echo_error "Failed to remove '${path_to_linux_dependencies_root}'."
        exit_code=1
    }

    echo -e "done!"
    echo

    # Fix rpath to the deps copied in from yum/dnf
    fix_runtime_paths
}

function build_python_runtime() {
    local flags enable_workaround

    # Export the below to compile the python dependencies
    if [[ $(uname) == "Darwin" ]]; then
        # macOS C compiler and Linker options for python dependencies
        export SDKROOT="${path_to_sysroot}"

        export CPPFLAGS="--sysroot=${path_to_sysroot} \
                         -I${path_to_local}/include \
                         -I${path_to_sysroot}/usr/include"

        export LDFLAGS="--sysroot=${path_to_sysroot} \
                        -L${path_to_local}/lib \
                        -L${path_to_sysroot}/usr/lib"

        # Be paranoid and strip the system include/library hints
        unset C_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR
    elif [[ $(uname -s) == "Linux" ]]; then
        case "$(linux_pkg_family)" in
        apt)
            # Debian C compiler and Linker options for python dependencies.
            #
            # Differs from the yum branch in the multiarch paths: arch
            # headers are in include/<triplet> and libraries in
            # lib/<triplet>, and there is no usr/lib64 at all.
            local dep_triplet
            dep_triplet="$(linux_multiarch_triplet)" || {
                exit_code=1
            }

            export LD_LIBRARY_PATH="${path_to_local}/lib"

            export CPPFLAGS="--sysroot=${path_to_sysroot} \
                             -I${path_to_local}/include \
                             -I${path_to_local}/include/${dep_triplet} \
                             -I${path_to_local}/include/tirpc \
                             -I${path_to_sysroot}/usr/include \
                             -I${path_to_sysroot}/usr/include/${dep_triplet}"

            export LDFLAGS="--sysroot=${path_to_sysroot} \
                            -L${path_to_local}/lib \
                            -L${path_to_sysroot}/usr/lib \
                            -L${path_to_sysroot}/usr/lib/${dep_triplet} \
                            -Wl,-rpath,${path_to_local}/lib \
                            -Wl,-rpath-link,${path_to_local}/lib"

            # Be paranoid and strip the system include/library hints
            unset C_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR
            ;;
        yum)
            # Linux C compiler and Linker options for python dependencies
            export LD_LIBRARY_PATH="${path_to_local}/lib"

            export CPPFLAGS="--sysroot=${path_to_sysroot} \
                             -I${path_to_local}/include \
                             -I${path_to_local}/include/tirpc \
                             -I${path_to_sysroot}/usr/include"

            export LDFLAGS="--sysroot=${path_to_sysroot} \
                            -L${path_to_local}/lib \
                            -L${path_to_sysroot}/usr/lib \
                            -L${path_to_sysroot}/usr/lib64 \
                            -Wl,-rpath,${path_to_local}/lib \
                            -Wl,-rpath-link,${path_to_local}/lib"

            # Be paranoid and strip the system include/library hints
            unset C_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR
            ;;
        *)
            echo_error "Unsupported Linux package manager: neither apt-get nor yum found."
            exit_code=1
            ;;
        esac
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    if [[ "${python_full_version}" == "3.15."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_readline
            build_gdbm
            build_xz
            build_zstd
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                build_debian_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.14."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_readline
            build_gdbm
            build_xz
            build_zstd
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                build_debian_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.13."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                build_debian_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.12."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                build_debian_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.11."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                build_debian_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.10."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                build_debian_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.9."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.8."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    elif [[ "${python_full_version}" == "3.7."* ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            build_tcltk
            build_openssl
            build_libffi
            build_ncurses
            build_readline
            build_gdbm
            build_xz
            build_uuid_macos
            build_sqlite3
        elif [[ $(uname -s) == "Linux" ]]; then
            if [[ "${platform_identifier}" == *'debian13-'* ]]; then
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            elif [[ "${platform_identifier}" == *'centos9-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2023-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
                build_libnsl
            elif [[ "${platform_identifier}" == *'amzn2-'* ]]; then
                build_linux_base_dependencies
                build_tcltk
                build_openssl
                build_sqlite3
            else
                echo_error "Unsupported Linux platform: ${platform_identifier}"
                exit_code=1
            fi
        else
            echo_error "Unsupported platform: $(uname -s)"
            exit_code=1
        fi

        flags="--prefix=${path_to_python_home} \
               :--enable-optimizations \
               :--with-lto \
               :--with-computed-gotos \
               :--with-openssl=${path_to_local} \
               :--with-openssl-rpath=no \
               :--enable-loadable-sqlite-extensions"

    else
        echo_error "Unsupported Python version: ${python_full_version}"
    fi

    # Export the below to compile Cpython
    if [[ $(uname) == "Darwin" ]]; then
        # macOS C compiler and Linker options for Python
        export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

        export CPPFLAGS="-I${path_to_local}/include \
                         -I${path_to_local}/include/uuid"

        export LDFLAGS="-L${path_to_local}/lib \
                        -Wl,-rpath,@loader_path/../"

        # Be paranoid and strip the system include/library hints
        unset C_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR

        # Options for Python third-party dependencies
        export TCLTK_CFLAGS="-I${path_to_local}/include"
        export TCLTK_LIBS="-L${path_to_local}/lib -framework Tcl -framework Tk"
    elif [[ $(uname -s) == "Linux" ]]; then
        # Inject sysroot *only* via the compiler driver, not via CPPFLAGS/LDFLAGS:
        # - create_compiler_wrapper writes tiny shims (cc-sysroot / cxx-sysroot)
        #   that exec the real compiler with:  --sysroot="$PY_SYSROOT"
        # - We point CC/CXX/LDSHARED at those shims so both compilation and
        #   shared-object linking see the sysroot.
        # - We intentionally keep CPPFLAGS/LDFLAGS free of --sysroot to avoid
        #   leaking absolute paths into Python's sysconfig/python3-config.
        # - The wrappers live under ${path_to_tmpwork_root} and aren't packaged,
        #   so the final runtime has no dependency on host SDK locations.

        # Create tiny CC/CXX wrappers that add --sysroot only at compile/link time
        # (so configure/sysconfig never see --sysroot in CPPFLAGS/LDFLAGS)
        create_compiler_wrapper
        # build C sources via wrapper
        export CC="${CC_WRAPPER}"
        # build any C++ sources via wrapper
        export CXX="${CXX_WRAPPER}"
        # link .so via wrapper (gets sysroot too)
        export LDSHARED="${CC_WRAPPER} -shared"

        # Linux C compiler and Linker options for Python
        export LD_LIBRARY_PATH="${path_to_local}/lib"

        # On Debian glibc's arch headers (bits/*.h) live in
        # include/<triplet>, so that directory has to be searched too or
        # configure fails to find basic system headers. Libraries were
        # already flattened into local/lib by
        # build_debian_base_dependencies, so LDFLAGS needs no triplet.
        local py_triplet_inc=""
        if [[ "${platform_identifier}" == *'debian13-'* ]]; then
            local py_triplet
            py_triplet="$(linux_multiarch_triplet)" || {
                exit_code=1
            }
            py_triplet_inc="-I${path_to_local}/include/${py_triplet}"
        fi

        export CPPFLAGS="-I${path_to_local}/include \
                         ${py_triplet_inc} \
                         -I${path_to_local}/include/tirpc \
                         -I${path_to_local}/include/uuid"

        export LDFLAGS="-L${path_to_local}/lib \
                        -Wl,-rpath,${path_to_local}/lib \
                        -Wl,-rpath,${path_to_python_home}/lib \
                        -Wl,-rpath-link,${path_to_local}/lib"

        # Be paranoid and strip the system include/library hints
        unset C_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR

        # Options for Python third-party dependencies
        export TCLTK_CFLAGS="-I${path_to_local}/include"
        export TCLTK_LIBS="-L${path_to_local}/lib -ltcl${tcltk_version} -ltclstub${tcltk_version} -ltk${tcltk_version} -ltkstub${tcltk_version}"

        # This only seems to be needed on AL2
        # To enable replace false with true
        enable_workaround=false
        if [[ "${platform_identifier}" == *'amzn2-'* ]] && "${enable_workaround}"; then
            # For some unknown reasons this test sometimes fails, this workaround seem to work
            local test_generators test_poplib test_ftplib
            test_generators='-x test_generators'
            test_poplib='-x test_poplib'
            test_ftplib='-x test_ftplib'
            PROFILE_TASK="-m test --pgo ${test_generators} ${test_poplib} ${test_ftplib}"
            export PROFILE_TASK
        fi
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    build_generic \
        "CPython${python_full_version}" \
        "CPython/${python_full_version}" \
        "Python-${python_full_version}.tgz" \
        "Python-${python_full_version}" \
        "Python-${python_full_version}" \
        "https://www.python.org/ftp/python/${python_full_version}/Python-${python_full_version}.tgz" \
        "${flags}"

    # Make lib64 → lib symlink
    ln -sf "./lib" "${path_to_python_home}/lib64" || {
        echo_error "Failed to create lib64 symlink."
        exit_code=1
    }

    # Create .envroot file
    touch "${path_to_python_home}/.envroot" || {
        echo_error "Failed to create .envroot file."
        exit_code=1
    }
}

function create_compiler_wrapper() {
    # DO NOT declare local CC_WRAPPER and CXX_WRAPPER as
    # they are being used here above!!
    CC_WRAPPER="${path_to_tmpwork_root}/cc-sysroot"
    CXX_WRAPPER="${path_to_tmpwork_root}/cxx-sysroot"

    # C compiler wrapper: inject --sysroot without leaking it into Python's sysconfig
    cat >"${CC_WRAPPER}" <<EOF
#!/usr/bin/env bash
exec "\${REAL_CC:-gcc}" --sysroot="${path_to_sysroot}" "\$@"
EOF
    chmod +x "${CC_WRAPPER}"

    # C++ compiler wrapper for modules that use C++
    cat >"${CXX_WRAPPER}" <<EOF
#!/usr/bin/env bash
exec "\${REAL_CXX:-g++}" --sysroot="${path_to_sysroot}" "\$@"
EOF
    chmod +x "${CXX_WRAPPER}"
}

function check_python_build_logs() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking logs after build${end}"

    grep -E -n \
        -e '[fF]ollowing modules built successfully but were removed because they could not be imported' \
        -e 'could not be imported' \
        -e '[fF]ailed to build' \
        -e 'to build these optional modules were not found' \
        -e 'modules were not found' \
        -e '[tT]o find the necessary bits, look in configure' \
        -e '[cC]ould not build the' \
        -e '[pP]ython requires' \
        -e 'since importing it failed' \
        -e 'Traceback ' \
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

    # Ensure include is empty (dev headers not needed at runtime)
    rm -rf "${path_to_local}/include/" || {
        echo_error "Failed to remove '${path_to_local}/include'."
        exit_code=1
    }
    mkdir -p "${path_to_local}/include/" || {
        echo_error "Failed to create '${path_to_local}/include/'."
        exit_code=1
    }

    # Existing cache/file cleanup
    #
    # cmake joins pkgconfig here: both are build-time metadata directories
    # that describe where headers and libraries live, so they are useless at
    # runtime and their contents embed absolute build paths.
    local dirs_to_clean=(
        ".mypy_cache"
        ".pytest_cache"
        "__pycache__"
        "pkgconfig"
        "cmake"
    )
    for dir in "${dirs_to_clean[@]}"; do
        find "${path_to_python_home}" -type d -name "${dir}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${dir}'."
            exit_code=1
        }
    done

    # *.cmake joins *.pc for the same reason: build-time metadata. The
    # dirs_to_clean pass above only catches a directory actually named
    # "cmake" (as OpenSSL installs), so the glob is still needed for packages
    # that drop their .cmake files elsewhere (libpng uses lib/libpng/).
    local files_to_clean=(
        ".DS_Store"
        "Thumbs.db"
        "*.pyc"
        "*.pc"
        "*.cmake"
    )
    for file in "${files_to_clean[@]}"; do
        find "${path_to_python_home}" \( -type f -o -type l \) -name "${file}" -print -exec rm -rf {} + || {
            echo_error "Failed to clean '${file}'."
            exit_code=1
        }
    done

    if [[ "${optimize_space}" == true ]]; then
        # Docs/man/info
        local dirs_to_clean=(
            "doc"
            "docs"
            "man"
            "info"
            "gtk-doc"
        )
        for dir in "${dirs_to_clean[@]}"; do
            find "${path_to_local}/share" -mindepth 1 -maxdepth 1 -name "${dir}" -print -exec rm -rf {} + || {
                echo_warning "Failed to remove some share/* files."
                exit_code=1
            }
        done

        # Static & libtool artifacts — keep only things the loader can use
        local files_to_clean=(
            "*.a"
            "*.la"
        )
        for file in "${files_to_clean[@]}"; do
            find "${path_to_python_home}" \( -type f -o -type l \) -name "${file}" -print -delete || {
                echo_error "Failed to clean '${file}'."
                exit_code=1
            }
        done

        # TCL/Tk demos (runtime not required)
        local dirs_to_clean=(
            "tk*"/demos
            "tcl*"/demos
        )
        for dir in "${dirs_to_clean[@]}"; do
            find "${path_to_local}/lib" -maxdepth 2 -type d -name "${dir}" -print -exec rm -rf {} + || {
                echo_warning "Failed to remove TCL/Tk demos."
                exit_code=1
            }
        done

        # Remove CPython test suites to save space
        # prune lib2to3/tests, tkinter/test, distutils/tests, etc.
        local dirs_to_clean=(
            "test"
            "tests"
        )
        for dir in "${dirs_to_clean[@]}"; do
            find "${path_to_python_home}/lib/python${python_version}" -type d -name "${dir}" -print -exec rm -rf {} + || {
                echo_warning "Failed to remove CPython test suites."
                exit_code=1
            }
        done
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
    du -h "${python_builds}/${python_pkg_full_name}"
    echo -e "done!"
    echo
}

function fix_runtime_paths_macos() {
    # Make every dylib install-name relative @rpath.
    #
    # Process substitution, not a pipe, to match the other fix_/check_
    # helpers: a `find … | while` pipeline runs the loop body in a subshell,
    # so anything assigned in there (exit_code included) would be discarded.
    while IFS= read -r -d '' bin; do
        if file "${bin}" | grep -q 'Mach-O'; then
            extension=$(echo "${bin}" | sed "s|${path_to_python_home}/||g")
            install_name_tool -id "@rpath/${extension}" "${bin}"

            if otool -L "${bin}" | tail -n +2 | grep -q "${path_to_local}/lib/"; then
                while read -r lib; do
                    extension=$(echo "${lib}" | sed "s|${path_to_local}/lib/||g")
                    install_name_tool -change "${lib}" "@rpath/local/lib/${extension}" "${bin}"
                done < <(otool -L "${bin}" | tail -n +2 | grep "${path_to_local}/lib/" | awk '{print $1}')
            fi

            if otool -L "${bin}" | tail -n +2 | grep -q '^[[:space:]]*/Library/Frameworks/'; then
                while read -r fw; do
                    extension=$(echo "${fw}" | sed "s|/Library/Frameworks/||g")
                    install_name_tool -change "${fw}" "@rpath/local/Frameworks/${extension}" "${bin}"
                done < <(otool -L "${bin}" | tail -n +2 | grep '^[[:space:]]*/Library/Frameworks/' | awk '{print $1}')
            fi
        fi
    done < <(
        find "${path_to_python_home}" \
            \( -path "${path_to_python_home}/sysroot" -prune \) -o \
            \( \( -type f -o -type l \) \
            \( -perm -111 \
            -o -name '*.so*' \
            -o -name '*.dylib' \
            -o -name '*.bundle' \
            -o -name '*.sl' \) \
            -print0 \
            \)
    )

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

    local new_path='$ORIGIN:$ORIGIN/..:$ORIGIN/../..:$ORIGIN/../../..:$ORIGIN/../../../..:$ORIGIN/../../../../..:$ORIGIN/../lib:$ORIGIN/../../lib:$ORIGIN/../../../lib:$ORIGIN/../local/lib:$ORIGIN/../../local/lib:$ORIGIN/../../../local/lib:$ORIGIN/../../../../local/lib:$ORIGIN/../../../../../local/lib'

    # Make all .so files look for libraries in new_path.
    #
    # Process substitution, not a pipe, so a failed patchelf sets exit_code in
    # this shell instead of in a subshell that throws it away.
    while IFS= read -r -d '' fh; do
        if file "${fh}" | grep -q ' ELF'; then
            if file "${fh}" | grep -q 'relocatable'; then
                # Disabling debugging log
                # echo -e "skipping file-is-relocatable '${fh}'"
                continue
            fi
            dynamic_section=$(readelf -d "${fh}")
            if [[ "${dynamic_section}" == *"there is no dynamic section in this file"* ]]; then
                # Disabling debugging log
                # echo -e "skipping there-is-no-dynamic-section-in-this-file '${fh}'"
                continue
            else
                patchelf --force-rpath --set-rpath "${new_path}" "${fh}" || {
                    echo_error "Failed to patch '${fh}'."
                    exit_code=1
                }
            fi
        fi
    done < <(
        find "${path_to_python_home}" \
            \( -path "${path_to_python_home}/sysroot" -prune \) -o \
            \( \( -type f -o -type l \) \
            -print0 \
            \)
    )
}

function fix_runtime_paths() {
    echo_time
    echo -e "${bold_green}${sparkles} Fixing id's and rpaths${end}"
    local extension lib fw

    if [[ $(uname -s) == "Darwin" ]]; then
        fix_runtime_paths_macos
    elif [[ $(uname -s) == "Linux" ]]; then
        fix_runtime_paths_linux || {
            echo_warning "Segmentation fault (core dumped). retrying..."
            fix_runtime_paths_linux || {
                echo_error "Failed to fix runtime paths."
                exit_code=1
            }
        }
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    echo -e "done!"
    echo
}

function echo_lib_ref() {
    local file="${1}"
    local lib="${2}"
    echo -e "'${file}' links to lib '${lib}'"
}

function check_loadable_refs_macos() {
    local file lib bad_refs
    local forbidden_paths=("/Library/Developer/CommandLineTools")

    # Process substitution, not a pipe, so exit_code assignments below happen
    # in this shell rather than in a subshell that discards them.
    while IFS= read -r -d '' file; do
        # Skip the header line from otool -L, grab only the referenced install names
        while read -r lib; do
            case "${lib}" in
            @*)
                # relative reference – OK
                ;;
            /System/* | \
                /usr/lib/*)
                # system lib – OK
                ;;
            "${path_to_sysroot}"/*)
                # this is one of our local dir lib pointing at the sysroot - NOT OK
                echo -e "Match case macOS_01"
                echo_lib_ref "${file}" "${lib}"
                exit_code=1
                bad_refs=1
                ;;
            *)
                # any extra "forbidden" prefixes
                for p in "${forbidden_paths[@]}"; do
                    if [[ "${lib}" == "${p}"* ]]; then
                        echo -e "Match case macOS_02"
                        echo_lib_ref "${file}" "${lib}"
                        exit_code=1
                        bad_refs=1
                    fi
                done
                if [[ "${file}" == *".a" ]]; then
                    # static library – OK
                    continue
                fi
                # Not sure what this is so let's log it
                echo -e "Match case macOS_03"
                echo_lib_ref "${file}" "${lib}"
                exit_code=1
                bad_refs=1
                ;;
            esac
        done < <(otool -L "${file}" | tail -n +2 | awk '{print $1}')
    done < <(
        find "${path_to_python_home}" \
            \( -path "${path_to_python_home}/sysroot" -prune \) -o \
            \( -type f \
            \( -perm -111 \
            -o -name '*.so*' \
            -o -name '*.dylib' \
            -o -name '*.bundle' \
            -o -name '*.sl' \) \
            -print0 \
            \)
    )

    if [[ "${bad_refs}" -eq 1 ]]; then
        echo_error "Bad loadable references found in Mach-O objects."
    fi
}

function check_loadable_refs_debian() {
    # Debian counterpart of check_loadable_refs_linux.
    #
    # The logic is identical; only the "core system libraries" allowlist
    # differs, because Debian resolves libraries through multiarch paths
    # (/lib/<triplet>/libc.so.6) rather than the flat /lib64 used by the RPM
    # distros. Without the triplet-aware patterns every core system library
    # would fall through to the catch-all and fail the build.
    #
    # The patterns stay per-library on purpose: a blanket
    # /lib/*-linux-gnu/* would defeat the point of this check, which is to
    # catch one of our own libraries silently resolving against the host's
    # copy instead of the one in local/lib.

    local file lib rpath dynamic_section ldd_failed response bad_refs
    local forbidden_paths=()

    # Both loops are fed by process substitution rather than a pipe so that
    # they run in *this* shell: a `find … | while` pipeline puts the loop
    # body in a subshell, where every exit_code=1 below would be discarded
    # and the build would report success despite finding bad references.
    while IFS= read -r -d '' file; do
        if file "${file}" | grep -q ' ELF'; then
            response=""
            dynamic_section=$(readelf -d "${file}")
            if [[ "${dynamic_section}" == *"there is no dynamic section in this file"* ]]; then
                response="there-is-no-dynamic-section-in-this-file"
            else
                ldd_failed=0
                ldd -v "${file}" >/dev/null 2>&1 || ldd_failed=1
                if [[ "${ldd_failed}" -eq 0 ]]; then
                    response=$(ldd -v "${file}" | awk '/=>/ {print $3}')
                else
                    response="failed-to-run-ldd-on-file."
                    exit_code=1
                    bad_refs=1
                fi
            fi
        else
            # Short-circuit non-ELF files right away
            continue
        fi
        while read -r lib; do
            case "${lib}" in
            /lib/*/ld-linux* | /usr/lib/*/ld-linux* | \
                /lib/ld-linux* | /usr/lib/ld-linux* | \
                /lib/*/libc[.-]* | /usr/lib/*/libc[.-]* | \
                /lib/*/libcom_err* | /usr/lib/*/libcom_err* | \
                /lib/*/libcrypt[.-]* | /usr/lib/*/libcrypt[.-]* | \
                /lib/*/libdl[.-]* | /usr/lib/*/libdl[.-]* | \
                /lib/*/libgcc_s* | /usr/lib/*/libgcc_s* | \
                /lib/*/libgssapi_krb5* | /usr/lib/*/libgssapi_krb5* | \
                /lib/*/libk5crypto* | /usr/lib/*/libk5crypto* | \
                /lib/*/libkeyutils* | /usr/lib/*/libkeyutils* | \
                /lib/*/libkrb5[.-]* | /usr/lib/*/libkrb5[.-]* | \
                /lib/*/libkrb5support* | /usr/lib/*/libkrb5support* | \
                /lib/*/libm[.-]* | /usr/lib/*/libm[.-]* | \
                /lib/*/libpthread[.-]* | /usr/lib/*/libpthread[.-]* | \
                /lib/*/libresolv[.-]* | /usr/lib/*/libresolv[.-]* | \
                /lib/*/librt[.-]* | /usr/lib/*/librt[.-]* | \
                /lib/*/libselinux* | /usr/lib/*/libselinux* | \
                /lib/*/libstdc++* | /usr/lib/*/libstdc++* | \
                /lib/*/libutil[.-]* | /usr/lib/*/libutil[.-]*)
                # Core "system" libraries we can assume exist on the host machine
                ;;
            "${path_to_python_home}"/lib* | \
                "${path_to_python_home}"/local/bin* | \
                "${path_to_python_home}"/local/lib*)
                rpath="$(readelf -d "${file}" | awk -F '[][]' '/(RPATH|RUNPATH)/ {print $2}')"
                if [[ "${rpath}" == *'$ORIGIN/../local/lib'* ]]; then
                    # this are definitely our relative reference – OK
                    :
                else
                    # file doesn't have an RPATH or
                    # file has an hard coded absolute rpath - NOT OK
                    # however if the file is in the sysroot we will ignore it
                    if [[ "${file}" == "${path_to_sysroot}"* ]]; then
                        # if the file is in the sysroot itself ignore it as will get deleted
                        :
                    else
                        # absolute rpath pointing at our path_to_python_home/...
                        echo -e "Match case Debian_01"
                        echo_lib_ref "${file}" "${lib}"
                        exit_code=1
                        bad_refs=1
                    fi
                fi
                ;;
            "${path_to_sysroot}"/*)
                if [[ "${file}" == "${path_to_sysroot}"* ]]; then
                    # if the file is in the sysroot itself ignore it as will get deleted
                    :
                else
                    # this is one of our local dir lib pointing at the sysroot - NOT OK
                    echo -e "Match case Debian_02"
                    echo_lib_ref "${file}" "${lib}"
                    exit_code=1
                    bad_refs=1
                fi
                ;;
            *)
                # any extra "forbidden" prefixes
                for p in "${forbidden_paths[@]}"; do
                    if [[ "${lib}" == "${p}"* ]]; then
                        echo -e "Match case Debian_03"
                        echo_lib_ref "${file}" "${lib}"
                        exit_code=1
                        bad_refs=1
                    fi
                done
                if [[ -z "${lib}" ]]; then
                    # response has not been set here above so it's ''
                    continue
                fi
                if [[ "${lib}" == '=>' ]]; then
                    # sometimes `ldd … | awk '/=>/ {print $3}'` will emit a bare "=>"
                    # when there's no third field, so skip it
                    continue
                fi
                if [[ "${file}" == "${path_to_sysroot}"* ]]; then
                    # if the file is in the sysroot ignore it as will get deleted
                    continue
                fi
                if [[ "${file}" == *".a" ]]; then
                    # static library – OK
                    continue
                fi
                # Not sure what this is so let's log it
                echo -e "Match case Debian_04"
                echo_lib_ref "${file}" "${lib}"
                exit_code=1
                bad_refs=1
                ;;
            esac
        done < <(printf '%s\n' "${response}")
    done < <(
        find "${path_to_python_home}" \
            \( -path "${path_to_python_home}/sysroot" -prune \) -o \
            \( \( -type f -o -type l \) \( -perm -111 \) \
            -print0 \
            \)
    )

    if [[ "${bad_refs}" -eq 1 ]]; then
        echo_error "Bad loadable references found in ELF objects."
    fi
}

function check_loadable_refs_linux() {
    local file lib rpath dynamic_section ldd_failed response bad_refs
    local forbidden_paths=()

    # Process substitution, not a pipe, so exit_code assignments below happen
    # in this shell rather than in a subshell that discards them.
    while IFS= read -r -d '' file; do
        if file "${file}" | grep -q ' ELF'; then
            response=""
            dynamic_section=$(readelf -d "${file}")
            if [[ "${dynamic_section}" == *"there is no dynamic section in this file"* ]]; then
                response="there-is-no-dynamic-section-in-this-file"
            else
                ldd_failed=0
                ldd -v "${file}" >/dev/null 2>&1 || ldd_failed=1
                if [[ "${ldd_failed}" -eq 0 ]]; then
                    response=$(ldd -v "${file}" | awk '/=>/ {print $3}')
                else
                    response="failed-to-run-ldd-on-file."
                    exit_code=1
                    bad_refs=1
                fi
            fi
        else
            # Short-circuit non-ELF files right away
            continue
        fi
        while read -r lib; do
            case "${lib}" in
            /lib/ld-linux* | /lib64/ld-linux* | \
                /lib/libc* | /lib64/libc* | \
                /lib/libcom_err* | /lib64/libcom_err* | \
                /lib/libdl* | /lib64/libdl* | \
                /lib/libgcc_s* | /lib64/libgcc_s* | \
                /lib/libgssapi_krb5* | /lib64/libgssapi_krb5* | \
                /lib/libk5crypto* | /lib64/libk5crypto* | \
                /lib/libkeyutils* | /lib64/libkeyutils* | \
                /lib/libkrb5* | /lib64/libkrb5* | \
                /lib/libkrb5support* | /lib64/libkrb5support* | \
                /lib/libm* | /lib64/libm* | \
                /lib/libpthread* | /lib64/libpthread* | \
                /lib/libresolv* | /lib64/libresolv* | \
                /lib/librt* | /lib64/librt* | \
                /lib/libselinux* | /lib64/libselinux* | \
                /lib/libstdc++* | /lib64/libstdc++* | \
                /lib/libutil* | /lib64/libutil*)
                # Core "system" libraries we can assume exist on the host machine
                ;;
            "${path_to_python_home}"/lib* | \
                "${path_to_python_home}"/local/bin* | \
                "${path_to_python_home}"/local/lib*)
                rpath="$(readelf -d "${file}" | awk -F '[][]' '/(RPATH|RUNPATH)/ {print $2}')"
                if [[ "${rpath}" == *'$ORIGIN/../local/lib'* ]]; then
                    # this are definitely our relative reference – OK
                    :
                else
                    # file doesn't have an RPATH or
                    # file has an hard coded absolute rpath - NOT OK
                    # however if the file is in the sysroot we will ignore it
                    if [[ "${file}" == "${path_to_sysroot}"* ]]; then
                        # if the file is in the sysroot itself ignore it as will get deleted
                        :
                    else
                        # absolute rpath pointing at our path_to_python_home/...
                        echo -e "Match case Linux_01"
                        echo_lib_ref "${file}" "${lib}"
                        exit_code=1
                        bad_refs=1
                    fi
                fi
                ;;
            "${path_to_sysroot}"/*)
                if [[ "${file}" == "${path_to_sysroot}"* ]]; then
                    # if the file is in the sysroot itself ignore it as will get deleted
                    :
                else
                    # this is one of our local dir lib pointing at the sysroot - NOT OK
                    echo -e "Match case Linux_02"
                    echo_lib_ref "${file}" "${lib}"
                    exit_code=1
                    bad_refs=1
                fi
                ;;
            *)
                # any extra "forbidden" prefixes
                for p in "${forbidden_paths[@]}"; do
                    if [[ "${lib}" == "${p}"* ]]; then
                        echo -e "Match case Linux_03"
                        echo_lib_ref "${file}" "${lib}"
                        exit_code=1
                        bad_refs=1
                    fi
                done
                if [[ -z "${lib}" ]]; then
                    # response has not been set here above so it's ''
                    continue
                fi
                if [[ "${lib}" == '=>' ]]; then
                    # sometimes `ldd … | awk '/=>/ {print $3}'` will emit a bare "=>"
                    # when there's no third field, so skip it
                    continue
                fi
                if [[ "${file}" == "${path_to_sysroot}"* ]]; then
                    # if the file is in the sysroot ignore it as will get deleted
                    continue
                fi
                if [[ "${file}" == *".a" ]]; then
                    # static library – OK
                    continue
                fi
                # Not sure what this is so let's log it
                echo -e "Match case Linux_04"
                echo_lib_ref "${file}" "${lib}"
                exit_code=1
                bad_refs=1
                ;;
            esac
        done < <(printf '%s\n' "${response}")
    done < <(
        find "${path_to_python_home}" \
            \( -path "${path_to_python_home}/sysroot" -prune \) -o \
            \( \( -type f -o -type l \) \( -perm -111 \) \
            -print0 \
            \)
    )

    if [[ "${bad_refs}" -eq 1 ]]; then
        echo_error "Bad loadable references found in ELF objects."
    fi
}

function check_loadable_refs() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking loadable Mach-O / ELF object${end}"

    if [[ $(uname -s) == "Darwin" ]]; then
        check_loadable_refs_macos
    elif [[ $(uname -s) == "Linux" ]]; then
        case "$(linux_pkg_family)" in
        apt)
            check_loadable_refs_debian
            ;;
        yum)
            check_loadable_refs_linux
            ;;
        *)
            echo_error "Unsupported Linux package manager: neither apt-get nor yum found."
            exit_code=1
            ;;
        esac
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    echo -e "done!"
    echo
}

function check_python_sysconfig() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking Python build flags${end}"

    local pybin="${path_to_python_home}/bin/python3"

    NEEDLE="${path_to_sysroot}" "$pybin" - <<'PY' || py_sysconfig_failed=1
import os, sys, sysconfig

needle = os.environ['NEEDLE']

# Patterns that should not persist in a *final* Python toolchain
needles = [needle, '--sysroot', '-isysroot', '-Wl,-syslibroot,']

bad = []
for k, v in (sysconfig.get_config_vars() or {}).items():
    if isinstance(v, str) and any(n in v for n in needles):
        bad.append((k, v))

if bad:
    for k, v in bad:
        print(f"[LEAK] {k} = {v}")
    sys.exit(1)

print("OK: no leaked sysroot/-isysroot/-syslibroot in Python build vars")
PY

    if [[ "${py_sysconfig_failed}" -eq 1 ]]; then
        echo_error "Python build flags test failed."
        exit_code=1
    fi

    echo -e "done!"
    echo
}

function check_hardcoded_paths() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking for hardcoded paths${end}"

    local file keyword
    local hardcoded_paths_found=0
    local -a keywords=(
        "build_runtime"
        "build-runtime"
        "python_builds"
        "build-workspace"
        "pkgbuild-workspace"
        "carlogtt"
        "carlo"
        "ec2-user"
        "admin"
        "debian"
        "/Users/carlogtt"
        "/home/carlogtt"
        "/Users/carlo"
        "/home/carlo"
        "/Users/ec2-user"
        "/home/ec2-user"
        "/home/admin"
        "/home/debian"
    )

    while IFS= read -r -d '' file; do
        if [[ ! -r "${file}" ]]; then
            continue
        fi

        for keyword in "${keywords[@]}"; do
            if LC_ALL=C grep --text -F --quiet -- "${keyword}" "${file}" 2>/dev/null; then
                echo -e "'${file}' contains hardcoded keyword '${keyword}'"
                hardcoded_paths_found=1
                exit_code=1
                break
            fi
        done
    done < <(
        find "${path_to_python_home}" \
            \( -path "${path_to_python_home}/local" -o -path "${path_to_python_home}/lib" \) -prune -o \
            \( -type f -o -type l \) \
            ! -path "${path_to_python_home}/bin/python3" \
            ! -path "${path_to_python_home}/bin/python3.7m" \
            ! -path "${path_to_python_home}/bin/python${python_version}" \
            ! -path "${path_to_python_home}/bin/python3-config" \
            ! -path "${path_to_python_home}/bin/python3.7m-config" \
            ! -path "${path_to_python_home}/bin/python${python_version}-config" \
            -print0
    )

    if [[ "${hardcoded_paths_found}" -eq 1 ]]; then
        echo_error "Hardcoded paths found in '${path_to_python_home}'."
    fi

    echo -e "done!"
    echo
}

function check_broken_links() {
    echo_time
    echo -e "${bold_green}${sparkles} Checking for broken links${end}"

    local file broken_links

    # Process substitution, not a pipe: a `find … | while` pipeline runs the
    # loop body in a subshell, which would discard both exit_code and
    # broken_links and make this check silently always pass.
    while IFS= read -r -d '' file; do
        if [[ ! -e "${file}" ]]; then
            echo -e "'${file}' is broken"
            exit_code=1
            broken_links=1
        fi
    done < <(find "${path_to_python_home}" -type l -print0)

    if [[ "${broken_links}" -eq 1 ]]; then
        echo_error "Broken links found."
    fi

    echo -e "done!"
    echo
}

function fix_shebang() {
    echo_time
    echo -e "${bold_green}${sparkles} Fixing shebang #!...${end}"

    local filepath first_line

    cp "${path_to_python_home}/bin/pip3" "${path_to_python_home}/bin/pip" || {
        echo_error "Failed to copy 'pip3'."
        exit_code=1
    }

    while IFS= read -r -d '' filepath; do
        if [[ ! -e "${filepath}" ]]; then
            continue
        fi
        if ! grep -Iq . "${filepath}" 2>/dev/null; then
            continue
        fi

        IFS= read -r first_line <"${filepath}" || {
            echo_warning "Failed to read ${filepath}."
            continue
        }

        if [[ "${first_line}" != "#!/"* ]]; then
            continue
        fi
        if [[ "${first_line}" != *"python3"* ]]; then
            continue
        fi

        tmp="${filepath}.shim"
        shebang="#!/${cli_name}/bin/envroot \"\$ENVROOT/bin/python${python_version}\""

        echo -e "Fixing ${filepath} \n--| from: $(head -n 1 "${filepath}") \n--| to: ${shebang}"

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
    done < <(find "${path_to_python_home}" -type f -print0)

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
    echo -e "${bold_green}${sparkles} Setting ownership for '${python_version_build_root}'${end}"

    local u g

    u="${SUDO_USER}"
    g="$(groups "${u}" | awk '{print $1}')"

    sudo chown -R "${u}":"${g}" "${python_version_build_root}" || {
        echo_error "Failed to set ownership for '${python_version_build_root}'."
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
        --latest=true \
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

function echo_response() {
    local response col

    if [[ "${exit_code}" -eq 0 ]]; then
        col="${bold_green}"
    else
        col="${bold_red}"
    fi

    response="${python_pkg_name} -> ${col}Completed with exit code: ${exit_code}${end}\n"

    # This must be the last line of the log file
    printf '%s' "${response}"
}

function echo_final_response() {
    echo_time
    echo -e "${bold_green}${sparkles} Final response${end}"
    echo -e "${final_response}"
    echo
}

function read_build_versions() {
    declare -g -r verv=(
        # PYTHON 3.15
        # "3.15.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # PYTHON 3.14
        # "3.14.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # "3.14.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1:1.5.7"
        # PYTHON 3.13
        # "3.13.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.13.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # PYTHON 3.12
        # "3.12.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.12.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.12.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.12.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.12.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # PYTHON 3.11
        # "3.11.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.11.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.11.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.11.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.11.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.11.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.11.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # PYTHON 3.10
        # "3.10.20:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.19:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.18:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.17:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.16:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.10.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.10.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # PYTHON 3.9
        # "3.9.25:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.24:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.23:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.22:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.21:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.20:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.19:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.18:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.17:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.16:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.9.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.9.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # PYTHON 3.8
        # "3.8.20:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.19:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.18:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.17:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.16:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.15:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.14:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.13:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.12:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.11:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.8.10:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.9:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.8:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.7:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.6:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.5:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.4:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.3:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.2:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.1:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.8.0:3.5.0:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # PYTHON 3.7
        # "3.7.17:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.16:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.15:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.14:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.13:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.12:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.11:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        # "3.7.10:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.9:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.8:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.7:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.6:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.5:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.4:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.3:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.2:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.1:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
        #  "3.7.0:1.1.1w:8.6.16:5.8.1:1.24:3.49.2:3490200:8.2:6.5:3.4.8:2.0.1"
    )
}

function build_version() {
    local version_string clean_after

    version_string="${1}"
    shift # Removes $1

    validate_prerequisites

    set_constants "${@}"

    local title="Building Python ${python_full_version} runtime"
    echo -e "\n${bold_black}${bg_white}${left_pad} ${title} ${right_pad}${end}\n"

    clean_workspace_shallow
    prepare_workspace
    prepare_sysroot
    prepare_local

    build_python_runtime
    if [[ $(uname -s) == "Darwin" ]]; then
        if [[ ! "${python_full_version}" =~ ^3\.(10|9|8)\. ]]; then
            check_python_build_logs
        fi
    elif [[ $(uname -s) == "Linux" ]]; then
        if [[ ! "${python_full_version}" =~ ^3\.7\. ]]; then
            check_python_build_logs
        fi
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi

    set_ownership
    fix_runtime_paths
    check_loadable_refs
    check_python_sysconfig

    # Optimize space while cleaning the python build and remove additional dirs
    optimize_space=true
    clean_build

    fix_shebang

    check_broken_links
    check_hardcoded_paths
    check_python_runtime

    make_tar

    # Optimize space deleting the whole python home after making the tar
    clean_after=false
    if [[ "${clean_after}" == true ]]; then
        clean_workspace_deep
    fi

    if [[ "${exit_code}" -eq 0 ]]; then
        push_gh_release
    fi

    echo_response
}

function main() {
    local max_parallel spinner pids

    # Due to TK build this needs to run as 1 on macos
    # On linux hosts can be upped to 100
    if [[ $(uname -s) == "Darwin" ]]; then
        max_parallel=1
    elif [[ $(uname -s) == "Linux" ]]; then
        max_parallel=10
    else
        echo_error "Unsupported platform: $(uname -s)"
        exit_code=1
    fi
    spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    read_build_versions
    validate_prerequisites

    echo
    echo_time
    echo -e "${bold_green}${sparkles} Launching build jobs${end}"
    pids="sudo kill -9 "
    for version_string in "${verv[@]}"; do
        set_constants "${@}"
        rm -rf "${python_version_build_root:?}"
        sleep 2
        mkdir -p "${path_to_log_root}"
        build_version "${version_string}" "${@}" >"${path_to_log_build_master_file}" 2>&1 &
        pids+="${!} "
        echo -e "${pids}" >"${python_build_root}/emergency-cmd"
        echo -e "\rBuilding Python ${python_full_version}, follow the log on: ${path_to_log_build_master_file}"
        sleep 1
        # Wait if we hit the max num of concurrent job we can run
        while [[ "$(jobs -r | wc -l)" -ge "${max_parallel}" ]]; do
            for ((i = 0; i < ${#spinner}; i++)); do
                printf "\rWaiting for builds to complete... %s" "${bold_white}${spinner:$i:1}${end}"
                sleep 0.1
            done
        done
    done
    # Wait for all background jobs to complete
    rm -rf "${python_build_root}/debug.log" || :
    while [[ "$(jobs -r | wc -l)" -gt 0 ]]; do
        {
            echo -e '\n\n\n'
            echo_time
            echo -e '============================================================='
            echo -e 'DEBUG LOG'
            echo -e '============================================================='
            echo -e 'whoami'
            whoami
            echo -e '============================================================='
            echo -e 'free -th'
            free -th
            echo -e '============================================================='
            echo -e 'df -h'
            df -h
            echo -e '============================================================='
            echo -e 'df -ih'
            df -ih
            echo -e '============================================================='
            echo -e 'sudo ps -ef | grep build_runtime'
            ps -ef | grep [b]uild_runtime
            echo -e '============================================================='
            echo -e 'jobs'
            jobs
            echo -e '============================================================='
            echo -e 'jobs | wc -l'
            jobs | wc -l
            echo -e '============================================================='
        } >>"${python_build_root}/debug.log"
        for ((i = 0; i < ${#spinner}; i++)); do
            printf "\rWaiting for builds to complete... %s" "${bold_white}${spinner:$i:1}${end}"
            sleep 0.1
        done
    done
    echo
    echo -e "done!"
    echo

    # Redundant as the while loop above is guaranteed to finish
    # before the next line is executed but precocious
    wait

    # Collect all responses
    final_response=""
    for version_string in "${verv[@]}"; do
        set_constants "${@}"
        final_response+="$(tail -n 1 "${path_to_log_build_master_file}")"
    done

    echo_final_response

    return "${exit_code}"
}

main "${@}"
