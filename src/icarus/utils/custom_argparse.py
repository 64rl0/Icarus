# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/utils/custom_argparse.py
# Created 1/19/25 - 9:39 PM UK Time (London) by carlogtt
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
import sys

# Local Folder (Relative) Imports
from .. import config

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['IcarusArgumentParser']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


class IcarusArgumentParser(argparse.ArgumentParser):
    """
    Custom argument parser for the CLI application.
    """

    def error(self, message):
        """
        Overrides the default error handling to provide a more
        user-friendly error message.

        :param message: The error message to be displayed.
        """

        self.print_help(sys.stderr)
        print('\n\n[USAGE ERROR]\n', end='', flush=True)
        super().error(message)
