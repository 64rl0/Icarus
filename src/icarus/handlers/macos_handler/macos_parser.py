# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/macos_handler/macos_parser.py
# Created 1/19/25 - 4:03 PM UK Time (London) by carlogtt

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
    'handle_macos_command',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_macos_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'macos' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `macos_command` argument.

    :param args: The parsed arguments containing the `macos_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `macos_command` is provided.
    """

    if args.macos_command == 'find-unencrypted-volumes':
        module_logger.debug(f"Running {args.macos_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'macos_handler' / 'find_unencrypted_volumes.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.macos_command == 'make-encrypted-volume':
        module_logger.debug(f"Running {args.macos_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'macos_handler' / 'make_encrypted_volume.sh'
        script_args = [args.n, args.q]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.macos_command == 'encrypt-volume':
        module_logger.debug(f"Running {args.macos_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'macos_handler' / 'encrypt_volume.sh'
        script_args = [args.n]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.macos_command == 'mount-volume':
        module_logger.debug(f"Running {args.macos_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'macos_handler' / 'mount_volume.sh'
        script_args = [args.n, args.p]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.macos_command == 'mount-at-startup':
        module_logger.debug(f"Running {args.macos_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'macos_handler' / 'mount_at_startup.sh'
        script_args = [args.n, args.p]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.macos_command == 'icarus-update-daemon':
        module_logger.debug(f"Running {args.macos_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'macos_handler' / 'update_icarus_daemon.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    else:
        module_logger.debug(f"Running {args.macos_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')
