# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/builder_helper.py
# Created 5/24/25 - 8:48 PM UK Time (London) by carlogtt
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
import re
from typing import Literal, TypedDict, Union

# Third Party Library Imports
import requests
import yaml

# My Library Imports
import carlogtt_python_library as mylib

# Local Folder (Relative) Imports
from ... import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['get_argv']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


# Type aliases
class IbArgMmp(TypedDict):
    icarus_config_filename: str
    icarus_config_filepath: str
    project_root_dir_abs: str
    package_name_pascal_case: str
    package_name_snake_case: str
    package_name_dashed: str
    package_language: str
    build_system_in_use: str
    platform_identifier: str
    python_version_default_for_brazil: str
    python_versions_for_brazil: list[str]
    build_env_dir_name: str
    python_version_default_for_icarus: str
    python_versions_for_icarus: list[str]
    requirements_paths: list[str]
    icarus_ignore_array: list[str]
    build: str
    is_only_build_hook: str
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
    docs: str
    exec: str
    initial_command_received: str
    initial_exec_command_received: list[str]
    running_hooks_name: list[str]
    running_hooks_count: str
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
        Literal['docs'],
        Literal['exec'],
    ]
    python_default_version: str
    python_default_full_version: str
    python_versions: list[str]


def get_argv(ib_args: dict[str, Union[str, list[str]]]) -> str:
    """
    Get the arguments for the builder.sh script.

    :param ib_args:
    :return: The arguments for the builder.sh script.
    """

    validate_build_cli_args_base_rules(ib_args=ib_args)

    ib_arg_mmp = initialize_ib_arg_mmp(ib_args=ib_args)
    ib_arg_mmp = read_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = parse_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = validate_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = process_ib_args(ib_arg_mmp=ib_arg_mmp, ib_args=ib_args)
    ib_arg_mmp = normalize_and_set_defaults_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = normalize_and_set_python_version(ib_arg_mmp=ib_arg_mmp)

    ib_argv = convert_ib_arg_mmp_to_ib_argv(ib_arg_mmp=ib_arg_mmp)

    return ib_argv


def initialize_ib_arg_mmp(ib_args: dict[str, Union[str, list[str]]]) -> IbArgMmp:
    """
    Initialize the IbbArgMmp dictionary with default values.

    :param ib_args: The parsed arguments.
    :return: The initialized IbbArgMmp dictionary.
    """

    # Initialize the IbbArgMmp dictionary with default values
    ib_arg_mmp: IbArgMmp = {
        'all_hooks': (
            'build',
            'clean',
            'isort',
            'black',
            'flake8',
            'mypy',
            'shfmt',
            'eolnorm',
            'whitespaces',
            'trailing',
            'eofnewline',
            'gitleaks',
            'pytest',
            'docs',
            'exec',
        ),
        'icarus_config_filename': '',
        'icarus_config_filepath': '',
        'project_root_dir_abs': '',
        'package_name_pascal_case': '',
        'package_name_snake_case': '',
        'package_name_dashed': '',
        'package_language': '',
        'build_system_in_use': '',
        'platform_identifier': utils.platform_id(),
        'python_version_default_for_brazil': '',
        'python_versions_for_brazil': [],
        'build_env_dir_name': '',
        'python_version_default_for_icarus': '',
        'python_versions_for_icarus': [],
        'requirements_paths': [],
        'icarus_ignore_array': [],
        'build': 'Y' if ib_args.get('build') else 'N',
        'is_only_build_hook': 'N',
        'clean': 'Y' if ib_args.get('clean') else 'N',
        'isort': 'Y' if ib_args.get('isort') else 'N',
        'black': 'Y' if ib_args.get('black') else 'N',
        'flake8': 'Y' if ib_args.get('flake8') else 'N',
        'mypy': 'Y' if ib_args.get('mypy') else 'N',
        'shfmt': 'Y' if ib_args.get('shfmt') else 'N',
        'eolnorm': 'Y' if ib_args.get('eolnorm') else 'N',
        'whitespaces': 'Y' if ib_args.get('whitespaces') else 'N',
        'trailing': 'Y' if ib_args.get('trailing') else 'N',
        'eofnewline': 'Y' if ib_args.get('eofnewline') else 'N',
        'gitleaks': 'Y' if ib_args.get('gitleaks') else 'N',
        'pytest': 'Y' if ib_args.get('pytest') else 'N',
        'docs': 'Y' if ib_args.get('docs') else 'N',
        'exec': 'Y' if ib_args.get('exec') else 'N',
        'initial_command_received': 'icarus builder',
        'initial_exec_command_received': [],
        'running_hooks_name': [],
        'running_hooks_count': '',
        'python_default_version': '',
        'python_default_full_version': '',
        'python_versions': [],
    }

    return ib_arg_mmp


def validate_build_cli_args_base_rules(ib_args: dict[str, Union[str, list[str]]]) -> None:
    """
    Prepare the arguments for the builder.sh script.

    This function takes the parsed arguments and prepares them for the
    builder.sh script to eval them and set as script variables.

    :param ib_args:
    :return:
    """

    # Initial validations
    if ib_args.get('clean') and sum(1 for el in ib_args.values() if el) > 1:
        raise utils.IcarusParserException('--clean is a standalone argument and must be used alone')

    if ib_args.get('exec') and sum(1 for el in ib_args.values() if el) > 1:
        raise utils.IcarusParserException('--exec is a standalone argument and must be used alone')

    if not any(ib_args.values()):
        raise utils.IcarusParserException(
            f'{config.CLI_NAME} builder requires at least one argument'
        )


def process_ib_args(ib_arg_mmp: IbArgMmp, ib_args: dict[str, Union[str, list[str]]]) -> IbArgMmp:
    """
    Prepare the arguments for the builder.sh script.

    :param ib_arg_mmp:
    :param ib_args:
    :return:
    """

    if ib_args.get('exec'):
        if len(ib_args['exec']) == 1:
            initial_exec_command_received = ib_args['exec'][0].split()
        elif len(ib_args['exec']) > 1:
            assert isinstance(ib_args['exec'], list)
            initial_exec_command_received = ib_args['exec']
        else:
            raise utils.IcarusParserException('Invalid --exec argument')
        ib_arg_mmp.update({'initial_exec_command_received': initial_exec_command_received})
        # altering the exec value so it can be used from the for loop
        # here below to make up the initial_command_received look nice
        ib_args['exec'] = f"--exec {' '.join(ib_args['exec'])}"

    if ib_args.get('release'):
        if ib_arg_mmp['build_system_in_use'] in {'brazil', 'icarus'}:
            ib_arg_mmp.update({
                'build': 'Y',
                'isort': 'Y',
                'black': 'Y',
                'flake8': 'Y',
                'mypy': 'Y',
                'shfmt': 'Y',
                'eolnorm': 'Y',
                'whitespaces': 'Y',
                'trailing': 'Y',
                'eofnewline': 'Y',
                'pytest': 'Y',
                'gitleaks': 'Y',
                'docs': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --release argument is only valid for brazil or icarus build systems'
            )

    if ib_args.get('format'):
        if ib_arg_mmp['build_system_in_use'] in {'brazil', 'icarus'}:
            ib_arg_mmp.update({
                'isort': 'Y',
                'black': 'Y',
                'shfmt': 'Y',
                'eolnorm': 'Y',
                'whitespaces': 'Y',
                'trailing': 'Y',
                'eofnewline': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --format argument is only valid for brazil or icarus build systems'
            )

    if ib_args.get('test'):
        if ib_arg_mmp['build_system_in_use'] in {'brazil', 'icarus'}:
            ib_arg_mmp.update({
                'pytest': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --test argument is only valid for brazil or icarus build systems'
            )

    for arg in ib_args.values():
        if arg:
            ib_arg_mmp['initial_command_received'] += f" {arg}"

    for hook in ib_arg_mmp['all_hooks']:
        if ib_arg_mmp[hook] == 'Y':
            ib_arg_mmp['running_hooks_name'].append(hook)

    ib_arg_mmp['running_hooks_count'] = str(len(ib_arg_mmp['running_hooks_name']))

    if ib_arg_mmp['build'] == 'Y' and ib_arg_mmp['running_hooks_count'] == str(1):
        ib_arg_mmp['is_only_build_hook'] = 'Y'

    return ib_arg_mmp


def read_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Process the icarus build config file and return a string with
    all the ib_arg_mmp to be then eval from the sh script.

    :param ib_arg_mmp:
    :return:
    """

    pwd = os.getcwd()
    while pwd != '/':
        if os.path.exists(f"{pwd}/{config.ICARUS_CFG_FILENAME}"):
            break
        else:
            pwd = os.path.dirname(pwd)
    else:
        raise utils.IcarusParserException(
            f'No `{config.ICARUS_CFG_FILENAME}` file found!\n               You are not in an'
            ' icarus build enabled directory.\n               To enable icarus build create a'
            f' `{config.ICARUS_CFG_FILENAME}` in the project root directory.'
        )

    config_filepath = f"{pwd}/{config.ICARUS_CFG_FILENAME}"

    ib_arg_mmp['icarus_config_filename'] = config.ICARUS_CFG_FILENAME
    ib_arg_mmp['icarus_config_filepath'] = config_filepath
    ib_arg_mmp['project_root_dir_abs'] = pwd

    return ib_arg_mmp


def parse_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Parse the icarus build config file.

    :param ib_arg_mmp:
    :return:
    """

    try:
        with open(ib_arg_mmp['icarus_config_filepath']) as icarus_build_config:
            ibc = yaml.safe_load(icarus_build_config)
    except Exception as e:
        raise utils.IcarusParserException(
            f"Error parsing {ib_arg_mmp['icarus_config_filepath']}\n               {repr(e)}"
        )

    pkg = ibc.get('package', [])
    bs = ibc.get('build-system', [])
    brz = ibc.get('brazil', [])
    vnv = ibc.get('icarus', [])
    ignrs = ibc.get('ignore', [])

    try:
        ib_arg_mmp['package_name_pascal_case'] = [d['name'] for d in pkg if d.get('name')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['package_language'] = [d['language'] for d in pkg if d.get('language')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['build_system_in_use'] = [d['runtime'] for d in bs if d.get('runtime')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['python_version_default_for_brazil'] = [
            d['python-default'] for d in brz if d.get('python-default')
        ][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['python_versions_for_brazil'] = [d['python'] for d in brz if d.get('python')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['build_env_dir_name'] = [d['name'] for d in vnv if d.get('name')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['python_version_default_for_icarus'] = [
            d['python-default'] for d in vnv if d.get('python-default')
        ][0]

    except Exception:
        pass

    try:
        ib_arg_mmp['requirements_paths'] = [
            d['requirements'] for d in vnv if d.get('requirements')
        ][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['python_versions_for_icarus'] = [d['python'] for d in vnv if d.get('python')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['icarus_ignore_array'] = [i.strip() for i in ignrs]
    except Exception:
        pass

    return ib_arg_mmp


def validate_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Validate the icarus build config file.

    :param ib_arg_mmp:
    :return:
    """

    accepted_build_systems = ['brazil', 'icarus']

    if not ib_arg_mmp.get('package_name_pascal_case'):
        raise utils.IcarusParserException(
            f'No package name specified in {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('package_name_pascal_case'), str):
            raise utils.IcarusParserException(
                f'Package name in {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if not ib_arg_mmp.get('package_language'):
        raise utils.IcarusParserException(
            f'No package language specified in {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('package_language'), str):
            raise utils.IcarusParserException(
                f'Package language in {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if not ib_arg_mmp.get('build_system_in_use'):
        raise utils.IcarusParserException(
            f'No build system specified in {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('build_system_in_use'), str):
            raise utils.IcarusParserException(
                f'Build system in {config.ICARUS_CFG_FILENAME} must be a string'
            )
        if ib_arg_mmp.get('build_system_in_use') not in accepted_build_systems:
            raise utils.IcarusParserException(
                f'Invalid build system in {config.ICARUS_CFG_FILENAME}'
            )

    if ib_arg_mmp.get('build_system_in_use') == 'brazil':
        if not ib_arg_mmp.get('python_versions_for_brazil'):
            raise utils.IcarusParserException(
                f'No python version(s) specified in brazil {config.ICARUS_CFG_FILENAME}'
            )
        elif isinstance(ib_arg_mmp.get('python_versions_for_brazil'), list):
            if not all(
                isinstance(v, str) for v in ib_arg_mmp.get('python_versions_for_brazil', [])
            ):
                raise utils.IcarusParserException(
                    f'All python versions in brazil {config.ICARUS_CFG_FILENAME} must be strings'
                )
            if not all(
                len(v.split('.')) in {2, 3}
                for v in ib_arg_mmp.get('python_versions_for_brazil', [])
            ):
                raise utils.IcarusParserException(
                    f'All python versions in brazil {config.ICARUS_CFG_FILENAME} must be valid'
                )
        else:
            raise utils.IcarusParserException(
                f'Python versions in brazil {config.ICARUS_CFG_FILENAME} must be a list of string'
            )

        if not ib_arg_mmp.get('python_version_default_for_brazil'):
            raise utils.IcarusParserException(
                f'No default python version specified in brazil {config.ICARUS_CFG_FILENAME}'
            )
        else:
            if not isinstance(ib_arg_mmp.get('python_version_default_for_brazil'), str):
                raise utils.IcarusParserException(
                    f'Default python version in brazil {config.ICARUS_CFG_FILENAME} must be a'
                    ' string'
                )
            if len(ib_arg_mmp.get('python_version_default_for_brazil', '').split('.')) not in {
                2,
                3,
            }:
                raise utils.IcarusParserException(
                    f'Invalid default python version in brazil {config.ICARUS_CFG_FILENAME}'
                )
            if ib_arg_mmp.get('python_version_default_for_brazil') not in ib_arg_mmp.get(
                'python_versions_for_brazil', []
            ):
                raise utils.IcarusParserException(
                    f'Default python version in brazil {config.ICARUS_CFG_FILENAME} must be in the'
                    ' list of python versions'
                )

    if ib_arg_mmp.get('build_system_in_use') == 'icarus':
        if not ib_arg_mmp.get('build_env_dir_name'):
            raise utils.IcarusParserException(
                f'No `build_env_dir_name` specified in icarus {config.ICARUS_CFG_FILENAME}'
            )
        else:
            if not isinstance(ib_arg_mmp.get('build_env_dir_name'), str):
                raise utils.IcarusParserException(
                    f'`build_env_dir_name` in icarus {config.ICARUS_CFG_FILENAME} must be a string'
                )

        if not ib_arg_mmp.get('python_versions_for_icarus'):
            raise utils.IcarusParserException(
                f'No python version(s) specified in icarus {config.ICARUS_CFG_FILENAME}'
            )
        elif isinstance(ib_arg_mmp.get('python_versions_for_icarus'), list):
            if not all(
                isinstance(v, str) for v in ib_arg_mmp.get('python_versions_for_icarus', [])
            ):
                raise utils.IcarusParserException(
                    f'All python versions in icarus {config.ICARUS_CFG_FILENAME} must be strings'
                )
            if not all(
                len(v.split('.')) in {2, 3}
                for v in ib_arg_mmp.get('python_versions_for_icarus', [])
            ):
                raise utils.IcarusParserException(
                    f'All python versions in icarus {config.ICARUS_CFG_FILENAME} must be valid'
                )
        else:
            raise utils.IcarusParserException(
                f'Python versions in icarus {config.ICARUS_CFG_FILENAME} must be a list of string'
            )

        if not ib_arg_mmp.get('python_version_default_for_icarus'):
            raise utils.IcarusParserException(
                f'No default python version specified in icarus {config.ICARUS_CFG_FILENAME}'
            )
        else:
            if not isinstance(ib_arg_mmp.get('python_version_default_for_icarus'), str):
                raise utils.IcarusParserException(
                    f'Default python version in icarus {config.ICARUS_CFG_FILENAME} must be a'
                    ' string'
                )
            if len(ib_arg_mmp.get('python_version_default_for_icarus', '').split('.')) not in {
                2,
                3,
            }:
                raise utils.IcarusParserException(
                    f'Invalid default python version in brazil {config.ICARUS_CFG_FILENAME}'
                )
            if ib_arg_mmp.get('python_version_default_for_icarus') not in ib_arg_mmp.get(
                'python_versions_for_icarus', []
            ):
                raise utils.IcarusParserException(
                    f'Default python version in icarus {config.ICARUS_CFG_FILENAME} must be in the'
                    ' list of python versions'
                )

        if not ib_arg_mmp.get('requirements_paths'):
            # not a mandatory field
            pass
        elif isinstance(ib_arg_mmp.get('requirements_paths'), list):
            if not all(isinstance(v, str) for v in ib_arg_mmp.get('requirements_paths', [])):
                raise utils.IcarusParserException(
                    f'All requirements path array in icarus {config.ICARUS_CFG_FILENAME} must be'
                    ' strings'
                )
        else:
            if not isinstance(ib_arg_mmp.get('requirements_paths'), list):
                raise utils.IcarusParserException(
                    f'Requirements path array in icarus {config.ICARUS_CFG_FILENAME} must be a list'
                    ' of strings'
                )

    if not ib_arg_mmp.get('icarus_ignore_array'):
        # not a mandatory field
        pass
    elif isinstance(ib_arg_mmp.get('icarus_ignore_array'), list):
        if not all(isinstance(v, str) for v in ib_arg_mmp.get('icarus_ignore_array', [])):
            raise utils.IcarusParserException(
                f'All icarus ignore array in {config.ICARUS_CFG_FILENAME} must be strings'
            )
    else:
        if not isinstance(ib_arg_mmp.get('icarus_ignore_array'), list):
            raise utils.IcarusParserException(
                f'Icarus ignore array in {config.ICARUS_CFG_FILENAME} must be a list of string'
            )

    return ib_arg_mmp


def normalize_and_set_defaults_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Normalize the ib_arg_mmp to be used in the python script.

    :param ib_arg_mmp:
    :return:
    """

    stru = mylib.StringUtils()

    # Optional settings will get here as None, set defaults
    if ib_arg_mmp.get('requirements_paths') is None:
        ib_arg_mmp['requirements_paths'] = []
    if ib_arg_mmp.get('icarus_ignore_array') is None:
        ib_arg_mmp['icarus_ignore_array'] = []

    # Add pkg name snake anf dashed
    try:
        ib_arg_mmp['package_name_snake_case'] = stru.snake_case(
            ib_arg_mmp['package_name_pascal_case']
        )
        ib_arg_mmp['package_name_dashed'] = ib_arg_mmp['package_name_snake_case'].replace("_", "-")
    except Exception:
        raise utils.IcarusParserException(f"Invalid package name in {config.ICARUS_CFG_FILENAME}")

    # Remove duplicates and sort from newest to oldest version
    ib_arg_mmp['python_versions_for_brazil'] = sorted(
        list(set(ib_arg_mmp['python_versions_for_brazil'])), key=sort_version, reverse=True
    )
    ib_arg_mmp['python_versions_for_icarus'] = sorted(
        list(set(ib_arg_mmp['python_versions_for_icarus'])), key=sort_version, reverse=True
    )
    ib_arg_mmp['icarus_ignore_array'] = list(set(ib_arg_mmp['icarus_ignore_array']))
    ib_arg_mmp['requirements_paths'] = list(set(ib_arg_mmp['requirements_paths']))

    return ib_arg_mmp


def normalize_and_set_python_version(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Set the python version to use.

    :param ib_arg_mmp:
    :return:
    """

    if ib_arg_mmp['build_system_in_use'] == 'brazil':
        if len(ib_arg_mmp['python_version_default_for_brazil'].split('.')) == 2:
            ib_arg_mmp['python_default_version'] = ib_arg_mmp['python_version_default_for_brazil']
            ib_arg_mmp['python_default_full_version'] = get_latest_python_version(
                ib_arg_mmp['python_default_version']
            )
        elif len(ib_arg_mmp['python_version_default_for_brazil'].split('.')) == 3:
            ib_arg_mmp['python_default_version'] = '.'.join(
                ib_arg_mmp['python_version_default_for_brazil'].split('.')[:2]
            )
            ib_arg_mmp['python_default_full_version'] = ib_arg_mmp[
                'python_version_default_for_brazil'
            ]

        python_versions_to_normalize = ib_arg_mmp['python_versions_for_brazil']

    elif ib_arg_mmp['build_system_in_use'] == 'icarus':
        if len(ib_arg_mmp['python_version_default_for_icarus'].split('.')) == 2:
            ib_arg_mmp['python_default_version'] = ib_arg_mmp['python_version_default_for_icarus']
            ib_arg_mmp['python_default_full_version'] = get_latest_python_version(
                ib_arg_mmp['python_default_version']
            )
        elif len(ib_arg_mmp['python_version_default_for_icarus'].split('.')) == 3:
            ib_arg_mmp['python_default_version'] = '.'.join(
                ib_arg_mmp['python_version_default_for_icarus'].split('.')[:2]
            )
            ib_arg_mmp['python_default_full_version'] = ib_arg_mmp[
                'python_version_default_for_icarus'
            ]

        python_versions_to_normalize = ib_arg_mmp['python_versions_for_icarus']

    def_v = f"{ib_arg_mmp['python_default_version']}:{ib_arg_mmp['python_default_full_version']}"
    tmp_py_v = []

    for v in python_versions_to_normalize:
        if len(v.split('.')) == 2:
            short_version = v
            full_version = get_latest_python_version(v)
        elif len(v.split('.')) == 3:
            short_version = '.'.join(v.split('.')[:2])
            full_version = v
        tmp_py_v.append(':'.join([short_version, full_version]))

    # Python default always stays at index 0
    ib_arg_mmp['python_versions'] = [v for v in tmp_py_v if v == def_v] + [
        v for v in tmp_py_v if v != def_v
    ]

    return ib_arg_mmp


def convert_ib_arg_mmp_to_ib_argv(ib_arg_mmp: IbArgMmp) -> str:
    """
    Convert a dictionary to a bash ib_arg_mmp string.

    :param ib_arg_mmp:
    :return:
    """

    temp_ib_arg_mmp = {}

    module_logger.debug('*' * 50)

    for k, v in ib_arg_mmp.items():
        temp_ib_arg_mmp[k] = convert_value(v)
        module_logger.debug(f"ib_arg_mmp -> {k}={temp_ib_arg_mmp[k]}")

    module_logger.debug('*' * 50)

    ib_arg_mmp_str = ' '.join([f"{k}={v}" for k, v in temp_ib_arg_mmp.items()])

    return ib_arg_mmp_str


def get_latest_python_version(python_version: str) -> str:
    """
    Get the latest python full version for the given python version.

    :param python_version:
    :return:
    """

    given_major, given_minor = python_version.split('.')
    given_patch = 0

    reg = re.compile(r'(\d+)\.(\d+)\.(\d+)')

    response = requests.get('https://www.python.org/ftp/python/')

    for version in set(reg.findall(response.text)):
        major = version[0]
        minor = version[1]
        patch = version[2]
        if major != given_major:
            continue
        if minor != given_minor:
            continue
        if int(patch) > given_patch:
            given_patch = int(patch)

    return f"{given_major}.{given_minor}.{given_patch}"


def convert_value(value):
    """
    Convert a value to a string representation suitable for use in a
    Bash script.

    :param value:
    :return:
    """

    if isinstance(value, str):
        return repr(value)
    elif isinstance(value, list) or isinstance(value, tuple):
        return f"( {' '.join(convert_value(el) for el in value)} )"
    else:
        raise utils.IcarusParserException(f"Invalid type for `{value}`")


def sort_version(v):
    """
    Sort version.
    """

    version_split = v.split('.')
    version_len = len(version_split)

    if version_len == 1:
        v = f"{version_split[0]}.0.0"
    elif version_len == 2:
        v = f"{version_split[0]}.{version_split[1]}.0"
    elif version_len == 3:
        v = f"{version_split[0]}.{version_split[1]}.{version_split[2]}"

    major = v.split('.')[0]
    if len(major) == 1:
        major = f"00{major}"
    elif len(major) == 2:
        major = f"0{major}"

    minor = v.split('.')[1]
    if len(minor) == 1:
        minor = f"00{minor}"
    elif len(minor) == 2:
        minor = f"0{minor}"

    patch = v.split('.')[2]
    if len(patch) == 1:
        patch = f"00{patch}"
    elif len(patch) == 2:
        patch = f"0{patch}"

    v = f"{major}{minor}{patch}"

    skey = int(v)

    return skey
