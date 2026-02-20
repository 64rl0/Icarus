# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/update_version_helper.py
# Created 2/16/26 - 4:23 PM UK Time (London) by carlogtt

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

# Local Application Imports
from icarus import config, utils
from icarus.handlers.builder_handler.model import IcarusBuilderArg

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'update_version_file',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


@utils.capture_exit_code
def update_version_file(ib_arg: IcarusBuilderArg) -> None:
    """
    Update the version number in a given file.

    :param ib_arg: The IbbArgMmp dictionary.
    :return: None
    """

    current_version = ib_arg.package_version_full
    current_version_major = ib_arg.package_version_major
    current_version_minor = ib_arg.package_version_minor
    current_version_patch = ib_arg.package_version_patch

    print(f"Current version: {current_version}", flush=True)
    print("", flush=True)

    # Parse the command line
    version_option = input('Enter the release type (major, minor or [patch]): ')
    if version_option not in ('major', 'minor', 'patch', ''):
        raise utils.IcarusParserException("Version option must be 'major', 'minor' or 'patch'")

    # No option provided, so default to the patch version
    if version_option == '':
        version_option = 'patch'

    # Check what option was provided and increment the version
    # accordingly
    if version_option == 'major':
        new_version_major = str(int(current_version_major) + 1)
        new_version_minor = '0'
        new_version_patch = '0'
    elif version_option == 'minor':
        new_version_major = current_version_major
        new_version_minor = str(int(current_version_minor) + 1)
        new_version_patch = '0'
    elif version_option == 'patch':
        new_version_major = current_version_major
        new_version_minor = current_version_minor
        new_version_patch = str(int(current_version_patch) + 1)
    else:
        raise utils.IcarusParserException("Version option must be 'major', 'minor' or 'patch'")

    new_version = '.'.join([new_version_major, new_version_minor, new_version_patch])

    print(f"Updating version ({version_option}) to {new_version}")
    print("", flush=True)

    # Update new version in icarus.cfg
    try:
        with open(ib_arg.icarus_config_filepath, 'r') as icarus_build_config:
            icarus_build_config_content = icarus_build_config.readlines()
    except Exception as e:
        raise utils.IcarusParserException(
            f"Error parsing {ib_arg.icarus_config_filename} -- {repr(e)}"
        )

    updated = False
    try:
        with open(ib_arg.icarus_config_filepath, 'w') as icarus_build_config:
            for line in icarus_build_config_content:
                if line == f'  - version: {current_version}\n':
                    icarus_build_config.write(f'  - version: {new_version}\n')
                    updated = True
                else:
                    icarus_build_config.write(line)
    except Exception as e:
        raise utils.IcarusParserException(
            f"Error parsing {ib_arg.icarus_config_filename} -- {repr(e)}"
        )

    if not updated:
        raise utils.IcarusParserException(
            f"Error updating version in {ib_arg.icarus_config_filename}"
        )

    print(f"New version: {new_version}", flush=True)
    print("", flush=True)
