#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/macos_handler/encrypt_volume.sh
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
macos_encrypt_volume() {
    # This script encrypts an existing APFS volume with a very long randomly
    # generated passphrase and stores the passphrase in the System keychain so that
    # the volume can be automatically mounted at startup.

    echo -e "We need to briefly run as root (through sudo) to execute some commands."
    echo -e "If prompted, please enter your user password."
    sudo -v

    local volume_name="$1"
    if [[ -z $volume_name ]]; then
        echo "Please provide a volume name."
        exit 1
    fi

    local volume_passphrase="$(dd if=/dev/urandom bs=64 count=1 2>/dev/null | base64 | tr -d '\n')"
    echo -e "Your volume passphrase is: ${volume_passphrase}"

    local vol_info_file="${tmp_root_sudo}/macos/${volume_name}.plist"
    /usr/sbin/diskutil info -plist "${volume_name}" >"${vol_info_file}" || {
        echo "Wrong volume: \"${volume_name}\". Exiting."
        exit 1
    }
    local vol_uuid="$(/usr/libexec/PlistBuddy -c 'Print VolumeUUID' "${vol_info_file}")"
    rm "${vol_info_file}"

    /usr/sbin/diskutil apfs encryptVolume "${vol_uuid}" -user disk -stdinpassphrase <<<"${volume_passphrase}" || {
        echo -e "ERROR: Volume encryption failed!"
        echo -e "Volume ${volume_name} (UUID: ${vol_uuid}) might already be encrypted (in that case, it still has the old password, not the one shown above) or something else happened."
        echo -e "See diskutil error message above."
        exit 1
    }

    # Now we need to store volume passphrase in the System keychain.
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
    echo -e "Volume ${volume_name} (UUID ${vol_uuid}) is now being encrypted in the background by an independent macOS system daemon."
    echo -e "You can safely close this shell if you want."
    echo -e "You can verify your volume has been encrypted in Disk Utility app or executing \"diskutil apfs list\" in your shell."
}

macos_encrypt_volume "$@"
