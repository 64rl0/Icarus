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
import errno
import fcntl
import getpass
import json
import os
import pathlib
import re
import time
from typing import IO, Literal, Optional, TypedDict, Union

# Third Party Library Imports
import requests
import yaml

# My Library Imports
import carlogtt_python_library as mylib

# Local Application Imports
from icarus import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'get_argv',
    'ensure_builder_control_plane',
    'acquire_builder_lock',
    'release_builder_lock',
    'run_bash_script_with_logging',
]

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
    build_root_dir: str
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


def ensure_builder_control_plane() -> None:
    """
    Ensure the builder control plane directories exist in the project.
    """

    project_root_dir_abs = _find_project_root_dir()

    control_plane_dir = pathlib.Path(project_root_dir_abs) / config.ICARUS_CONTROL_PLANE_DIRNAME
    log_dir = control_plane_dir / config.ICARUS_LOG_DIRNAME
    lock_dir = control_plane_dir / config.ICARUS_LOCK_DIRNAME

    for path in (control_plane_dir, log_dir, lock_dir):
        path.mkdir(parents=True, exist_ok=True)


def acquire_builder_lock() -> IO[str]:
    """
    Acquire an exclusive builder lock for the project.

    :return: A handle for the acquired lock.
    """

    lock_path = (
        pathlib.Path(_find_project_root_dir())
        / config.ICARUS_CONTROL_PLANE_DIRNAME
        / config.ICARUS_LOCK_DIRNAME
        / config.ICARUS_BUILDER_LOCK_FILENAME
    )

    lock_handle = open(lock_path, 'a+', encoding='utf-8')
    try:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as ex:
        lock_handle.close()
        if ex.errno in {errno.EACCES, errno.EAGAIN, errno.EWOULDBLOCK}:
            raise utils.IcarusParserException(
                f'Icarus builder is already running. Lock file: {lock_path}'
            )
        raise

    lock_content = json.dumps({
        "pid": os.getpid(),
        "user": getpass.getuser() or 'unknown',
        "started": time.strftime('%Y-%m-%d %H:%M:%S %Z'),
    })

    lock_handle.seek(0)
    lock_handle.truncate()
    lock_handle.write(lock_content)
    lock_handle.flush()

    return lock_handle


def release_builder_lock(lock_handle: Optional[IO[str]]) -> None:
    """
    Release the builder lock and remove the lock file.

    :param lock_handle: A handle for the lock to be released.
    """

    if lock_handle is None:
        return

    try:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_UN)
    finally:
        lock_handle.close()


def run_bash_script_with_logging(
    script_path: Union[str, pathlib.Path],
    script_args: Optional[list[str]],
) -> int:
    """
    Run a Bash script, log trace, and persist error logs on failure.

    :param script_path:
    :param script_args:
    :return: Exit code of the Bash script.
    """

    log_dir = (
        pathlib.Path(_find_project_root_dir())
        / config.ICARUS_CONTROL_PLANE_DIRNAME
        / config.ICARUS_LOG_DIRNAME
    )

    start_time = time.time()
    start_time_iso = datetime.datetime.fromtimestamp(start_time, config.SYSTEM_TZ).isoformat()
    run_id = f"{int(start_time)}_{os.getpid()}"
    run_log_path = log_dir / f"{run_id}.log"
    trace_log_path = log_dir / config.ICARUS_TRACE_LOG_FILENAME

    return_code = utils.run_bash_script(
        script_path=script_path, script_args=script_args, log_path=run_log_path
    )

    end_time = time.time()
    end_time_iso = datetime.datetime.fromtimestamp(end_time, config.SYSTEM_TZ).isoformat()
    duration_seconds = round(end_time - start_time, 3)

    trace_log = {
        'cwd': os.getcwd(),
        'command': str(script_path),
        'command_args': script_args,
        'pid': os.getpid(),
        'run_id': run_id,
        'return_code': return_code,
        'start_time': start_time_iso,
        'end_time': end_time_iso,
        'duration_seconds': duration_seconds,
    }
    with open(trace_log_path, 'a', encoding='utf-8') as trace_log_handle:
        json.dump(trace_log, trace_log_handle)
        trace_log_handle.write('\n')

    # Keep the log file if the command was successful
    if return_code == 0:
        run_log_path.unlink(missing_ok=True)

    return return_code


def get_argv(ib_args: dict[str, Union[str, list[str]]]) -> str:
    """
    Get the arguments for the builder.sh script.

    :param ib_args:
    :return: The arguments for the builder.sh script.
    """

    _validate_build_cli_args_base_rules(ib_args=ib_args)

    ib_arg_mmp = _initialize_ib_arg_mmp(ib_args=ib_args)
    ib_arg_mmp = _read_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = _parse_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = _validate_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = _process_ib_args(ib_arg_mmp=ib_arg_mmp, ib_args=ib_args)
    ib_arg_mmp = _normalize_and_set_defaults_icarus_build_cfg(ib_arg_mmp=ib_arg_mmp)
    ib_arg_mmp = _normalize_and_set_python_version(ib_arg_mmp=ib_arg_mmp)

    ib_argv = _convert_ib_arg_mmp_to_ib_argv(ib_arg_mmp=ib_arg_mmp)

    return ib_argv


def _initialize_ib_arg_mmp(ib_args: dict[str, Union[str, list[str]]]) -> IbArgMmp:
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
        'build_root_dir': '',
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


def _validate_build_cli_args_base_rules(ib_args: dict[str, Union[str, list[str]]]) -> None:
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


def _process_ib_args(ib_arg_mmp: IbArgMmp, ib_args: dict[str, Union[str, list[str]]]) -> IbArgMmp:
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
        if ib_arg_mmp['build_system_in_use'] in {'icarus-python3'}:
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
                'The --release argument is only valid for icarus-python3 build systems'
            )

    if ib_args.get('format'):
        if ib_arg_mmp['build_system_in_use'] in {'icarus-python3'}:
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
                'The --format argument is only valid for icarus-python3 build systems'
            )

    if ib_args.get('test'):
        if ib_arg_mmp['build_system_in_use'] in {'icarus-python3'}:
            ib_arg_mmp.update({
                'pytest': 'Y',
            })
        else:
            raise utils.IcarusParserException(
                'The --test argument is only valid for icarus-python3 build systems'
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


def _read_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Process the icarus build config file and return a string with
    all the ib_arg_mmp to be then eval from the sh script.

    :param ib_arg_mmp:
    :return:
    """

    project_root_dir_abs = _find_project_root_dir()
    config_filepath = os.path.join(project_root_dir_abs, config.ICARUS_CFG_FILENAME)

    ib_arg_mmp['icarus_config_filename'] = config.ICARUS_CFG_FILENAME
    ib_arg_mmp['icarus_config_filepath'] = config_filepath
    ib_arg_mmp['project_root_dir_abs'] = project_root_dir_abs

    return ib_arg_mmp


def _parse_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
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
    ipy = ibc.get('icarus-python3', [])
    icdk = ibc.get('icarus-cdk', [])  # noqa
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
        ib_arg_mmp['build_root_dir'] = [d['build-root'] for d in bs if d.get('build-root')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['python_version_default_for_icarus'] = [
            d['python-default'] for d in ipy if d.get('python-default')
        ][0]

    except Exception:
        pass

    try:
        ib_arg_mmp['python_versions_for_icarus'] = [d['python'] for d in ipy if d.get('python')][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['requirements_paths'] = [
            d['requirements'] for d in ipy if d.get('requirements')
        ][0]
    except Exception:
        pass

    try:
        ib_arg_mmp['icarus_ignore_array'] = [i.strip() for i in ignrs]
    except Exception:
        pass

    return ib_arg_mmp


def _validate_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Validate the icarus build config file.

    :param ib_arg_mmp:
    :return:
    """

    accepted_build_systems = ['icarus-python3', 'icarus-cdk']

    if not ib_arg_mmp.get('package_name_pascal_case'):
        raise utils.IcarusParserException(
            f'No name specified in package {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('package_name_pascal_case'), str):
            raise utils.IcarusParserException(
                f'name in package {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if not ib_arg_mmp.get('package_language'):
        raise utils.IcarusParserException(
            f'No language specified in package {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('package_language'), str):
            raise utils.IcarusParserException(
                f'language in package {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if not ib_arg_mmp.get('build_system_in_use'):
        raise utils.IcarusParserException(
            f'No runtime specified in build-system {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('build_system_in_use'), str):
            raise utils.IcarusParserException(
                f'runtime in build-system {config.ICARUS_CFG_FILENAME} must be a string'
            )
        if ib_arg_mmp.get('build_system_in_use') not in accepted_build_systems:
            raise utils.IcarusParserException(
                f'Invalid runtime in build-system {config.ICARUS_CFG_FILENAME}'
            )

    if not ib_arg_mmp.get('build_root_dir'):
        raise utils.IcarusParserException(
            f'No build-root specified in build-system {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg_mmp.get('build_root_dir'), str):
            raise utils.IcarusParserException(
                f'build-root in build-system {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if ib_arg_mmp.get('build_system_in_use') == 'icarus-python3':
        if not ib_arg_mmp.get('python_versions_for_icarus'):
            raise utils.IcarusParserException(
                f'No python version(s) specified in icarus-python3 {config.ICARUS_CFG_FILENAME}'
            )
        elif isinstance(ib_arg_mmp.get('python_versions_for_icarus'), list):
            if not all(
                isinstance(v, str) for v in ib_arg_mmp.get('python_versions_for_icarus', [])
            ):
                raise utils.IcarusParserException(
                    f'All python version(s) in icarus-python3 {config.ICARUS_CFG_FILENAME} must be'
                    ' strings'
                )
            if not all(
                len(v.split('.')) in {2, 3}
                for v in ib_arg_mmp.get('python_versions_for_icarus', [])
            ):
                raise utils.IcarusParserException(
                    f'All python version(s) in icarus-python3 {config.ICARUS_CFG_FILENAME} must be'
                    ' valid'
                )
        else:
            raise utils.IcarusParserException(
                f'Python version(s) in icarus-python3 {config.ICARUS_CFG_FILENAME} must be a list'
                ' of string'
            )

        if not ib_arg_mmp.get('python_version_default_for_icarus'):
            raise utils.IcarusParserException(
                'No python-default version specified in icarus-python3'
                f' {config.ICARUS_CFG_FILENAME}'
            )
        else:
            if not isinstance(ib_arg_mmp.get('python_version_default_for_icarus'), str):
                raise utils.IcarusParserException(
                    f'python-default version in icarus-python3 {config.ICARUS_CFG_FILENAME} must be'
                    ' a string'
                )
            if len(ib_arg_mmp.get('python_version_default_for_icarus', '').split('.')) not in {
                2,
                3,
            }:
                raise utils.IcarusParserException(
                    f'Invalid python-default version in icarus-python3 {config.ICARUS_CFG_FILENAME}'
                )
            if ib_arg_mmp.get('python_version_default_for_icarus') not in ib_arg_mmp.get(
                'python_versions_for_icarus', []
            ):
                raise utils.IcarusParserException(
                    f'python-default version in icarus-python3 {config.ICARUS_CFG_FILENAME} must be'
                    ' in the list of python versions'
                )

        if not ib_arg_mmp.get('requirements_paths'):
            # not a mandatory field
            pass
        elif isinstance(ib_arg_mmp.get('requirements_paths'), list):
            if not all(isinstance(v, str) for v in ib_arg_mmp.get('requirements_paths', [])):
                raise utils.IcarusParserException(
                    f'All requirements in icarus-python3 {config.ICARUS_CFG_FILENAME} must be'
                    ' strings'
                )
        else:
            if not isinstance(ib_arg_mmp.get('requirements_paths'), list):
                raise utils.IcarusParserException(
                    f'requirements in icarus-python3 {config.ICARUS_CFG_FILENAME} must be a list'
                    ' of strings'
                )

    if ib_arg_mmp.get('build_system_in_use') == 'icarus-cdk':
        raise utils.IcarusParserException(
            f'CDK build system not yet supported in icarus-cdk {config.ICARUS_CFG_FILENAME}'
        )

    if not ib_arg_mmp.get('icarus_ignore_array'):
        # not a mandatory field
        pass
    else:
        if isinstance(ib_arg_mmp.get('icarus_ignore_array'), list):
            if not all(isinstance(v, str) for v in ib_arg_mmp.get('icarus_ignore_array', [])):
                raise utils.IcarusParserException(
                    f'All icarus ignore in ignore {config.ICARUS_CFG_FILENAME} must be strings'
                )
            for v in ib_arg_mmp.get('icarus_ignore_array', []):
                if '//' in v:
                    raise utils.IcarusParserException(
                        f'icarus ignore in ignore {config.ICARUS_CFG_FILENAME} cannot contain `//`'
                    )
                if '***' in v:
                    raise utils.IcarusParserException(
                        f'icarus ignore in ignore {config.ICARUS_CFG_FILENAME} cannot contain `***`'
                    )
        else:
            raise utils.IcarusParserException(
                f'Icarus ignore in ignore {config.ICARUS_CFG_FILENAME} must be a list of string'
            )

    return ib_arg_mmp


def _normalize_and_set_defaults_icarus_build_cfg(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
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
    ib_arg_mmp['python_versions_for_icarus'] = sorted(
        list(set(ib_arg_mmp['python_versions_for_icarus'])), key=_sort_version, reverse=True
    )
    ib_arg_mmp['icarus_ignore_array'] = list(set(ib_arg_mmp['icarus_ignore_array']))
    ib_arg_mmp['requirements_paths'] = list(set(ib_arg_mmp['requirements_paths']))

    return ib_arg_mmp


def _normalize_and_set_python_version(ib_arg_mmp: IbArgMmp) -> IbArgMmp:
    """
    Set the python version to use.

    :param ib_arg_mmp:
    :return:
    """

    if ib_arg_mmp['build_system_in_use'] == 'icarus-python3':
        if len(ib_arg_mmp['python_version_default_for_icarus'].split('.')) == 2:
            ib_arg_mmp['python_default_version'] = ib_arg_mmp['python_version_default_for_icarus']
            ib_arg_mmp['python_default_full_version'] = _get_latest_python_version(
                ib_arg_mmp['python_default_version']
            )
        elif len(ib_arg_mmp['python_version_default_for_icarus'].split('.')) == 3:
            ib_arg_mmp['python_default_version'] = '.'.join(
                ib_arg_mmp['python_version_default_for_icarus'].split('.')[:2]
            )
            ib_arg_mmp['python_default_full_version'] = ib_arg_mmp[
                'python_version_default_for_icarus'
            ]

        def_v = (
            f"{ib_arg_mmp['python_default_version']}:{ib_arg_mmp['python_default_full_version']}"
        )
        tmp_py_v = []

        for v in ib_arg_mmp['python_versions_for_icarus']:
            if len(v.split('.')) == 2:
                short_version = v
                full_version = _get_latest_python_version(v)
            elif len(v.split('.')) == 3:
                short_version = '.'.join(v.split('.')[:2])
                full_version = v
            tmp_py_v.append(':'.join([short_version, full_version]))

        # Python default always stays at index 0
        ib_arg_mmp['python_versions'] = [v for v in tmp_py_v if v == def_v] + [
            v for v in tmp_py_v if v != def_v
        ]

    return ib_arg_mmp


def _convert_ib_arg_mmp_to_ib_argv(ib_arg_mmp: IbArgMmp) -> str:
    """
    Convert a dictionary to a bash ib_arg_mmp string.

    :param ib_arg_mmp:
    :return:
    """

    temp_ib_arg_mmp = {}

    module_logger.debug('*' * 50)

    for k, v in ib_arg_mmp.items():
        temp_ib_arg_mmp[k] = _convert_value(v)
        module_logger.debug(f"ib_arg_mmp -> {k}={temp_ib_arg_mmp[k]}")

    module_logger.debug('*' * 50)

    ib_arg_mmp_str = ' '.join([f"{k}={v}" for k, v in temp_ib_arg_mmp.items()])

    return ib_arg_mmp_str


def _find_project_root_dir() -> str:
    """
    Find the project root directory containing the icarus config file.

    :return: Absolute path to the project root directory.
    """

    pwd = os.getcwd()
    while True:
        if os.path.exists(os.path.join(pwd, config.ICARUS_CFG_FILENAME)):
            return pwd
        parent = os.path.dirname(pwd)
        if parent == pwd:
            break
        pwd = parent

    raise utils.IcarusParserException(
        f'No `{config.ICARUS_CFG_FILENAME}` file found!\n               You are not in an'
        ' icarus build enabled directory.\n               To enable icarus build create a'
        f' `{config.ICARUS_CFG_FILENAME}` in the project root directory.'
    )


def _get_latest_python_version(python_version: str) -> str:
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


def _convert_value(value):
    """
    Convert a value to a string representation suitable for use in a
    Bash script.

    :param value:
    :return:
    """

    if isinstance(value, str):
        return repr(value)
    elif isinstance(value, list) or isinstance(value, tuple):
        return f"( {' '.join(_convert_value(el) for el in value)} )"
    else:
        raise utils.IcarusParserException(f"Invalid type for `{value}`")


def _sort_version(v):
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
