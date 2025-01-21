#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/auth_init_exp.sh
# Created 1/20/25 - 10:42 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs
project_root_dir_abs="$(realpath -- "${cli_scripts_dir_abs}/..")"
declare -r project_root_dir_abs
cli_script_base="${cli_scripts_dir_abs}/base.sh"
declare -r cli_script_base

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
auth_init_express() {
    # Check that MWPIN and AMZPSW are exported
    if [[ -z "${MWPIN}" || -z "${AMZPSW}" ]]; then
        echo -e "${red}MWPIN and/or AMZPSW env variable(s) not found! Run the following command to set them.${end}"
        echo -e "${red}export MWPIN=<your midway pin>${end}"
        echo -e "${red}export AMZPSW=<your amazon password>${end}"
        return
    fi

    cat <<EOF >"/tmp/auth-init-expect.exp"
#!/usr/bin/expect
# vim: ft=sh

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

set timeout -1
set mwpin \$env(MWPIN)
set amzpsw \$env(AMZPSW)

# Start the script
log_user 0
spawn \$env(HOME)/.icarus/bin/icarus amazon auth-init $*
log_user 1

# Handle multiple prompt possibilities repeatedly
while {1} {
expect {
    # Case 1 local machine
    "Enter the on-token PIN of your security key:" {
        sleep 1
        send "\$mwpin\r"

        # Expect the intermediate prompt
        expect {
            "Touch the security key" {
                sleep 1
            }
        }

        # Continue
        exp_continue
    }

    # Case 2 over ssh
    "Please enter your Midway PIN:" {
        sleep 1
        send "\$mwpin\r"

        # Expect the intermediate prompt
        expect {
            "Press your security key for 3-5 seconds to generate the one-time password (OTP)" {
                # Disable terminal echo
                stty -echo
                expect_user -re "(.*)\n"
                set yubikey \$expect_out(1,string)
                send "\$yubikey\r"
                # Re-enable terminal echo
                stty echo
            }
        }

        # Continue
        exp_continue
    }

    # Case 3 Kerberos
    "@ANT.AMAZON.COM" {
        sleep 1
        send "\$amzpsw\r"
    }

    # Case 4 exit case
    eof {
        exit
    }
}
}
EOF

    # Run the expect script as file to maintain interactivity
    expect "/tmp/auth-init-expect.exp"
}

auth_init_express "$@"
