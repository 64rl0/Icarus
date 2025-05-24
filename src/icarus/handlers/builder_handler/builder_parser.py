# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/builder_parser.py
# Created 1/19/25 - 3:58 PM UK Time (London) by carlogtt
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
from typing import Literal, TypedDict

# Third Party Library Imports
import yaml

# My Library Imports
import carlogtt_python_library as mylib

# Local Folder (Relative) Imports
from ... import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = ['handle_builder_command']

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def handle_builder_command(args: argparse.Namespace) -> int:
    """
    Handle execution of subcommands under the 'builder' top-level
    command.

    This function routes the parsed arguments to the appropriate logic
    based on the value of the `builder_command` argument.

    :param args: The parsed arguments containing the `builder_command`
        and any associated options or parameters.
    :return: Exit code of the script.
    :raise ValueError: If an unknown `builder_command` is provided.
    """

    if args.builder_command == 'dotfiles-update':
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'dotfiles_update.sh'
        script_args = None

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.builder_command == 'create':
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'create.sh'
        script_args = [args.n, args.l]

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    elif args.builder_command == 'build':
        module_logger.debug(f"Running {args.builder_command=}")

        script_path = config.CLI_SCRIPTS_DIR / 'builder_handler' / 'build.sh'
        script_args = prepare_script_args(args=args)

        return_code = utils.run_bash_script(script_path=script_path, script_args=script_args)

        return return_code

    else:
        module_logger.debug(f"Running {args.builder_command=}")
        raise utils.IcarusParserException('the following arguments are required: <subcommand>')


class KwArgs(TypedDict):
    icarus_config_filename: str
    icarus_config_filepath: str
    project_root_dir_abs: str
    package_name_pascal_case: str
    package_name_snake_case: str
    package_name_dashed: str
    package_language: str
    build_system_in_use: str
    python_version_default_for_brazil: str
    python_versions_for_brazil: list
    venv_name: str
    python_version_default_for_venv: str
    python_versions_for_venv: list
    requirements_path: str
    icarus_ignore_array: list
    build: str
    is_only_build_hook: str
    clean: str
    isort: str
    black: str
    flake8: str
    mypy: str
    shfmt: str
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
        Literal['whitespaces'],
        Literal['trailing'],
        Literal['eofnewline'],
        Literal['gitleaks'],
        Literal['pytest'],
        Literal['docs'],
        Literal['exec'],
    ]


def prepare_script_args(args: argparse.Namespace) -> list[str]:
    """
    Prepare the arguments for the build.sh script.

    This function takes the parsed arguments and prepares them for the
    build.sh script to eval them and set as script variables.

    :param args:
    :return:
    """

    # Clean the args to remove the unutilized args
    script_args = [
        args.build,
        args.clean,
        args.isort,
        args.black,
        args.flake8,
        args.mypy,
        args.shfmt,
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

    # Initial validations
    if args.clean and sum(1 for el in script_args if el) > 1:
        raise utils.IcarusParserException('--clean is a standalone argument and must be used alone')
    if args.exec and sum(1 for el in script_args if el) > 1:
        raise utils.IcarusParserException('--exec is a standalone argument and must be used alone')
    if not any(script_args):
        raise utils.IcarusParserException(
            f'{config.CLI_NAME} builder build requires at least one argument'
        )

    kwargs: KwArgs = {
        'all_hooks': (
            'build',
            'clean',
            'isort',
            'black',
            'flake8',
            'mypy',
            'shfmt',
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
        'python_version_default_for_brazil': '',
        'python_versions_for_brazil': [],
        'venv_name': '',
        'python_version_default_for_venv': '',
        'python_versions_for_venv': [],
        'requirements_path': '',
        'icarus_ignore_array': [],
        'build': 'Y' if args.build else 'N',
        'is_only_build_hook': 'N',
        'clean': 'Y' if args.clean else 'N',
        'isort': 'Y' if args.isort else 'N',
        'black': 'Y' if args.black else 'N',
        'flake8': 'Y' if args.flake8 else 'N',
        'mypy': 'Y' if args.mypy else 'N',
        'shfmt': 'Y' if args.shfmt else 'N',
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

    kwargs = process_icarus_build_config(kwargs=kwargs)
    kwargs = parse_icarus_build_config(kwargs=kwargs)
    kwargs = validate_icarus_build_config(kwargs=kwargs)

    if args.exec:
        if len(args.exec) == 1:
            initial_exec_command_received = args.exec[0].split()
        elif len(args.exec) > 1:
            initial_exec_command_received = args.exec
        else:
            raise utils.IcarusParserException('Invalid --exec argument')
        kwargs.update({'initial_exec_command_received': initial_exec_command_received})
        # altering the args.exec value so it can be used from the
        # for loop here below to make up the initial_command_received
        script_args[13] = f"--exec {' '.join(args.exec)}"

    if args.release:
        if kwargs['build_system_in_use'] in {'brazil', 'venv'}:
            kwargs.update({
                'build': 'Y',
                'isort': 'Y',
                'black': 'Y',
                'flake8': 'Y',
                'mypy': 'Y',
                'shfmt': 'Y',
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
        if kwargs['build_system_in_use'] in {'brazil', 'venv'}:
            kwargs.update({
                'isort': 'Y',
                'black': 'Y',
                'flake8': 'Y',
                'mypy': 'Y',
                'shfmt': 'Y',
                'whitespaces': 'Y',
                'trailing': 'Y',
                'eofnewline': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --format argument is only valid for brazil or venv build systems'
            )

    if args.test:
        if kwargs['build_system_in_use'] in {'brazil', 'venv'}:
            kwargs.update({
                'pytest': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --test argument is only valid for brazil or venv build systems'
            )

    for arg in script_args:
        if arg:
            kwargs['initial_command_received'] += f" {arg}"

    for hook in kwargs['all_hooks']:
        if kwargs[hook] == 'Y':
            kwargs['running_hooks_name'].append(hook)

    kwargs['running_hooks_count'] = str(len(kwargs['running_hooks_name']))

    if kwargs['build'] == 'Y' and kwargs['running_hooks_count'] == 1:
        kwargs['is_only_build_hook'] = 'Y'

    kwargs = normalize_args_from_python_script(kwargs=kwargs)
    kwargs_str = convert_dict_to_bash_kwargs_string(kwargs=kwargs)
    list_kwargs_str = [kwargs_str]

    return list_kwargs_str


def process_icarus_build_config(kwargs: KwArgs) -> KwArgs:
    """
    Process the icarus build config file and return a string with
    all the kwargs to be then eval from the sh script.

    :return:
    """

    config_filename = 'icarus.cfg'

    while (pwd := os.getcwd()) != '/':
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

    kwargs['icarus_config_filename'] = config_filename
    kwargs['icarus_config_filepath'] = config_filepath
    kwargs['project_root_dir_abs'] = pwd

    return kwargs


def parse_icarus_build_config(kwargs: KwArgs) -> KwArgs:
    """
    Parse the icarus build config file.

    :param kwargs:
    :return:
    """

    try:
        with open(kwargs['icarus_config_filepath']) as icarus_build_config:
            ibc = yaml.safe_load(icarus_build_config)
    except Exception as e:
        raise utils.IcarusParserException(
            f"Error parsing {kwargs['icarus_config_filepath']}\n               {repr(e)}"
        )

    pkg = ibc.get('package', [])
    bs = ibc.get('build-system', [])
    brz = ibc.get('brazil', [])
    vnv = ibc.get('venv', [])
    ignrs = ibc.get('ignore', [])

    try:
        kwargs['package_name_pascal_case'] = [d['name'] for d in pkg if d.get('name')][0]
    except Exception:
        pass

    try:
        kwargs['package_language'] = [d['language'] for d in pkg if d.get('language')][0]
    except Exception:
        pass

    try:
        kwargs['build_system_in_use'] = [d['runtime'] for d in bs if d.get('runtime')][0]
    except Exception:
        pass

    try:
        kwargs['python_version_default_for_brazil'] = [
            d['python-default'] for d in brz if d.get('python-default')
        ][0]
    except Exception:
        pass

    try:
        kwargs['python_versions_for_brazil'] = [d['python'] for d in brz if d.get('python')][0]
    except Exception:
        pass

    try:
        kwargs['venv_name'] = [d['name'] for d in vnv if d.get('name')][0]
    except Exception:
        pass

    try:
        kwargs['python_version_default_for_venv'] = [
            d['python-default'] for d in vnv if d.get('python-default')
        ][0]

    except Exception:
        pass

    try:
        kwargs['requirements_path'] = [d['requirements'] for d in vnv if d.get('requirements')][0]
    except Exception:
        pass

    try:
        kwargs['python_versions_for_venv'] = [d['python'] for d in vnv if d.get('python')][0]
    except Exception:
        pass

    try:
        kwargs['icarus_ignore_array'] = [i.strip() for i in ignrs]
    except Exception:
        pass

    return kwargs


def validate_icarus_build_config(kwargs: KwArgs) -> KwArgs:
    """
    Validate the icarus build config file.

    :param kwargs:
    :return:
    """

    accepted_build_systems = ['brazil', 'venv']
    icfg = kwargs['icarus_config_filename']

    if not kwargs.get("package_name_pascal_case"):
        raise utils.IcarusParserException(f"No package name specified in {icfg}")
    else:
        if not isinstance(kwargs.get('package_name_pascal_case'), str):
            raise utils.IcarusParserException(f"Package name in {icfg} must be a string")

    if not kwargs.get("package_language"):
        raise utils.IcarusParserException(f"No package language specified in {icfg}")
    else:
        if not isinstance(kwargs.get('package_language'), str):
            raise utils.IcarusParserException(f"Package language in {icfg} must be a string")

    if not kwargs.get("build_system_in_use"):
        raise utils.IcarusParserException(f"No build system specified in {icfg}")
    else:
        if not isinstance(kwargs.get('build_system_in_use'), str):
            raise utils.IcarusParserException(f"Build system in {icfg} must be a string")
        if kwargs.get("build_system_in_use") not in accepted_build_systems:
            raise utils.IcarusParserException(f"Invalid build system in {icfg}")

    if kwargs.get("build_system_in_use") == 'brazil':
        if not kwargs.get("python_versions_for_brazil"):
            raise utils.IcarusParserException(f"No python version(s) specified in brazil {icfg}")
        elif isinstance(kwargs.get("python_versions_for_brazil"), list):
            if not all(isinstance(v, str) for v in kwargs.get("python_versions_for_brazil", [])):
                raise utils.IcarusParserException(
                    f"All python versions in brazil {icfg} must be strings"
                )
        else:
            raise utils.IcarusParserException(
                f"Python versions in brazil {icfg} must be a list of string"
            )

        if not kwargs.get("python_version_default_for_brazil"):
            raise utils.IcarusParserException(
                f"No default python version specified in brazil {icfg}"
            )
        else:
            if not isinstance(kwargs.get("python_version_default_for_brazil"), str):
                raise utils.IcarusParserException(
                    f"Default python version in brazil {icfg} must be a string"
                )
            if kwargs.get("python_version_default_for_brazil") not in kwargs.get(
                "python_versions_for_brazil", []
            ):
                raise utils.IcarusParserException(
                    f"Default python version in brazil {icfg} must be in the list of python"
                    " versions"
                )

    if kwargs.get("build_system_in_use") == 'venv':
        if not kwargs.get("venv_name"):
            raise utils.IcarusParserException(f"No venv name specified in venv {icfg}")
        else:
            if not isinstance(kwargs.get('venv_name'), str):
                raise utils.IcarusParserException(f"Venv name in {icfg} must be a string")

        if not kwargs.get("python_versions_for_venv"):
            raise utils.IcarusParserException(f"No python version(s) specified in venv {icfg}")
        elif isinstance(kwargs.get("python_versions_for_venv"), list):
            if not all(isinstance(v, str) for v in kwargs.get("python_versions_for_venv", [])):
                raise utils.IcarusParserException(
                    f"All python versions in venv {icfg} must be strings"
                )
        else:
            raise utils.IcarusParserException(
                f"Python versions in venv {icfg} must be a list of string"
            )

        if not kwargs.get("python_version_default_for_venv"):
            raise utils.IcarusParserException(f"No default python version specified in venv {icfg}")
        else:
            if not isinstance(kwargs.get("python_version_default_for_venv"), str):
                raise utils.IcarusParserException(
                    f"Default python version in {icfg} must be a string"
                )
            if kwargs.get("python_version_default_for_venv") not in kwargs.get(
                "python_versions_for_venv", []
            ):
                raise utils.IcarusParserException(
                    f"Default python version in venv {icfg} must be in the list of python versions"
                )

        if not kwargs.get("requirements_path"):
            # not a mandatory field
            pass
        else:
            if not isinstance(kwargs.get('requirements_path'), str):
                raise utils.IcarusParserException(f"Requirements path in {icfg} must be a string")

    if not kwargs.get("icarus_ignore_array"):
        # not a mandatory field
        pass
    elif isinstance(kwargs.get("icarus_ignore_array"), list):
        if not all(isinstance(v, str) for v in kwargs.get("icarus_ignore_array", [])):
            raise utils.IcarusParserException(f"All icarus ignore array in {icfg} must be strings")
    else:
        if not isinstance(kwargs.get("icarus_ignore_array"), list):
            raise utils.IcarusParserException(
                f"Icarus ignore array in {icfg} must be a list of string"
            )

    return kwargs


def normalize_args_from_python_script(kwargs: KwArgs) -> KwArgs:
    """
    Normalize the kwargs to be used in the python script.

    :param kwargs:
    :return:
    """

    stru = mylib.StringUtils()
    skey = lambda v: int(''.join([i for i in str(v).split('.')]))  # noqa
    icfg = kwargs['icarus_config_filename']

    # Optional settings will get here as None, set defaults
    if kwargs.get('requirements_path') is None:
        kwargs['requirements_path'] = ''
    if kwargs.get('icarus_ignore_array') is None:
        kwargs['icarus_ignore_array'] = []

    # Add pkg name snake anf dashed
    try:
        kwargs['package_name_snake_case'] = stru.snake_case(kwargs['package_name_pascal_case'])
        kwargs['package_name_dashed'] = kwargs['package_name_snake_case'].replace("_", "-")
    except Exception:
        raise utils.IcarusParserException(f"Invalid package name in {icfg}")

    # Remove duplicates and sort from newest to oldest version
    kwargs['python_versions_for_brazil'] = sorted(
        list(set(kwargs['python_versions_for_brazil'])), key=skey, reverse=True
    )
    kwargs['python_versions_for_venv'] = sorted(
        list(set(kwargs['python_versions_for_venv'])), key=skey, reverse=True
    )
    kwargs['icarus_ignore_array'] = list(set(kwargs['icarus_ignore_array']))

    return kwargs


def convert_dict_to_bash_kwargs_string(kwargs: KwArgs) -> str:
    """
    Convert a dictionary to a bash kwargs string.

    :param kwargs:
    :return:
    """

    temp_kwargs = {}

    module_logger.debug('*' * 50)

    for k, v in kwargs.items():
        if not (isinstance(v, str) or isinstance(v, list) or isinstance(v, tuple)):
            raise utils.IcarusParserException(f"Invalid type for `{k}`")

        if isinstance(v, str):
            temp_kwargs[k] = repr(v)
        if isinstance(v, tuple):
            v = list(v)
        if isinstance(v, list):
            temp_kwargs[k] = f"( {' '.join(repr(el) for el in v)} )"

        module_logger.debug(f"kwargs -> {k}={temp_kwargs[k]}")

    module_logger.debug('*' * 50)

    kwargs_str = ' '.join([f"{k}={v}" for k, v in temp_kwargs.items()])

    return kwargs_str
