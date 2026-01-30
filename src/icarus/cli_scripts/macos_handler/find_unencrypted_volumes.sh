#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/macos_handler/find_unencrypted_volumes.sh
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
macos_find_unencrypted_volumes() {
    pb() {
        /usr/libexec/PlistBuddy -c "$1" "${vol_list_path}"
    }

    pbe() {
        pb "$1" >/dev/null 2>&1
    }

    check_container() {
        local container_id="$1"
        local vol_id=0

        while true; do
            pbe "Print Containers:${container_id}:Volumes:${vol_id}" || break # break if volume doesn't exist
            local fv_status=$(pb "Print Containers:${container_id}:Volumes:${vol_id}:FileVault")
            local vol_name="$(pb "Print Containers:${container_id}:Volumes:${vol_id}:Name")"
            if [[ ${fv_status} == "false" ]]; then
                if ! [[ "${vol_name}" =~ ^VM|Preboot|Recovery|Update$ ]]; then
                    echo -e "${red}Volume \"${vol_name}\" is not encrypted and should be!${end}"
                    unencrypted_volume_count=$((unencrypted_volume_count + 1))
                else
                    echo -e "${blue}Volume \"${vol_name}\" is not encrypted but that's expected.${end}"
                fi
            else
                echo -e "${green}Volume \"${vol_name}\" is encrypted.${end}"
            fi
            vol_id=$((vol_id + 1))
        done
    }

    local vol_list_path="/${tmp_root}/macos/volumes.plist"
    diskutil apfs list -plist >"${vol_list_path}"

    local unencrypted_volume_count=0
    local container_id=0

    echo -e ""

    while true; do
        check_container ${container_id}
        container_id=$((container_id + 1))
        pbe "Print Containers:${container_id}" || break
    done

    if ((unencrypted_volume_count != 0)); then
        echo -e "\nYou have ${unencrypted_volume_count} unencrypted volume(s)!"
        echo -e "Please see https://w.amazon.com/bin/view/MacImprovement/CaseSensitiveVolume/"
        echo -e "for instructions how to encrypt them."
    else
        echo -e "Congratulations! You do not have any unencrypted volumes this script could detect."
    fi

    rm "${vol_list_path}"
    unset -f pb pbe check_container
}

macos_find_unencrypted_volumes "$@"
