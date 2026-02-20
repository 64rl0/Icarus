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

# Local Application Imports
from icarus import config, utils
from icarus.handlers.builder_handler import builder_helper, create_helper, update_version_helper
from icarus.handlers.builder_handler.model import IcarusBuilderOperation

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

    ib_cli = builder_helper.parse_icarus_builder_cli_arg(args)

    if ib_cli.operation is IcarusBuilderOperation.BUILD_RUNTIME:
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'build_runtime.sh'
        script_args = [utils.platform_id()]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif ib_cli.operation is IcarusBuilderOperation.CREATE:
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'create.sh'
        script_args = create_helper.get_argv(package_name=args.n, package_language=args.l)

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif ib_cli.operation is IcarusBuilderOperation.CACHE:
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'cache.sh'
        script_args = [builder_helper.get_ib_argv(ib_cli.args)]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif ib_cli.operation is IcarusBuilderOperation.PATH:
        module_logger.debug(f"Running {args.builder_command=}")

        builder_helper.ensure_builder_control_plane()
        builder_lock = builder_helper.acquire_builder_lock()

        try:
            script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'path.sh'
            script_args = [builder_helper.get_ib_argv(ib_cli.args)]

            return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)
        finally:
            builder_helper.release_builder_lock(builder_lock)

        return return_code

    elif ib_cli.operation is IcarusBuilderOperation.BUMPVER:
        module_logger.debug(f"Running {args.builder_command=}")

        builder_helper.ensure_builder_control_plane()
        builder_lock = builder_helper.acquire_builder_lock()

        try:
            ib_arg = builder_helper.get_ib_arg(ib_cli.args)

            return_code = update_version_helper.update_version_file(ib_arg)
        finally:
            builder_helper.release_builder_lock(builder_lock)

        return return_code

    elif ib_cli.operation is IcarusBuilderOperation.BUILDER:
        module_logger.debug(f"Running {args.builder_command=}")

        builder_helper.ensure_builder_control_plane()
        builder_lock = builder_helper.acquire_builder_lock()

        try:
            script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'builder.sh'
            script_args = [builder_helper.get_ib_argv(ib_cli.args)]

            return_code = builder_helper.run_bash_script_with_logging(
                script_path=script_path, script_args=script_args
            )
        finally:
            builder_helper.release_builder_lock(builder_lock)

        return return_code

    else:
        module_logger.debug(f"Running {args.builder_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')
