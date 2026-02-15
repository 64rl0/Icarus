# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/create_helper.py
# Created 2/15/26 - 7:06 PM UK Time (London) by carlogtt
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
import re

# My Library Imports
import carlogtt_python_library as mylib

# Local Application Imports
from icarus import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'get_argv',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


def get_argv(package_name: str, package_language: str) -> list[str]:
    """
    Get the command line arguments and return them as a list.

    :return: The arguments for the create.sh script.
    """

    stru = mylib.StringUtils()
    name_re = re.compile(r'^[A-Za-z0-9]*$')

    package_language_normalized = package_language.strip()
    package_name_pascal_case_normalized = package_name.strip()

    if not name_re.match(package_name_pascal_case_normalized):
        raise utils.IcarusParserException(
            "Invalid input: only alphanumeric characters are allowed in the package name"
        )
    if not name_re.match(package_language_normalized):
        raise utils.IcarusParserException(
            "Invalid input: only alphanumeric characters are allowed in the package language"
        )

    package_name_snake_case = stru.snake_case(package_name_pascal_case_normalized)
    package_name_dashed = package_name_snake_case.replace('_', '-')

    argv = [
        package_language_normalized,
        package_name_pascal_case_normalized,
        package_name_snake_case,
        package_name_dashed,
    ]

    print(
        f"Package name mapping:\n--| User input:  {package_name}\n--| PascalCase:"
        f"  {package_name_pascal_case_normalized}\n--| snake_case:  {package_name_snake_case}\n"
        f"--| dashed-case: {package_name_dashed}"
    )

    return argv
