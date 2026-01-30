#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/amazon_handler/auth_init_exp.sh
# Created 1/20/25 - 10:42 PM UK Time (London) by carlogtt

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
auth_init_express() {
    local tmp_file

    if [[ -z "${CARLOGTT_SECRET_MIDWAY_PIN}" || -z "${CARLOGTT_SECRET_AMZ_ANT_PASSWORD}" ]]; then
        echo -e "${red}CARLOGTT_SECRET_MIDWAY_PIN and/or CARLOGTT_SECRET_AMZ_ANT_PASSWORD env variable(s) not found! Run the following command to set them.${end}"
        echo -e "${red}export CARLOGTT_SECRET_MIDWAY_PIN=<your midway pin>${end}"
        echo -e "${red}export CARLOGTT_SECRET_AMZ_ANT_PASSWORD=<your amazon password>${end}"
        return
    fi

    tmp_file="/tmp/${cli_name}/amazon/auth-init-expect.exp"

    cat <<EOF >"${tmp_file}"
#!/usr/bin/expect
# vim: ft=sh

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

set timeout -1
set mwpin \$env(CARLOGTT_SECRET_MIDWAY_PIN)
set amzpsw \$env(CARLOGTT_SECRET_AMZ_ANT_PASSWORD)

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
    expect "${tmp_file}"
}

parse_args() {
    local -a devdsk_ids=($1)
    local -a mw_args=($2)

    # Prefix each element with --mw-args
    local -a mw_args_expanded=()
    for arg in "${mw_args[@]}"; do
        mw_args_expanded+=("--mw-args" "${arg}")
    done

    if [[ -n "${devdsk_ids[*]}" ]]; then
        auth_init_express "-i" "${devdsk_ids[@]}" "${mw_args_expanded[@]}"
    else
        auth_init_express "${devdsk_ids[@]}" "${mw_args_expanded[@]}"
    fi
}

parse_args "$@"
