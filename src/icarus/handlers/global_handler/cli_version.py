# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/global_handler/cli_version.py
# Created 1/23/25 - 3:26 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

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
import os
import subprocess
import sys

# Local Folder (Relative) Imports
from ... import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['cli_version']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


@utils.capture_exit_code
def cli_version() -> None:
    """
    Display the version of the CLI.

    :return: The CLI version.
    """

    icarus_version = config.CLI_VERSION
    icarus_build = subprocess.run(
        ['git', 'describe', '--always'],
        cwd=os.path.expanduser("~/.icarus"),
        check=True,
        text=True,
        capture_output=True,
    ).stdout.replace('\n', '')
    python_version = sys.version

    version = (
        f'icarus-cli: {icarus_version}\nicarus-hash: {icarus_build}\npython:'
        f' {python_version}\nplatform: {utils.platform_id()}'
    )

    print(version, flush=True)
