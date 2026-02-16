# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/types.py
# Created 2/16/26 - 4:33 PM UK Time (London) by carlogtt

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
from typing import Literal, TypedDict

# Local Application Imports
from icarus import config

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'IbArgMmp',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


class IbArgMmp(TypedDict):
    all_hooks: tuple[
        Literal['build'],
        Literal['clean'],
        Literal['isort'],
        Literal['black'],
        Literal['flake8'],
        Literal['mypy'],
        Literal['shfmt'],
        Literal['eolnorm'],
        Literal['whitespaces'],
        Literal['trailing'],
        Literal['eofnewline'],
        Literal['gitleaks'],
        Literal['pytest'],
        Literal['sphinx'],
        Literal['readthedocs'],
        Literal['merge'],
        Literal['exectool'],
        Literal['execrun'],
        Literal['execdev'],
        Literal['bumpver'],
    ]
    icarus_config_filename: str
    icarus_config_filepath: str
    project_root_dir_abs: str
    package_name_pascal_case: str
    package_name_snake_case: str
    package_name_dashed: str
    package_language: str
    package_version_full: str
    package_version_major: str
    package_version_minor: str
    package_version_patch: str
    build_system_in_use: str
    platform_identifier: str
    build_root_dir: str
    python_version_default_for_icarus: str
    python_versions_for_icarus: list[str]
    tool_requirements_paths: list[str]
    run_requirements_paths: list[str]
    run_requirements_pyproject_toml: list[str]
    dev_requirements_paths: list[str]
    icarus_ignore_array: list[str]
    build: str
    is_only_build_hook: str
    is_release: str
    merge: str
    clean: str
    isort: str
    black: str
    flake8: str
    mypy: str
    shfmt: str
    eolnorm: str
    whitespaces: str
    trailing: str
    eofnewline: str
    gitleaks: str
    pytest: str
    sphinx: str
    readthedocs: str
    exectool: str
    execrun: str
    execdev: str
    bumpver: str
    initial_command_received: str
    initial_exectool_command_received: list[str]
    initial_execrun_command_received: list[str]
    initial_execdev_command_received: list[str]
    running_hooks_name: list[str]
    running_hooks_count: str
    verbose: str
    python_default_version: str
    python_default_full_version: str
    python_versions: list[str]
    path_name: str
    list_paths: str
