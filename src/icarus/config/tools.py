# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/config/tools.py
# Created 1/19/25 - 9:58 PM UK Time (London) by carlogtt

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

# My Library Imports
import carlogtt_python_library

# Local Folder (Relative) Imports
from . import constants

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['master_logger']

# Setting up logger for current module
# module_logger =

# Type aliases
#

master_logger = carlogtt_python_library.Logger(
    log_name=constants.CLI_NAME,
    log_fmt='%(levelname)-8s | %(asctime)s | %(filename)-20s:%(lineno)-3d | %(message)s',
    log_level='WARNING',
)
master_logger.add_console_handler()
