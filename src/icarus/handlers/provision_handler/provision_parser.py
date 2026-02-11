# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/provision_handler/provision_parser.py
# Created 5/25/25 - 8:35 PM UK Time (London) by carlogtt

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

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'handle_provision_command',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_provision_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'provision' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `provision_command` argument.

    :param args: The parsed arguments containing the `provision_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `provision_command` is provided.
    """

    if args.provision_command == 'dotfiles-update':
        module_logger.debug(f"Running {args.provision_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'provision_handler' / 'dotfiles_update.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.provision_command == 'envroot':
        module_logger.debug(f"Running {args.provision_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'provision_handler' / 'envroot.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    else:
        module_logger.debug(f"Running {args.provision_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')
