# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/amazon_handler/amazon_parser.py
# Created 1/19/25 - 11:14 AM UK Time (London) by carlogtt
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
from . import update_hosts

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['handle_amazon_command']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_amazon_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'amazon' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `amazon_command` argument.

    :param args: The parsed arguments containing the `amazon_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `amazon_command` is provided.
    """

    if args.amazon_command == 'auth-init':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'auth_init.sh'
        script_args = [' '.join(args.i), ' '.join(args.mw_args)]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.amazon_command == 'auth-init-exp':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'auth_init_exp.sh'
        script_args = [' '.join(args.i), ' '.join(args.mw_args)]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.amazon_command == 'midway-cookie':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'midway_cookie.sh'
        script_args = [args.filepath]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.amazon_command == 'devdsk-formation':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'devdsk_formation.sh'
        script_args = [args.i]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.amazon_command == 'update-hosts':
        module_logger.debug(f"Running {args.amazon_command=}")

        return_code = update_hosts.update_hots()

        return return_code

    elif args.amazon_command == 'update-hosts-d':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'update_hosts_d.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.amazon_command == 'brazil-setup':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'brazil_setup.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.amazon_command == 'spurdog-ro':
        module_logger.debug(f"Running {args.amazon_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'amazon_handler' / 'spurdog_ro.sh'
        script_args = [args.u, args.auth]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    else:
        module_logger.debug(f"Running {args.amazon_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')
