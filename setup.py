# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# setup.py
# Created 2/16/26 - 9:50 AM UK Time (London) by carlogtt

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

# Third Party Library Imports
from setuptools import setup

# END IMPORTS
# ======================================================================


def derive_version() -> str:
    """
    This function is required for Icarus Builder to  determine the
    package version from the version in `icarus.cfg`.

    The version number is expected to be provided via the
    environment variable `ICARUS_PACKAGE_VERSION`.

    If this variable is not found, a KeyError will be raised.

    :return: The version number as a string.
    """

    version = os.environ.get('ICARUS_PACKAGE_VERSION')

    if version is None:
        raise KeyError("ICARUS_PACKAGE_VERSION not found in the environment.")

    return version


setup(
    version=derive_version(),
)
