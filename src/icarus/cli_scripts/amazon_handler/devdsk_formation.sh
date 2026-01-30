#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/devdsk_formation.sh
# Created 1/20/25 - 11:23 AM UK Time (London) by carlogtt

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
devdsk_formation() {
    local filepath='/Users/carlogtt/Dropbox/SDE/Shell/CarloCodes/DevDskFormation/devdsk_formation.sh'
    local hostname="devdsk$1"

    echo -e "Transferring devdsk_formation to ${hostname}..."
    scp "${filepath}" "${hostname}":/home/carlogtt/ || exit 1
    echo -e "Transfer completed!\n"

    echo -e "Running devdsk_formation on ${hostname}...\n"
    ssh -t "${hostname}" "./devdsk_formation.sh;"
}

devdsk_formation "$@"
