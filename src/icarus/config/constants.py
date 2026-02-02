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
import datetime
import importlib.metadata
import os
import pathlib
import sys

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

_SEMANTIC_VERSION = importlib.metadata.version(CLI_NAME)
CLI_VERSION = f'build {_SEMANTIC_VERSION} built on 02/02/2026'

ROOT_DIR = pathlib.Path(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
CLI_SCRIPTS_DIR = pathlib.Path(
    os.path.abspath(
        os.path.join(
            os.path.dirname(sys.executable),
            '..',
            'lib',
            f"python{sys.version_info.major}.{sys.version_info.minor}",
            'site-packages',
            CLI_NAME,
            'cli_scripts',
        )
    )
)

SYSTEM_TZ = datetime.datetime.now(datetime.timezone.utc).astimezone().tzinfo

ICARUS_CFG_FILENAME = 'icarus.cfg'
ICARUS_CONTROL_PLANE_DIRNAME = '.icarus'
ICARUS_LOG_DIRNAME = 'log'
ICARUS_TRACE_LOG_FILENAME = 'trace.log'
ICARUS_LOCK_DIRNAME = 'lock'
ICARUS_BUILDER_LOCK_FILENAME = 'builder.lock'
