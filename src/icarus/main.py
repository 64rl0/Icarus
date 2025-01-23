# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/main.py
# Created 1/18/25 - 5:46 PM UK Time (London) by carlogtt
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
import sys

# Local Folder (Relative) Imports
from . import cli, config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['main']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def main() -> int:
    """
    The main entry point of the application.

    :return: Exit code of the script.
    """

    # Initialize parser and parse args
    parser = cli.initialize_parser()

    # Parse cli args
    args = cli.parse_args(parser=parser)

    # Set CLI logging level
    utils.set_logger_level(args.verbose)

    # Log parsed args
    module_logger.debug(f"Arguments parsed:{args=}")

    # Execute the command
    try:
        return_cose = cli.execute(args=args)
        return return_cose

    except utils.IcarusParserException as ex:
        module_logger.debug(repr(ex))
        parser.error(str(ex))

    except Exception as ex:
        module_logger.debug(f"unexpected error: {repr(ex)}")
        sys.exit(1)
