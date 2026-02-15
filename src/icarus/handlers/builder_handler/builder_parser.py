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

# Local Application Imports
from icarus import config, utils
from icarus.handlers.builder_handler import builder_helper, create_helper

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'handle_builder_command',
]

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

    base_args: dict[str, Union[int]] = {
        'verbose': args.verbose,
    }
    builder_only_args: dict[str, Union[str, list[str]]] = {
        'build': getattr(args, 'build', ''),
        'release': getattr(args, 'release', ''),
        'format': getattr(args, 'format', ''),
        'docs': getattr(args, 'docs', ''),
        'test': getattr(args, 'test', ''),
        'clean': getattr(args, 'clean', ''),
        'isort': getattr(args, 'isort', ''),
        'black': getattr(args, 'black', ''),
        'flake8': getattr(args, 'flake8', ''),
        'mypy': getattr(args, 'mypy', ''),
        'shfmt': getattr(args, 'shfmt', ''),
        'eolnorm': getattr(args, 'eolnorm', ''),
        'whitespaces': getattr(args, 'whitespaces', ''),
        'trailing': getattr(args, 'trailing', ''),
        'eofnewline': getattr(args, 'eofnewline', ''),
        'gitleaks': getattr(args, 'gitleaks', ''),
        'pytest': getattr(args, 'pytest', ''),
        'sphinx': getattr(args, 'sphinx', ''),
        'readthedocs': getattr(args, 'readthedocs', ''),
        'merge': getattr(args, 'merge', ''),
        'exectool': getattr(args, 'exec-tool', '') or getattr(args, 'exec_tool', ''),
        'execrun': getattr(args, 'exec-run', '') or getattr(args, 'exec_run', ''),
        'execdev': getattr(args, 'exec-dev', '') or getattr(args, 'exec_dev', ''),
    }
    singleton_args = {
        'path',
        'create',
        'build-runtime',
    }

    if args.builder_command in singleton_args and any(builder_only_args.values()):
        raise utils.IcarusParserException("too many arguments")

    if args.builder_command == 'create':
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'create.sh'
        script_args = create_helper.get_argv(package_name=args.n, package_language=args.l)

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.builder_command == 'build-runtime':
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'build_runtime.sh'
        script_args = [utils.platform_id()]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.builder_command == 'path':
        module_logger.debug(f"Running {args.builder_command=}")

        builder_path_only_args: dict[str, Union[str, list[str]]] = {
            'path_name': args.path_name,
            'list_paths': args.list,
        }

        if sum(1 for a in builder_path_only_args.values() if a) > 1:
            raise utils.IcarusParserException("too many arguments")

        if not any(builder_path_only_args.values()):
            raise utils.IcarusParserException('the following arguments are required: <subcommand>')

        builder_path_args = {**base_args, **builder_only_args, **builder_path_only_args}

        builder_helper.ensure_builder_control_plane()
        builder_lock = builder_helper.acquire_builder_lock()

        try:
            script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'builder_path.sh'
            script_args = [builder_helper.get_argv(ib_args=builder_path_args)]

            return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)
        finally:
            builder_helper.release_builder_lock(builder_lock)

        return return_code

    elif args.builder_command not in singleton_args:
        module_logger.debug(f"Running {args.builder_command=}")

        total_builder_only_args = sum(1 for el in builder_only_args.values() if el)

        if builder_only_args.get('clean') and total_builder_only_args > 1:
            raise utils.IcarusParserException(
                '--clean is a standalone argument and must be used alone'
            )

        if builder_only_args.get('merge') and total_builder_only_args > 1:
            raise utils.IcarusParserException(
                '--merge is a standalone argument and must be used alone'
            )

        if builder_only_args.get('exectool') and total_builder_only_args > 1:
            raise utils.IcarusParserException(
                '--exec-tool is a standalone argument and must be used alone'
            )

        if builder_only_args.get('execrun') and total_builder_only_args > 1:
            raise utils.IcarusParserException(
                '--exec-run is a standalone argument and must be used alone'
            )

        if builder_only_args.get('execdev') and total_builder_only_args > 1:
            raise utils.IcarusParserException(
                '--exec-dev is a standalone argument and must be used alone'
            )

        if not any(builder_only_args.values()):
            raise utils.IcarusParserException('the following arguments are required: <subcommand>')

        builder_args = {**base_args, **builder_only_args}

        builder_helper.ensure_builder_control_plane()
        builder_lock = builder_helper.acquire_builder_lock()

        try:
            script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'builder.sh'
            script_args = [builder_helper.get_argv(ib_args=builder_args)]

            return_code = builder_helper.run_bash_script_with_logging(
                script_path=script_path, script_args=script_args
            )
        finally:
            builder_helper.release_builder_lock(builder_lock)

        return return_code

    else:
        module_logger.debug(f"Running {args.builder_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')
