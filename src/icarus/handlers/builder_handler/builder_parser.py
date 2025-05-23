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
from typing import TypedDict

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
            f"--exec {args.exec}" if args.exec else '',
            args.release,
            args.format,
            args.test,
        ]

        if args.exec:
            for arg in script_args:
                if arg and arg != f"--exec {args.exec}":
                    print(arg)
                    raise utils.IcarusParserException(
                        '--exec is a standalone argument and must be used alone'
                    )

            if script_args[16] == '--exec --exec':
                raise utils.IcarusParserException(
                    '--exec requires at least one argument to execute'
                )

        if args.clean:
            for arg in script_args:
                if arg and arg != '--clean':
                    raise utils.IcarusParserException(
                        '--clean is a standalone argument and must be used alone'
                    )

        if not any(script_args):
            raise utils.IcarusParserException(
                f'{config.CLI_NAME} builder build requires at least one argument'
            )

        script_args.append(process_icarus_build_config())

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


def process_icarus_build_config() -> str:
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
    kwargs: KwArgs = {
        'icarus_config_filename': config_filename,
        'icarus_config_filepath': config_filepath,
        'project_root_dir_abs': pwd,
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
    }

    kwargs = parse_icarus_build_config(kwargs=kwargs)
    kwargs = validate_icarus_build_config(kwargs=kwargs)
    kwargs_str = normalize_args_from_python_script(kwargs=kwargs)

    return kwargs_str


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


def normalize_args_from_python_script(kwargs: KwArgs) -> str:
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

    temp_kwargs = {}
    for k, v in kwargs.items():
        if isinstance(v, str):
            temp_kwargs[k] = repr(v)
        elif isinstance(v, list):
            temp_kwargs[k] = repr(v).replace('[', '( ').replace(']', ' )').replace('\',', '\'')
        else:
            raise utils.IcarusParserException(f"Invalid value for {k} in {icfg}")

    kwargs_str = ' '.join([f"{k}={v}" for k, v in temp_kwargs.items()])

    return kwargs_str
