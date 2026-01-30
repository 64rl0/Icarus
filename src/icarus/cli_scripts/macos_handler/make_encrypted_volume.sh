#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/macos_handler/make_encrypted_volume.sh
# Created 1/20/25 - 10:45 PM UK Time (London) by carlogtt

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
macos_make_encrypted_volume() {
    # This script makes it easy to create an encrypted APFS volume. It generates a
    # secure passphrase, creates the volume, and stores the passphrase in the
    # system keychain so that the volume can be automatically decrypted and mounted
    # on boot. We intentionally do not store the volume password in the user's
    # keychain because that keychain may get deleted by password rotation.
    # Spotlight indexing is disabled on the volumes by default to avoid CPU time contention
    # during package caching or checkout.

    echo -e "We need to briefly run as root (through sudo) to execute some commands."
    echo -e "If prompted, please enter your user password."
    sudo -v

    local volume_name="$1"
    if [[ -z $volume_name ]]; then
        echo "Please provide a volume name."
        exit 1
    fi

    local vol_quota=""
    if [[ -n "$2" ]]; then
        echo -e "Quota for volume ${volume_name} will be: $2\n"
        vol_quota="$2"
    fi

    local disk_name=disk1
    if [[ $(arch) == 'arm64' ]]; then
        disk_name=disk3
    fi

    local volume_passphrase="$(dd if=/dev/urandom bs=64 count=1 2>/dev/null | base64 | tr -d '\n')"
    /usr/sbin/diskutil apfs addVolume "${disk_name}" 'Case-sensitive APFS' "${volume_name}" -stdinpassphrase "${vol_quota}" <<<"${volume_passphrase}"
    echo -e "Your volume password is: ${volume_passphrase}\n"

    local vol_info_file="/${tmp_root_sudo}/macos/${volume_name}.plist"
    /usr/sbin/diskutil info -plist "${volume_name}" >"${vol_info_file}" || {
        echo "Wrong volume: \"${volume_name}\". Exiting."
        exit 1
    }
    local vol_uuid="$(/usr/libexec/PlistBuddy -c 'Print VolumeUUID' "${vol_info_file}")"
    local vol_mountPoint="$(/usr/libexec/PlistBuddy -c 'Print MountPoint' "${vol_info_file}")"
    rm "${vol_info_file}"

    # Exclude these volumes from Spotlight indexing to save CPU overhead on large cache updates/git indices
    /usr/bin/mdutil -i off "${vol_mountPoint}"

    local system_keychain_path="$(security list-keychains -d system | head -1 | sed -E 's/[ ]+\"(.*)\"/\1/')"

    # We MUST use the interactive mode of security to add the passphrase. Without
    # it the passphrase would be passed as an argument which is insecure.
    # Also, the passphrase must be stored in the system keychain and not login
    # keychain. Some people choose to delete their login keychains during password
    # rotation.
    sudo /usr/bin/security -i <<EOF
add-generic-password \
-a "${vol_uuid}" \
-s "${vol_uuid}" \
-D "Encrypted Volume Password" \
-l "${volume_name}" \
-U \
-T "/System/Library/CoreServices/APFSUserAgent" \
-T "/System/Library/CoreServices/CSUserAgent" \
-T "/usr/bin/security" \
-w "${volume_passphrase}" \
"${system_keychain_path}"
EOF

    echo -e "Volume passphrase has been stored in the System keychain (${system_keychain_path})."
    echo -e "Password rotation process doesn't delete System keychain but it's not a bad idea to back up the volume passphrase in your password safe."
    echo -e "Encrypted volume ${volume_name} (UUID ${vol_uuid}) was successfully created and mounted in ${vol_mountPoint}."
}

macos_make_encrypted_volume "$@"
