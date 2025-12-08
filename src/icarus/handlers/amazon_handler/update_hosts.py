# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/amazon_handler/update_hosts.py
# Created 1/21/25 - 8:21 PM UK Time (London) by carlogtt

"""
This module ...
"""

# ======================================================================
# EXCEPTIONS
# This section documents any exceptions made code or quality rules.
# These exceptions may be necessary due to specific coding requirements
# or to bypass false positives.
# ======================================================================
#

# ======================================================================
# IMPORTS
# Importing required libraries and modules for the application.
# ======================================================================

# Standard Library Imports
import datetime
import json
import subprocess

# Third Party Library Imports
import requests

# Local Folder (Relative) Imports
from ... import config

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['update_hots']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def update_hots() -> int:
    """
    Update the /etc/hosts file with the current DNS IP addresses

    :return: Exit code of the function.
    """

    url = "https://dns.google/resolve?name=cpgbackup.logitech.com&type=A"

    response = requests.get(url)
    result_dict = json.loads(response.text)

    all_dns_ips = [el['data'] for el in result_dict['Answer']]

    all_dns_ips_padded = []

    for el in all_dns_ips:
        ip_len = len(el)
        padding = (20 - ip_len) * " "
        new_el = f"{el}{padding}cpgbackup.logitech.com\n"
        all_dns_ips_padded.append(new_el)

    hosts_lines = []
    insert_idx = None

    with open('/etc/hosts', 'r') as f:
        for idx, line in enumerate(f.readlines()):
            if "## updated on" in line:
                line = (
                    "## updated on UTC"
                    f" {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n"
                )
                hosts_lines.append(line)
                continue

            if "cpgbackup.logitech.com" in line:
                if insert_idx is None:
                    insert_idx = idx
            else:
                hosts_lines.append(line)

    hosts_lines[insert_idx:insert_idx] = all_dns_ips_padded
    new_hosts_file = "".join(hosts_lines)

    try:
        print(
            "We need to briefly run as root (through sudo) to execute some commands.\nIf prompted,"
            " please enter your user password.",
            flush=True,
        )
        subprocess.run(["sudo", "-v"])
        print("Thanks! We'll continue in a moment...\n", flush=True)

        result = subprocess.run(
            ["sudo", "tee", "/etc/hosts"], input=new_hosts_file, text=True, check=True
        )

        module_logger.debug(f"Wrote /etc/hosts successfully with exit code: {result.returncode}")

        return result.returncode

    except subprocess.CalledProcessError as ex:
        module_logger.debug(f"Writing /etc/hosts failed with exit code {ex.returncode}: {ex}")

        return ex.returncode

    except Exception as ex:
        module_logger.debug(f"Exception occurred while writing /etc/hosts | exception: {repr(ex)}")

        return 1
