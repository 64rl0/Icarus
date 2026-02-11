#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/macos_handler/mount_at_startup.sh
# Created 1/20/25 - 10:47 PM UK Time (London) by carlogtt

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
macos_install_mount_volume_launchd() {
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

    # Now we need to ensure we have a normalized path. The easiest way I found to
    # do this is with a bit of Python. We use an ancient version (2.7) because
    # macOS ships with it.
    local mount_point="$(python3 -c "import os.path; import sys; print(os.path.abspath(sys.argv[1]))" "$2")"

    local mount_script_path="${this_cli_fullpath} macos mount-volume"

    echo -e "Volume name set to: ${volume_name}"
    echo -e "Mount point set to: ${mount_point}"
    echo -e "Full command to add to launchd daemon set to: ${mount_script_path} -n ${volume_name} -p ${mount_point}\n"

    local vol_info_file="${tmp_root_sudo}/macos/${volume_name}.plist"

    echo -e "Retrieving diskutil info for ${volume_name}"
    /usr/sbin/diskutil info -plist "${volume_name}" >"${vol_info_file}" || {
        echo -e "Unknown volume: \"${volume_name}\". Exiting."
        exit 1
    }
    local vol_uuid="$(/usr/libexec/PlistBuddy -c 'Print VolumeUUID' "${vol_info_file}")"

    local launchd_daemon_path="/Library/LaunchDaemons/mount.${volume_name}.plist"
    echo -e "Writing launchd daemon configuration"

    cat <<EOF | sudo tee "${launchd_daemon_path}" >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>mount.${volume_name}</string>
        <key>ProgramArguments</key>
        <array>
            <string>${this_cli_fullpath}</string>
            <string>-v</string>
            <string>macos</string>
            <string>mount-volume</string>
            <string>-n</string>
            <string>${volume_name}</string>
            <string>-p</string>
            <string>${mount_point}</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <!-- Logging std out/err is useful for debugging. -->
        <!--
        <key>StandardOutPath</key>
        <string>${tmp_root_sudo}/log/mount-volume-${volume_name}-stdout.log</string>
        <key>StandardErrorPath</key>
        <string>${tmp_root_sudo}/log/mount-volume-${volume_name}-stderr.log</string>
        -->
    </dict>
</plist>
EOF

    echo -e "launchd daemon configuration was successfully written to"
    echo -e "${launchd_daemon_path}\n"

    launchctl unload "${launchd_daemon_path}"
    sleep 1
    launchctl load "${launchd_daemon_path}"
    echo -e "Configuration loaded\n"

    sleep 3 # Sleep a little bit to make sure the script had enough time to mount the volume

    echo -e "Retrieving diskutil info for ${volume_name}"
    /usr/sbin/diskutil info -plist "${volume_name}" >"${vol_info_file}" || {
        echo -e "Unknown volume: \"${volume_name}\". Exiting."
        exit 1
    }
    local vol_new_mount_point="$(/usr/libexec/PlistBuddy -c 'Print MountPoint' "${vol_info_file}")"
    echo -e "Volume is now mounted at ${vol_new_mount_point}"

    if [[ "${vol_new_mount_point}" != "${mount_point}" ]]; then
        echo -e "ERROR: the new mount point for the volume was expected to be ${mount_point} but it's ${vol_new_mount_point}"
        exit 1
    fi
}

macos_install_mount_volume_launchd "$@"
