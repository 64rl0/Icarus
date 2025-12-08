# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/utils/exceptions.py
# Created 1/23/25 - 5:44 PM UK Time (London) by carlogtt

"""
This module ...
"""

# ======================================================================
# EXCEPTIONS
# This section documents any exceptions made code or quality rules.
# These exceptions may be necessary due to specific coding requirements
# or to bypass false positives.
# ======================================================================
# flake8: noqa


# ======================================================================
# IMPORTS
# Importing required libraries and modules for the application.
# ======================================================================


# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['IcarusParserException']

# Setting up logger for current module
# module_logger =

# Type aliases
#


class IcarusParserException(Exception):
    """
    Base exception class for IcarusParser-related exceptions.
    """
