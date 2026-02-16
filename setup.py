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
import pathlib

# Third Party Library Imports
from setuptools import setup

# END IMPORTS
# ======================================================================


def derive_version() -> str:
    """
    Derive the version number from the icarus.cfg file.

    :return: The version number as a string.
    """

    path_to_icarus_cfg = pathlib.Path(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), 'icarus.cfg')
    )
    version = None

    with open(path_to_icarus_cfg, 'r') as fh:
        for line in fh.readlines():
            if line.startswith('  - version: '):
                version = line.split(':')[1].strip()
                if len(version.split('.')) != 3:
                    continue
                break

    if version is None:
        raise KeyError('Version not found in icarus.cfg file.')

    return version


setup(
    version=derive_version(),
)
