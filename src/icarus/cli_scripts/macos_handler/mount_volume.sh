#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/macos_handler/mount_volume.sh
# Created 1/20/25 - 10:46 PM UK Time (London) by carlogtt

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

# User defined variables
macos_mount_volume() {
    # Mounts the specified volume at the specified mount point. The script will
    # first attempt to lock the volume to ensure it's operating on a locked volume.
    # Diskutil considering unlocking an already unlocked volume an error.
    #
    # This script is particularly useful when executed from a launchd script stored
    # in /Library/LaunchDaemons at startup. By default, macOS mounts all volumes in
    # /Volumes at startup. If you want to have them mounted elsewhere like I do
    # (e.g., in your home dir), you have to execute this script at startup as root
    # to remount them where you want them.
    #
    # You can use install-apfs-launch-daemon to install the daemon mentioned above.

    if [[ $(id -u) -ne 0 ]]; then
        echo -e "This script must run as root to be able to mount the volume in the home directory."
        exit 1
    fi

    local volume_name="$1"
    if [[ -z ${volume_name} ]]; then
        echo -e "Volume name is empty"
        exit 1
    fi

    local mount_point="$2"
    if [[ -z ${mount_point} ]]; then
        echo -e "Mount point is empty"
        exit 1
    fi

    if [[ ! -d ${mount_point} ]]; then
        echo -e "Mount point ${mount_point} is not a directory"
        exit 1
    fi

    local vol_info_file="/tmp/${volume_name}.plist"

    echo -e "Retrieving diskutil info for ${volume_name}"
    /usr/sbin/diskutil info -plist "${volume_name}" >"${vol_info_file}" || {
        echo -e "Unknown volume: \"${volume_name}\". Exiting."
        exit 1
    }
    local vol_uuid="$(/usr/libexec/PlistBuddy -c 'Print VolumeUUID' "${vol_info_file}")"

    echo -e "Retrieving passphrase for ${vol_uuid}"
    local volume_passphrase="$(/usr/bin/security find-generic-password -w -l "${volume_name}" -a "${vol_uuid}" -D 'Encrypted Volume Password')"

    # Try to lock the volume first to make sure we're unlocking a locked volume.
    /usr/sbin/diskutil apfs lockVolume "${volume_name}" || true

    echo -e "Unlocking volume ${vol_uuid}"
    /usr/sbin/diskutil apfs unlockVolume "${volume_name}" -stdinpassphrase -mountPoint "${mount_point}" <<<"${volume_passphrase}"

    echo -e "Volume ${volume_name} (UUID: ${vol_uuid}) was successfully mounted at ${mount_point}"
}

macos_mount_volume "$@"
