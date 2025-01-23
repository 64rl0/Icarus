# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/config/constants.py
# Created 1/18/25 - 5:52 PM UK Time (London) by carlogtt
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
import os
import pathlib

# END IMPORTS
# ======================================================================


# List of public names in the module
# __all__ = []

# Setting up logger for current module
# module_logger =

# Type aliases
#

CLI_NAME = 'icarus'
CLI_DESCRIPTION = (
    ' _)                                   \n'
    '  |   __|   _` |   __|  |   |   __|   \n'
    '  |  (     (   |  |     |   | \\__ \\ \n'
    ' _| \\___| \\__,_| _|    \\__,_| ____/  '
)
CLI_EPILOG = ''
CLI_VERSION = 'build 2.0.56 built on 01/23/2025'

ROOT_DIR = pathlib.Path(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
CLI_SCRIPTS_DIR = pathlib.Path(os.path.join(ROOT_DIR, 'cli_scripts'))
