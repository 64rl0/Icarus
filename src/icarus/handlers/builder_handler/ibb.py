# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/ibb.py
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
import argparse
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
class IbbArgMmp(TypedDict):
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


def get_argv(args: argparse.Namespace) -> str:
    """
    Get the arguments for the build.sh script.

    :return: The arguments for the build.sh script.
    """

    # Clean the args to remove the unutilized args
    ibb_args: list[Union[str, list[str]]] = [
        args.build,
        args.clean,
        args.isort,
        args.black,
        args.flake8,
        args.mypy,
        args.shfmt,
        args.eolnorm,
        args.whitespaces,
        args.trailing,
        args.eofnewline,
        args.gitleaks,
        args.pytest,
        args.docs,
        args.exec,  # DO NOT move this idx or update ref below
        args.release,
        args.format,
        args.test,
    ]

    validate_build_cli_args_base_rules(args=args, ibb_args=ibb_args)

    ibb_arg_mmp = initialize_ibb_arg_mmp(args=args)
    ibb_arg_mmp = read_icarus_build_cfg(ibb_arg_mmp=ibb_arg_mmp)
    ibb_arg_mmp = parse_icarus_build_cfg(ibb_arg_mmp=ibb_arg_mmp)
    ibb_arg_mmp = validate_icarus_build_cfg(ibb_arg_mmp=ibb_arg_mmp)
    ibb_arg_mmp = process_ibb_args(args=args, ibb_arg_mmp=ibb_arg_mmp, ibb_args=ibb_args)
    ibb_arg_mmp = normalize_and_set_defaults_icarus_build_cfg(ibb_arg_mmp=ibb_arg_mmp)

    ibb_argv = convert_ibb_arg_mmp_to_ibb_argv(ibb_arg_mmp=ibb_arg_mmp)

    return ibb_argv


def initialize_ibb_arg_mmp(args: argparse.Namespace) -> IbbArgMmp:
    """
    Initialize the IbbArgMmp dictionary with default values.

    :param args: The parsed arguments.
    :return: The initialized IbbArgMmp dictionary.
    """

    # Initialize the IbbArgMmp dictionary with default values
    ibb_arg_mmp: IbbArgMmp = {
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
        'build': 'Y' if args.build else 'N',
        'is_only_build_hook': 'N',
        'clean': 'Y' if args.clean else 'N',
        'isort': 'Y' if args.isort else 'N',
        'black': 'Y' if args.black else 'N',
        'flake8': 'Y' if args.flake8 else 'N',
        'mypy': 'Y' if args.mypy else 'N',
        'shfmt': 'Y' if args.shfmt else 'N',
        'eolnorm': 'Y' if args.eolnorm else 'N',
        'whitespaces': 'Y' if args.whitespaces else 'N',
        'trailing': 'Y' if args.trailing else 'N',
        'eofnewline': 'Y' if args.eofnewline else 'N',
        'gitleaks': 'Y' if args.gitleaks else 'N',
        'pytest': 'Y' if args.pytest else 'N',
        'docs': 'Y' if args.docs else 'N',
        'exec': 'Y' if args.exec else 'N',
        'initial_command_received': 'icarus builder build',
        'initial_exec_command_received': [],
        'running_hooks_name': [],
        'running_hooks_count': '',
    }

    return ibb_arg_mmp


def validate_build_cli_args_base_rules(
    args: argparse.Namespace, ibb_args: list[Union[str, list[str]]]
) -> None:
    """
    Prepare the arguments for the build.sh script.

    This function takes the parsed arguments and prepares them for the
    build.sh script to eval them and set as script variables.

    :param args:
    :param ibb_args:
    :return:
    """

    # Initial validations
    if args.clean and sum(1 for el in ibb_args if el) > 1:
        raise utils.IcarusParserException('--clean is a standalone argument and must be used alone')

    if args.exec and sum(1 for el in ibb_args if el) > 1:
        raise utils.IcarusParserException('--exec is a standalone argument and must be used alone')

    if not any(ibb_args):
        raise utils.IcarusParserException('icarus builder build requires at least one argument')


def process_ibb_args(
    args: argparse.Namespace, ibb_arg_mmp: IbbArgMmp, ibb_args: list[Union[str, list[str]]]
) -> IbbArgMmp:
    """
    Prepare the arguments for the build.sh script.

    :param args:
    :param ibb_arg_mmp:
    :param ibb_args:
    :return:
    """

    if args.exec:
        if len(args.exec) == 1:
            initial_exec_command_received = args.exec[0].split()
        elif len(args.exec) > 1:
            initial_exec_command_received = args.exec
        else:
            raise utils.IcarusParserException('Invalid --exec argument')
        ibb_arg_mmp.update({'initial_exec_command_received': initial_exec_command_received})
        # altering the args.exec value so it can be used from the
        # for loop here below to make up the initial_command_received
        ibb_args[14] = f"--exec {' '.join(args.exec)}"

    if args.release:
        if ibb_arg_mmp['build_system_in_use'] in {'brazil', 'venv'}:
            ibb_arg_mmp.update({
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

    if args.format:
        if ibb_arg_mmp['build_system_in_use'] in {'brazil', 'venv'}:
            ibb_arg_mmp.update({
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

    if args.test:
        if ibb_arg_mmp['build_system_in_use'] in {'brazil', 'venv'}:
            ibb_arg_mmp.update({
                'pytest': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --test argument is only valid for brazil or venv build systems'
            )

    for arg in ibb_args:
        if arg:
            ibb_arg_mmp['initial_command_received'] += f" {arg}"

    for hook in ibb_arg_mmp['all_hooks']:
        if ibb_arg_mmp[hook] == 'Y':
            ibb_arg_mmp['running_hooks_name'].append(hook)

    ibb_arg_mmp['running_hooks_count'] = str(len(ibb_arg_mmp['running_hooks_name']))

    if ibb_arg_mmp['build'] == 'Y' and ibb_arg_mmp['running_hooks_count'] == str(1):
        ibb_arg_mmp['is_only_build_hook'] = 'Y'

    return ibb_arg_mmp


def read_icarus_build_cfg(ibb_arg_mmp: IbbArgMmp) -> IbbArgMmp:
    """
    Process the icarus build config file and return a string with
    all the ibb_arg_mmp to be then eval from the sh script.

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

    ibb_arg_mmp['icarus_config_filename'] = config_filename
    ibb_arg_mmp['icarus_config_filepath'] = config_filepath
    ibb_arg_mmp['project_root_dir_abs'] = pwd

    return ibb_arg_mmp


def parse_icarus_build_cfg(ibb_arg_mmp: IbbArgMmp) -> IbbArgMmp:
    """
    Parse the icarus build config file.

    :param ibb_arg_mmp:
    :return:
    """

    try:
        with open(ibb_arg_mmp['icarus_config_filepath']) as icarus_build_config:
            ibc = yaml.safe_load(icarus_build_config)
    except Exception as e:
        raise utils.IcarusParserException(
            f"Error parsing {ibb_arg_mmp['icarus_config_filepath']}\n               {repr(e)}"
        )

    pkg = ibc.get('package', [])
    bs = ibc.get('build-system', [])
    brz = ibc.get('brazil', [])
    vnv = ibc.get('venv', [])
    ignrs = ibc.get('ignore', [])

    try:
        ibb_arg_mmp['package_name_pascal_case'] = [d['name'] for d in pkg if d.get('name')][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['package_language'] = [d['language'] for d in pkg if d.get('language')][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['build_system_in_use'] = [d['runtime'] for d in bs if d.get('runtime')][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['python_version_default_for_brazil'] = [
            d['python-default'] for d in brz if d.get('python-default')
        ][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['python_versions_for_brazil'] = [d['python'] for d in brz if d.get('python')][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['venv_name'] = [d['name'] for d in vnv if d.get('name')][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['python_version_default_for_venv'] = [
            d['python-default'] for d in vnv if d.get('python-default')
        ][0]

    except Exception:
        pass

    try:
        ibb_arg_mmp['requirements_paths'] = [
            d['requirements'] for d in vnv if d.get('requirements')
        ][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['python_versions_for_venv'] = [d['python'] for d in vnv if d.get('python')][0]
    except Exception:
        pass

    try:
        ibb_arg_mmp['icarus_ignore_array'] = [i.strip() for i in ignrs]
    except Exception:
        pass

    return ibb_arg_mmp


def validate_icarus_build_cfg(ibb_arg_mmp: IbbArgMmp) -> IbbArgMmp:
    """
    Validate the icarus build config file.

    :param ibb_arg_mmp:
    :return:
    """

    accepted_build_systems = ['brazil', 'venv']
    icfg = ibb_arg_mmp['icarus_config_filename']

    if not ibb_arg_mmp.get('package_name_pascal_case'):
        raise utils.IcarusParserException(f'No package name specified in {icfg}')
    else:
        if not isinstance(ibb_arg_mmp.get('package_name_pascal_case'), str):
            raise utils.IcarusParserException(f'Package name in {icfg} must be a string')

    if not ibb_arg_mmp.get('package_language'):
        raise utils.IcarusParserException(f'No package language specified in {icfg}')
    else:
        if not isinstance(ibb_arg_mmp.get('package_language'), str):
            raise utils.IcarusParserException(f'Package language in {icfg} must be a string')

    if not ibb_arg_mmp.get('build_system_in_use'):
        raise utils.IcarusParserException(f'No build system specified in {icfg}')
    else:
        if not isinstance(ibb_arg_mmp.get('build_system_in_use'), str):
            raise utils.IcarusParserException(f'Build system in {icfg} must be a string')
        if ibb_arg_mmp.get('build_system_in_use') not in accepted_build_systems:
            raise utils.IcarusParserException(f'Invalid build system in {icfg}')

    if ibb_arg_mmp.get('build_system_in_use') == 'brazil':
        if not ibb_arg_mmp.get('python_versions_for_brazil'):
            raise utils.IcarusParserException(f'No python version(s) specified in brazil {icfg}')
        elif isinstance(ibb_arg_mmp.get('python_versions_for_brazil'), list):
            if not all(
                isinstance(v, str) for v in ibb_arg_mmp.get('python_versions_for_brazil', [])
            ):
                raise utils.IcarusParserException(
                    f'All python versions in brazil {icfg} must be strings'
                )
        else:
            raise utils.IcarusParserException(
                f'Python versions in brazil {icfg} must be a list of string'
            )

        if not ibb_arg_mmp.get('python_version_default_for_brazil'):
            raise utils.IcarusParserException(
                f'No default python version specified in brazil {icfg}'
            )
        else:
            if not isinstance(ibb_arg_mmp.get('python_version_default_for_brazil'), str):
                raise utils.IcarusParserException(
                    f'Default python version in brazil {icfg} must be a string'
                )
            if ibb_arg_mmp.get('python_version_default_for_brazil') not in ibb_arg_mmp.get(
                'python_versions_for_brazil', []
            ):
                raise utils.IcarusParserException(
                    f'Default python version in brazil {icfg} must be in the list of python'
                    ' versions'
                )

    if ibb_arg_mmp.get('build_system_in_use') == 'venv':
        if not ibb_arg_mmp.get('venv_name'):
            raise utils.IcarusParserException(f'No venv name specified in venv {icfg}')
        else:
            if not isinstance(ibb_arg_mmp.get('venv_name'), str):
                raise utils.IcarusParserException(f'Venv name in {icfg} must be a string')

        if not ibb_arg_mmp.get('python_versions_for_venv'):
            raise utils.IcarusParserException(f'No python version(s) specified in venv {icfg}')
        elif isinstance(ibb_arg_mmp.get('python_versions_for_venv'), list):
            if not all(isinstance(v, str) for v in ibb_arg_mmp.get('python_versions_for_venv', [])):
                raise utils.IcarusParserException(
                    f'All python versions in venv {icfg} must be strings'
                )
        else:
            raise utils.IcarusParserException(
                f'Python versions in venv {icfg} must be a list of string'
            )

        if not ibb_arg_mmp.get('python_version_default_for_venv'):
            raise utils.IcarusParserException(f'No default python version specified in venv {icfg}')
        else:
            if not isinstance(ibb_arg_mmp.get('python_version_default_for_venv'), str):
                raise utils.IcarusParserException(
                    f'Default python version in venv {icfg} must be a string'
                )
            if ibb_arg_mmp.get('python_version_default_for_venv') not in ibb_arg_mmp.get(
                'python_versions_for_venv', []
            ):
                raise utils.IcarusParserException(
                    f'Default python version in venv {icfg} must be in the list of python versions'
                )

        if not ibb_arg_mmp.get('requirements_paths'):
            # not a mandatory field
            pass
        elif isinstance(ibb_arg_mmp.get('requirements_paths'), list):
            if not all(isinstance(v, str) for v in ibb_arg_mmp.get('requirements_paths', [])):
                raise utils.IcarusParserException(
                    f'All requirements path array in venv {icfg} must be strings'
                )
        else:
            if not isinstance(ibb_arg_mmp.get('requirements_paths'), list):
                raise utils.IcarusParserException(
                    f'Requirements path array in venv {icfg} must be a list of strings'
                )

    if not ibb_arg_mmp.get('icarus_ignore_array'):
        # not a mandatory field
        pass
    elif isinstance(ibb_arg_mmp.get('icarus_ignore_array'), list):
        if not all(isinstance(v, str) for v in ibb_arg_mmp.get('icarus_ignore_array', [])):
            raise utils.IcarusParserException(f'All icarus ignore array in {icfg} must be strings')
    else:
        if not isinstance(ibb_arg_mmp.get('icarus_ignore_array'), list):
            raise utils.IcarusParserException(
                f'Icarus ignore array in {icfg} must be a list of string'
            )

    return ibb_arg_mmp


def normalize_and_set_defaults_icarus_build_cfg(ibb_arg_mmp: IbbArgMmp) -> IbbArgMmp:
    """
    Normalize the ibb_arg_mmp to be used in the python script.

    :param ibb_arg_mmp:
    :return:
    """

    stru = mylib.StringUtils()
    skey = lambda v: int(''.join([i for i in str(v).split('.')]))  # noqa
    icfg = ibb_arg_mmp['icarus_config_filename']

    # Optional settings will get here as None, set defaults
    if ibb_arg_mmp.get('requirements_paths') is None:
        ibb_arg_mmp['requirements_paths'] = []
    if ibb_arg_mmp.get('icarus_ignore_array') is None:
        ibb_arg_mmp['icarus_ignore_array'] = []

    # Add pkg name snake anf dashed
    try:
        ibb_arg_mmp['package_name_snake_case'] = stru.snake_case(
            ibb_arg_mmp['package_name_pascal_case']
        )
        ibb_arg_mmp['package_name_dashed'] = ibb_arg_mmp['package_name_snake_case'].replace(
            "_", "-"
        )
    except Exception:
        raise utils.IcarusParserException(f"Invalid package name in {icfg}")

    # Remove duplicates and sort from newest to oldest version
    ibb_arg_mmp['python_versions_for_brazil'] = sorted(
        list(set(ibb_arg_mmp['python_versions_for_brazil'])), key=skey, reverse=True
    )
    ibb_arg_mmp['python_versions_for_venv'] = sorted(
        list(set(ibb_arg_mmp['python_versions_for_venv'])), key=skey, reverse=True
    )
    ibb_arg_mmp['icarus_ignore_array'] = list(set(ibb_arg_mmp['icarus_ignore_array']))
    ibb_arg_mmp['requirements_paths'] = list(set(ibb_arg_mmp['requirements_paths']))

    return ibb_arg_mmp


def convert_ibb_arg_mmp_to_ibb_argv(ibb_arg_mmp: IbbArgMmp) -> str:
    """
    Convert a dictionary to a bash ibb_arg_mmp string.

    :param ibb_arg_mmp:
    :return:
    """

    temp_ibb_arg_mmp = {}

    module_logger.debug('*' * 50)

    for k, v in ibb_arg_mmp.items():
        if not (isinstance(v, str) or isinstance(v, list) or isinstance(v, tuple)):
            raise utils.IcarusParserException(f"Invalid type for `{k}`")

        if isinstance(v, str):
            temp_ibb_arg_mmp[k] = repr(v)
        if isinstance(v, tuple):
            v = list(v)
        if isinstance(v, list):
            temp_ibb_arg_mmp[k] = f"( {' '.join(repr(el) for el in v)} )"

        module_logger.debug(f"ibb_arg_mmp -> {k}={temp_ibb_arg_mmp[k]}")

    module_logger.debug('*' * 50)

    ibb_arg_mmp_str = ' '.join([f"{k}={v}" for k, v in temp_ibb_arg_mmp.items()])

    return ibb_arg_mmp_str
