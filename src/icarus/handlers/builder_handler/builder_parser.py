# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/builder_parser.py
# Created 1/19/25 - 3:58 PM UK Time (London) by carlogtt
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
from typing import Union

# Local Folder (Relative) Imports
from ... import config, utils
from . import builder_helper

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['handle_builder_command']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_builder_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'builder' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `builder_command` argument.

    :param args: The parsed arguments containing the `builder_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `builder_command` is provided.
    """

    builder_args: dict[str, Union[str, list[str]]] = {
        'build': args.build,
        'clean': args.clean,
        'isort': args.isort,
        'black': args.black,
        'flake8': args.flake8,
        'mypy': args.mypy,
        'shfmt': args.shfmt,
        'eolnorm': args.eolnorm,
        'whitespaces': args.whitespaces,
        'trailing': args.trailing,
        'eofnewline': args.eofnewline,
        'gitleaks': args.gitleaks,
        'pytest': args.pytest,
        'docs': args.docs,
        'exec': args.exec,
        'release': args.release,
        'format': args.format,
        'test': args.test,
    }
    singleton_args = {
        'create',
        'build-runtime',
    }

    if args.builder_command == 'create' and not any(builder_args.values()):
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'create.sh'
        script_args = [args.n, args.l]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.builder_command == 'build-runtime' and not any(builder_args.values()):
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'build_runtime.sh'
        script_args = [utils.platform_id()]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.builder_command not in singleton_args and any(builder_args.values()):
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'builder.sh'
        script_args = [builder_helper.get_argv(ib_args=builder_args)]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    else:
        module_logger.debug(f"Running {args.builder_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')
