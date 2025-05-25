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
from typing import Literal, TypedDict, Union

# Third Party Library Imports
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
    python_versions_for_brazil: list
    venv_name: str
    python_version_default_for_venv: str
    python_versions_for_venv: list
    requirements_paths: list
    icarus_ignore_array: list
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
    initial_exec_command_received: list
    running_hooks_name: list
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


def get_argv(ib_args: dict[str, Union[str, list[str]]]) -> str:
    """
    Get the arguments for the builder.sh script.

    :return: The arguments for the builder.sh script.
    """

    validate_build_cli_args_base_rules(ib_args=ib_args)

    ib_arg_mmp = initialize_ib_arg_mmp(ib_args=ib_args)
    ib_arg_mmp = read_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = parse_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = validate_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = process_ib_args(ib_arg_mmp=ib_arg_mmp, ib_args=ib_args)
    ib_arg_mmp = normalize_and_set_defaults_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)

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
        'venv_name': '',
        'python_version_default_for_venv': '',
        'python_versions_for_venv': [],
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
        raise utils.IcarusParserException('icarus builder build requires at least one argument')


def process_ib_args(ib_arg_mmp: IbArgMmp, ib_args: dict[str, Union[str, list[str]]]) -> IbArgMmp:
    """
    Prepare the arguments for the builder.sh script.

    :param ib_args:
    :param ib_arg_mmp:
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
        if ib_arg_mmp['build_system_in_use'] in {'brazil', 'venv'}:
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
                'The --release argument is only valid for brazil or venv build systems'
            )

    if ib_args.get('format'):
        if ib_arg_mmp['build_system_in_use'] in {'brazil', 'venv'}:
            ib_arg_mmp.update({
                'isort': 'Y',
                'black': 'Y',
                'flake8': 'Y',
                'mypy': 'Y',
                'shfmt': 'Y',
                'eolnorm': 'Y',
                'whitespaces': 'Y',
                'trailing': 'Y',
                'eofnewline': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --format argument is only valid for brazil or venv build systems'
            )

    if ib_args.get('test'):
        if ib_arg_mmp['build_system_in_use'] in {'brazil', 'venv'}:
            ib_arg_mmp.update({
                'pytest': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --test argument is only valid for brazil or venv build systems'
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

    :return:
    """

    config_filename = 'icarus.cfg'

    pwd = os.getcwd()
    while pwd != '/':
        if os.path.exists(f"{pwd}/{config_filename}"):
            break
        else:
            pwd = os.path.dirname(pwd)
    else:
        raise utils.IcarusParserException(
            'No `icarus.cfg` file found!\n               You are not in an icarus build enabled'
            ' directory.\n               To enable icarus build create a `icarus.cfg` in the'
            ' project root directory.'
        )

    config_filepath = f"{pwd}/{config_filename}"

    ib_arg_mmp['icarus_config_filename'] = config_filename
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
    vnv = ibc.get('venv', [])
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
        ib_arg_mmp['venv_name'] = [d['name'] for d in vnv if d.get('name')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['python_version_default_for_venv'] = [
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
        ib_arg_mmp['python_versions_for_venv'] = [d['python'] for d in vnv if d.get('python')][0]
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

    accepted_build_systems = ['brazil', 'venv']
    icfg = ib_arg_mmp['icarus_config_filename']

    if not ib_arg_mmp.get('package_name_pascal_case'):
        raise utils.IcarusParserException(f'No package name specified in {icfg}')
    else:
        if not isinstance(ib_arg_mmp.get('package_name_pascal_case'), str):
            raise utils.IcarusParserException(f'Package name in {icfg} must be a string')

    if not ib_arg_mmp.get('package_language'):
        raise utils.IcarusParserException(f'No package language specified in {icfg}')
    else:
        if not isinstance(ib_arg_mmp.get('package_language'), str):
            raise utils.IcarusParserException(f'Package language in {icfg} must be a string')

    if not ib_arg_mmp.get('build_system_in_use'):
        raise utils.IcarusParserException(f'No build system specified in {icfg}')
    else:
        if not isinstance(ib_arg_mmp.get('build_system_in_use'), str):
            raise utils.IcarusParserException(f'Build system in {icfg} must be a string')
        if ib_arg_mmp.get('build_system_in_use') not in accepted_build_systems:
            raise utils.IcarusParserException(f'Invalid build system in {icfg}')

    if ib_arg_mmp.get('build_system_in_use') == 'brazil':
        if not ib_arg_mmp.get('python_versions_for_brazil'):
            raise utils.IcarusParserException(f'No python version(s) specified in brazil {icfg}')
        elif isinstance(ib_arg_mmp.get('python_versions_for_brazil'), list):
            if not all(
                isinstance(v, str) for v in ib_arg_mmp.get('python_versions_for_brazil', [])
            ):
                raise utils.IcarusParserException(
                    f'All python versions in brazil {icfg} must be strings'
                )
        else:
            raise utils.IcarusParserException(
                f'Python versions in brazil {icfg} must be a list of string'
            )

        if not ib_arg_mmp.get('python_version_default_for_brazil'):
            raise utils.IcarusParserException(
                f'No default python version specified in brazil {icfg}'
            )
        else:
            if not isinstance(ib_arg_mmp.get('python_version_default_for_brazil'), str):
                raise utils.IcarusParserException(
                    f'Default python version in brazil {icfg} must be a string'
                )
            if ib_arg_mmp.get('python_version_default_for_brazil') not in ib_arg_mmp.get(
                'python_versions_for_brazil', []
            ):
                raise utils.IcarusParserException(
                    f'Default python version in brazil {icfg} must be in the list of python'
                    ' versions'
                )

    if ib_arg_mmp.get('build_system_in_use') == 'venv':
        if not ib_arg_mmp.get('venv_name'):
            raise utils.IcarusParserException(f'No venv name specified in venv {icfg}')
        else:
            if not isinstance(ib_arg_mmp.get('venv_name'), str):
                raise utils.IcarusParserException(f'Venv name in {icfg} must be a string')

        if not ib_arg_mmp.get('python_versions_for_venv'):
            raise utils.IcarusParserException(f'No python version(s) specified in venv {icfg}')
        elif isinstance(ib_arg_mmp.get('python_versions_for_venv'), list):
            if not all(isinstance(v, str) for v in ib_arg_mmp.get('python_versions_for_venv', [])):
                raise utils.IcarusParserException(
                    f'All python versions in venv {icfg} must be strings'
                )
        else:
            raise utils.IcarusParserException(
                f'Python versions in venv {icfg} must be a list of string'
            )

        if not ib_arg_mmp.get('python_version_default_for_venv'):
            raise utils.IcarusParserException(f'No default python version specified in venv {icfg}')
        else:
            if not isinstance(ib_arg_mmp.get('python_version_default_for_venv'), str):
                raise utils.IcarusParserException(
                    f'Default python version in venv {icfg} must be a string'
                )
            if ib_arg_mmp.get('python_version_default_for_venv') not in ib_arg_mmp.get(
                'python_versions_for_venv', []
            ):
                raise utils.IcarusParserException(
                    f'Default python version in venv {icfg} must be in the list of python versions'
                )

        if not ib_arg_mmp.get('requirements_paths'):
            # not a mandatory field
            pass
        elif isinstance(ib_arg_mmp.get('requirements_paths'), list):
            if not all(isinstance(v, str) for v in ib_arg_mmp.get('requirements_paths', [])):
                raise utils.IcarusParserException(
                    f'All requirements path array in venv {icfg} must be strings'
                )
        else:
            if not isinstance(ib_arg_mmp.get('requirements_paths'), list):
                raise utils.IcarusParserException(
                    f'Requirements path array in venv {icfg} must be a list of strings'
                )

    if not ib_arg_mmp.get('icarus_ignore_array'):
        # not a mandatory field
        pass
    elif isinstance(ib_arg_mmp.get('icarus_ignore_array'), list):
        if not all(isinstance(v, str) for v in ib_arg_mmp.get('icarus_ignore_array', [])):
            raise utils.IcarusParserException(f'All icarus ignore array in {icfg} must be strings')
    else:
        if not isinstance(ib_arg_mmp.get('icarus_ignore_array'), list):
            raise utils.IcarusParserException(
                f'Icarus ignore array in {icfg} must be a list of string'
            )

    return ib_arg_mmp


def normalize_and_set_defaults_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Normalize the ib_arg_mmp to be used in the python script.

    :param ib_arg_mmp:
    :return:
    """

    stru = mylib.StringUtils()
    skey = lambda v: int(''.join([i for i in str(v).split('.')]))  # noqa
    icfg = ib_arg_mmp['icarus_config_filename']

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
        raise utils.IcarusParserException(f"Invalid package name in {icfg}")

    # Remove duplicates and sort from newest to oldest version
    ib_arg_mmp['python_versions_for_brazil'] = sorted(
        list(set(ib_arg_mmp['python_versions_for_brazil'])), key=skey, reverse=True
    )
    ib_arg_mmp['python_versions_for_venv'] = sorted(
        list(set(ib_arg_mmp['python_versions_for_venv'])), key=skey, reverse=True
    )
    ib_arg_mmp['icarus_ignore_array'] = list(set(ib_arg_mmp['icarus_ignore_array']))
    ib_arg_mmp['requirements_paths'] = list(set(ib_arg_mmp['requirements_paths']))

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
        if not (isinstance(v, str) or isinstance(v, list) or isinstance(v, tuple)):
            raise utils.IcarusParserException(f"Invalid type for `{k}`")

        if isinstance(v, str):
            temp_ib_arg_mmp[k] = repr(v)
        if isinstance(v, tuple):
            v = list(v)
        if isinstance(v, list):
            temp_ib_arg_mmp[k] = f"( {' '.join(repr(el) for el in v)} )"

        module_logger.debug(f"ib_arg_mmp -> {k}={temp_ib_arg_mmp[k]}")

    module_logger.debug('*' * 50)

    ib_arg_mmp_str = ' '.join([f"{k}={v}" for k, v in temp_ib_arg_mmp.items()])

    return ib_arg_mmp_str
