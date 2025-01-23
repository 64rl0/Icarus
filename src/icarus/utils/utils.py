# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/utils/utils.py
# Created 1/19/25 - 8:58 PM UK Time (London) by carlogtt
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
import functools
import os
import pathlib
import subprocess
import sys
from collections.abc import Callable
from typing import Any, Optional, Union

# Local Folder (Relative) Imports
from .. import config

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'cli_version',
    'set_logger_level',
    'run_bash_script',
    'capture_exit_code',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
OriginalFunction = Callable[..., Any]
InnerFunction = Callable[..., Any]


def capture_exit_code(original_function: OriginalFunction) -> InnerFunction:
    """
    Decorator function to capture the exit code of a Python function.

    :param original_function: The Python function to be decorated.
    :return: Exit code of the Python function.
    """

    @functools.wraps(original_function)
    def inner(*args: Any, **kwargs: Any) -> int:
        try:
            original_function(*args, **kwargs)
            return 0

        except Exception as ex:
            module_logger.debug(
                f"Exception occurred while running function: '{original_function.__name__}' |"
                f" exception: {repr(ex)}"
            )
            return 1

    return inner


@capture_exit_code
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
    python_version = sys.version.split()[0]

    version = f'icarus-cli: {icarus_version}\nicarus-hash: {icarus_build}\npython: {python_version}'

    print(version, flush=True)


def set_logger_level(level: int) -> None:
    """
    Set the logging level for the logger.

    :param level: The logging level to set.
    """

    if level > 0:
        config.master_logger.app_logger.setLevel('DEBUG')
        config.master_logger.add_console_handler()
    else:
        config.master_logger.app_logger.setLevel('WARNING')
        config.master_logger.add_console_handler()


def run_bash_script(
    script_path: Union[str, pathlib.Path], script_args: Optional[list[str]] = None
) -> int:
    """
    Runs a Bash script with the given arguments.

    :param script_path: Path to the Bash script.
    :param script_args: List of arguments to pass to the script.
    :return: Exit code of the Bash script.
    """

    module_logger.debug(f"Running BASH script with script_args before serializing {script_args=}")

    if script_args is None:
        script_args = []

    else:
        if not isinstance(script_args, list):
            raise TypeError(f"{script_args=} must be a list of strings")

        script_args_tmp = []

        for arg in script_args:
            if arg is None:
                script_args_tmp.append('')
            elif isinstance(arg, str):
                script_args_tmp.append(arg)
            else:
                script_args_tmp.append(str(arg))

        script_args = script_args_tmp

    module_logger.debug(f"Running BASH script with script_args after serializing {script_args=}")

    try:
        # Combine the script path and its arguments
        command = ['bash', script_path] + script_args

        # Execute the script and wait for it to complete
        result = subprocess.run(command, check=True, text=True)

        module_logger.debug(f"{command=} executed successfully with exit code: {result.returncode}")

        return result.returncode

    except subprocess.CalledProcessError as ex:
        module_logger.debug(f"{command=} failed with exit code {ex.returncode}: {ex}")

        return ex.returncode

    except Exception as ex:
        module_logger.debug(f"Exception occurred while running {command=} | exception: {repr(ex)}")

        return 1
