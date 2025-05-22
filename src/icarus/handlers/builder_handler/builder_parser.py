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


def process_icarus_build_config() -> str:
    config_filename = 'icarus.cfg'
    empty_string = repr('')
    empty_array = repr([]).replace('[', '( ').replace(']', ' )').replace('\',', '\'')

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
    mmp = {
        'icarus_config_filename': repr(config_filename),
        'icarus_config_filepath': repr(config_filepath),
        'project_root_dir_abs': repr(pwd),
    }

    mmp = parse_icarus_build_config(
        mmp=mmp,
        icarus_config_filepath=config_filepath,
        empty_string=empty_string,
        empty_array=empty_array,
    )
    mmp = validate_icarus_build_config(
        mmp=mmp,
        icarus_config_filename=config_filename,
        empty_string=empty_string,
        empty_array=empty_array,
    )

    args_from_python_script_validator_str = normalize_args_from_python_script(mmp)

    return args_from_python_script_validator_str


def parse_icarus_build_config(
    mmp: dict[str, str], icarus_config_filepath: str, empty_string: str, empty_array: str
) -> dict[str, str]:
    with open(icarus_config_filepath) as icarus_build_config:
        ibc = yaml.safe_load(icarus_build_config)

    pkg = ibc.get('package', [])
    bs = ibc.get('build-system', [])
    brz = ibc.get('brazil', [])
    vnv = ibc.get('venv', [])
    ignrs = ibc.get('ignore', [])

    try:
        mmp['package_name_pascal_case'] = repr(str([d['name'] for d in pkg if d.get('name')][0]))
    except Exception:
        mmp['package_name_pascal_case'] = empty_string

    try:
        mmp['package_language'] = repr(str([d['language'] for d in pkg if d.get('language')][0]))
    except Exception:
        mmp['package_language'] = empty_string

    try:
        mmp['build_system_in_use'] = repr(str([d['runtime'] for d in bs if d.get('runtime')][0]))
    except Exception:
        mmp['build_system_in_use'] = empty_string

    try:
        mmp['python_version_default_for_brazil'] = repr(
            str([d['python-default'] for d in brz if d.get('python-default')][0])
        )
    except Exception:
        mmp['python_version_default_for_brazil'] = empty_string

    try:
        mmp['python_versions_for_brazil'] = (
            repr([
                str(el).strip()
                for el in [sorted(d['python'], reverse=True) for d in brz if d.get('python')][0]
            ])
            .replace('[', '( ')
            .replace(']', ' )')
            .replace('\',', '\'')
        )
    except Exception:
        mmp['python_versions_for_brazil'] = empty_array

    try:
        mmp['venv_name'] = repr(str([d['name'] for d in vnv if d.get('name')][0]))
    except Exception:
        mmp['venv_name'] = empty_string

    try:
        mmp['python_version_default_for_venv'] = repr(
            str([d['python-default'] for d in vnv if d.get('python-default')][0])
        )
    except Exception:
        mmp['python_version_default_for_venv'] = empty_string

    try:
        mmp['requirements_path'] = repr(
            str([d['requirements'] for d in vnv if d.get('requirements')][0])
        )
    except Exception:
        mmp['requirements_path'] = empty_string

    try:
        mmp['python_versions_for_venv'] = (
            repr([
                str(el).strip()
                for el in [sorted(d['python'], reverse=True) for d in vnv if d.get('python')][0]
            ])
            .replace('[', '( ')
            .replace(']', ' )')
            .replace('\',', '\'')
        )
    except Exception:
        mmp['python_versions_for_venv'] = empty_array

    try:
        mmp['icarus_ignore_array'] = (
            repr([i.strip() for i in ignrs])
            .replace('[', '( ')
            .replace(']', ' )')
            .replace('\',', '\'')
        )
    except Exception:
        mmp['icarus_ignore_array'] = empty_array

    return mmp


def validate_icarus_build_config(
    mmp: dict[str, str], icarus_config_filename: str, empty_string: str, empty_array: str
) -> dict[str, str]:

    icfg = icarus_config_filename
    stru = mylib.StringUtils()

    if mmp.get("package_name_pascal_case") == empty_string:
        raise utils.IcarusParserException(f"No project name specified in {icfg}")
    else:
        try:
            mmp.update({
                'package_name_snake_case': repr(
                    stru.snake_case(mmp['package_name_pascal_case'][1:-1])
                )
            })
        except Exception:
            raise utils.IcarusParserException(f"Invalid project name in {icfg}")
        mmp.update({'package_name_dashed': mmp['package_name_snake_case'].replace("_", "-")})

    if mmp.get("package_language") == empty_string:
        raise utils.IcarusParserException(f"No package language specified in {icfg}")

    if mmp.get("build_system_in_use") == empty_string:
        raise utils.IcarusParserException(f"No build system specified in {icfg}")

    if mmp.get("build_system_in_use") == "'brazil'":
        python_versions = mmp.get("python_versions_for_brazil")
        default_version = mmp.get("python_version_default_for_brazil")

        if python_versions == empty_array:
            raise utils.IcarusParserException(f"No python version(s) specified in brazil {icfg}")
        if default_version == empty_string:
            raise utils.IcarusParserException(
                f"No default python version specified in brazil {icfg}"
            )

    elif mmp.get("build_system_in_use") == "'venv'":
        if mmp.get("venv_name") == empty_string:
            raise utils.IcarusParserException(f"No venv name specified in venv {icfg}")
        if mmp.get("python_versions_for_venv") == empty_array:
            raise utils.IcarusParserException(f"No python version(s) specified in venv {icfg}")
        if mmp.get("python_version_default_for_venv") == empty_string:
            raise utils.IcarusParserException(f"No default python version specified in venv {icfg}")
        if mmp.get("requirements_path") == empty_string:
            # not a mandatory field
            pass
    else:
        raise utils.IcarusParserException(f"Invalid build system in {icfg}")

    return mmp


def normalize_args_from_python_script(mmp: dict[str, str]) -> str:
    args_from_python_script_validator_str = ' '.join([f"{k}={v}" for k, v in mmp.items()])

    return args_from_python_script_validator_str
