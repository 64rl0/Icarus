# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/global_handler/global_parser.py
# Created 1/23/25 - 12:03 AM UK Time (London) by carlogtt

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
import argparse

# Local Application Imports
from icarus import config, utils
from icarus.handlers.global_handler import cli_version

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'handle_global_command',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_global_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'global' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `global_command` argument.

    :param args: The parsed arguments containing the `global_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `global_command` is provided.
    """

    if args.version == '--version':
        module_logger.debug(f"Running {args.version=}")

        return_code = cli_version.cli_version()

        assert isinstance(return_code, int)

        return return_code

    elif args.update == '--update':
        module_logger.debug(f"Running {args.update=}")

        # Update is done via the bin file so we just print the
        # new version here
        return_code = cli_version.cli_version()

        assert isinstance(return_code, int)

        return return_code

    else:
        module_logger.debug(f"Running {args=}")
        raise utils.IcarusParserException(f"Unknown command from {handle_global_command.__name__}")
