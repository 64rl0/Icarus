# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/unison_handler/unison_parser.py
# Created 1/19/25 - 4:05 PM UK Time (London) by carlogtt
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
import argparse

# Local Folder (Relative) Imports
from ... import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['handle_unison_command']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_unison_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'unison' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `unison_command` argument.

    :param args: The parsed arguments containing the `unison_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `unison_command` is provided.
    """

    if args.unison_command == 'status':
        module_logger.debug(f"Running {args.unison_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'unison_handler' / 'status.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.unison_command == 'restart':
        module_logger.debug(f"Running {args.unison_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'unison_handler' / 'restart.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.unison_command == 'stop':
        module_logger.debug(f"Running {args.unison_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'unison_handler' / 'stop.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.unison_command == 'clear-locks':
        module_logger.debug(f"Running {args.unison_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'unison_handler' / 'clear_locks.sh'
        script_args = [args.i]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.unison_command == 'start-at-startup':
        module_logger.debug(f"Running {args.unison_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'unison_handler' / 'start_at_startup.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.unison_command == 'run-profiles':
        module_logger.debug(f"Running {args.unison_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'unison_handler' / 'run_profiles.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    else:
        module_logger.debug(f"Running {args.unison_command=}")
        raise ValueError('the following arguments are required: <subcommand>')
