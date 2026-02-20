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
import argparse
import datetime
import errno
import fcntl
import getpass
import json
import os
import pathlib
import re
import time
import tomllib
from typing import IO, Optional, Union

# Third Party Library Imports
import requests
import yaml

# My Library Imports
import carlogtt_python_library as mylib

# Local Application Imports
from icarus import config, utils
from icarus.handlers.builder_handler.model import (
    BuildSystems,
    IcarusBuilderArg,
    IcarusBuilderCliArg,
    IcarusBuilderOperation,
)

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'ensure_builder_control_plane',
    'acquire_builder_lock',
    'release_builder_lock',
    'run_bash_script_with_logging',
    'parse_icarus_builder_cli_arg',
    'get_ib_arg',
    'get_ib_argv',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


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


def parse_icarus_builder_cli_arg(args: argparse.Namespace) -> IcarusBuilderCliArg:
    """
    Parse the arguments received from the CLI and return the appropriate
    operation and arguments.

    :param args: The parsed arguments.
    :return: The operation and arguments.
    """

    ib_cli_arg = IcarusBuilderCliArg()

    too_many_args = 'too many arguments'
    args_required = 'the following arguments are required: <subcommand>'
    standalone_arg = '{hook} is a standalone argument and must be used alone'

    base_args: dict[str, Union[int]] = {
        'verbose': args.verbose,
    }

    builder_hooks: dict[str, Union[str, list[str]]] = {
        'build': getattr(args, 'build', ''),
        'release': getattr(args, 'release', ''),
        'format': getattr(args, 'format', ''),
        'docs': getattr(args, 'docs', ''),
        'test': getattr(args, 'test', ''),
        'clean': getattr(args, 'clean', ''),
        'isort': getattr(args, 'isort', ''),
        'black': getattr(args, 'black', ''),
        'flake8': getattr(args, 'flake8', ''),
        'mypy': getattr(args, 'mypy', ''),
        'shfmt': getattr(args, 'shfmt', ''),
        'eolnorm': getattr(args, 'eolnorm', ''),
        'whitespaces': getattr(args, 'whitespaces', ''),
        'trailing': getattr(args, 'trailing', ''),
        'eofnewline': getattr(args, 'eofnewline', ''),
        'gitleaks': getattr(args, 'gitleaks', ''),
        'pytest': getattr(args, 'pytest', ''),
        'sphinx': getattr(args, 'sphinx', ''),
        'readthedocs': getattr(args, 'readthedocs', ''),
        'merge': getattr(args, 'merge', ''),
        'exectool': getattr(args, 'exec-tool', '') or getattr(args, 'exec_tool', ''),
        'execrun': getattr(args, 'exec-run', '') or getattr(args, 'exec_run', ''),
        'execdev': getattr(args, 'exec-dev', '') or getattr(args, 'exec_dev', ''),
        'bumpver': getattr(args, 'bumpver', ''),
    }

    builder_hooks_count = sum(1 for el in builder_hooks.values() if el)

    cache_hooks: dict[str, Union[str, list[str]]] = {
        'cache_root': args.cache_subcommands if getattr(args, 'cache_subcommands', '') == 'cache-root' else '',
        'cache_clean': args.cache_subcommands if getattr(args, 'cache_subcommands', '') == 'clean' else '',
    }

    cache_hooks_count = sum(1 for el in cache_hooks.values() if el)

    path_hooks: dict[str, Union[str, list[str]]] = {
        'list_paths': getattr(args, 'list', ''),
        'path_name': getattr(args, 'path_name', ''),
    }

    path_hooks_count = sum(1 for el in path_hooks.values() if el)

    builder_subcommand = {
        'build-runtime',
        'create',
        'path',
        'cache',
    }

    if args.builder_command in builder_subcommand and builder_hooks_count > 0:
        raise utils.IcarusParserException(too_many_args)

    if args.builder_command == 'build-runtime':
        ib_cli_arg.operation = IcarusBuilderOperation.BUILD_RUNTIME

    elif args.builder_command == 'create':
        ib_cli_arg.operation = IcarusBuilderOperation.CREATE

    elif args.builder_command == 'cache':
        if cache_hooks_count == 0:
            raise utils.IcarusParserException(args_required)

        if cache_hooks_count > 1:
            raise utils.IcarusParserException(too_many_args)

        ib_cli_arg.operation = IcarusBuilderOperation.CACHE
        ib_cli_arg.args = {**base_args, **builder_hooks, **cache_hooks}

    elif args.builder_command == 'path':
        if path_hooks_count == 0:
            raise utils.IcarusParserException(args_required)

        if path_hooks_count > 1:
            raise utils.IcarusParserException(too_many_args)

        ib_cli_arg.operation = IcarusBuilderOperation.PATH
        ib_cli_arg.args = {**base_args, **builder_hooks, **path_hooks}

    elif args.builder_command not in builder_subcommand:
        if builder_hooks_count == 0:
            raise utils.IcarusParserException(args_required)

        if builder_hooks.get('clean') and builder_hooks_count > 1:
            raise utils.IcarusParserException(standalone_arg.format(hook='--clean'))

        if builder_hooks.get('merge') and builder_hooks_count > 1:
            raise utils.IcarusParserException(standalone_arg.format(hook='--merge'))

        if builder_hooks.get('exectool') and builder_hooks_count > 1:
            raise utils.IcarusParserException(standalone_arg.format(hook='--exec-tool'))

        if builder_hooks.get('execrun') and builder_hooks_count > 1:
            raise utils.IcarusParserException(standalone_arg.format(hook='--exec-run'))

        if builder_hooks.get('execdev') and builder_hooks_count > 1:
            raise utils.IcarusParserException(standalone_arg.format(hook='--exec-dev'))

        if builder_hooks.get('bumpver') and builder_hooks_count > 1:
            raise utils.IcarusParserException(standalone_arg.format(hook='--bumpver'))

        if builder_hooks.get('bumpver'):
            ib_cli_arg.operation = IcarusBuilderOperation.BUMPVER
            ib_cli_arg.args = {**base_args, **builder_hooks}
        else:
            ib_cli_arg.operation = IcarusBuilderOperation.BUILDER
            ib_cli_arg.args = {**base_args, **builder_hooks}

    else:
        raise utils.IcarusParserException(args_required)

    return ib_cli_arg


def get_ib_arg(cli_ib_arg: dict[str, Union[int, str, list[str]]]) -> IcarusBuilderArg:
    """
    Get the arguments as IcarusBuilderArg object.

    :param cli_ib_arg: The parsed arguments.
    :return: The arguments as IcarusBuilderArg object.
    """

    ib_arg = IcarusBuilderArg()

    _read_icarus_build_cfg(ib_arg)
    _parse_icarus_build_cfg(ib_arg)
    _validate_icarus_build_cfg(ib_arg)
    _parse_pyproject_toml(ib_arg)
    _process_cli_ib_args(ib_arg, cli_ib_arg)
    _normalize_and_set_defaults_icarus_build_cfg(ib_arg)
    _normalize_and_set_python_version(ib_arg)

    return ib_arg


def get_ib_argv(cli_ib_arg: dict[str, Union[int, str, list[str]]]) -> str:
    """
    Get the arguments for the builder.sh script as a string.

    :param cli_ib_arg:
    :return: The arguments for the builder.sh script.
    """

    ib_arg = get_ib_arg(cli_ib_arg=cli_ib_arg)

    ib_argv = ib_arg.as_bash_argv()

    return ib_argv


def _process_cli_ib_args(
    ib_arg: IcarusBuilderArg, cli_ib_arg: dict[str, Union[int, str, list[str]]]
) -> None:
    """
    Process the arguments received from the CLI and set the
    appropriate values.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :param cli_ib_arg: The parsed arguments.
    :return:
    """

    if cli_ib_arg.get('verbose'):
        ib_arg.verbose = 'Y'

    if cli_ib_arg.get('exectool'):
        assert not isinstance(cli_ib_arg['exectool'], int)
        if len(cli_ib_arg['exectool']) == 1:
            ib_arg.initial_exectool_command_received = cli_ib_arg['exectool'][0].split()
        elif len(cli_ib_arg['exectool']) > 1:
            assert isinstance(cli_ib_arg['exectool'], list)
            ib_arg.initial_exectool_command_received = cli_ib_arg['exectool']
        else:
            raise utils.IcarusParserException('Invalid --exec-tool argument')
        # altering the exec value so it can be used from the for loop
        # here below to make up the initial_command_received look pretty
        cli_ib_arg['exectool'] = f"--exec-tool {' '.join(cli_ib_arg['exectool'])}"

    if cli_ib_arg.get('execrun'):
        assert not isinstance(cli_ib_arg['execrun'], int)
        if len(cli_ib_arg['execrun']) == 1:
            ib_arg.initial_execrun_command_received = cli_ib_arg['execrun'][0].split()
        elif len(cli_ib_arg['execrun']) > 1:
            assert isinstance(cli_ib_arg['execrun'], list)
            ib_arg.initial_execrun_command_received = cli_ib_arg['execrun']
        else:
            raise utils.IcarusParserException('Invalid --exec-run argument')
        # altering the exec value so it can be used from the for loop
        # here below to make up the initial_command_received look pretty
        cli_ib_arg['execrun'] = f"--exec-run {' '.join(cli_ib_arg['execrun'])}"

    if cli_ib_arg.get('execdev'):
        assert not isinstance(cli_ib_arg['execdev'], int)
        if len(cli_ib_arg['execdev']) == 1:
            ib_arg.initial_execdev_command_received = cli_ib_arg['execdev'][0].split()
        elif len(cli_ib_arg['execdev']) > 1:
            assert isinstance(cli_ib_arg['execdev'], list)
            ib_arg.initial_execdev_command_received = cli_ib_arg['execdev']
        else:
            raise utils.IcarusParserException('Invalid --exec-dev argument')
        # altering the exec value so it can be used from the for loop
        # here below to make up the initial_command_received look pretty
        cli_ib_arg['execdev'] = f"--exec-dev {' '.join(cli_ib_arg['execdev'])}"

    # HOOKS
    for hook in ib_arg.all_hooks:
        if cli_ib_arg.get(hook):
            setattr(ib_arg, hook, 'Y')

    # RELEASE target
    if cli_ib_arg.get('release'):
        ib_arg.is_release = 'Y'
        if ib_arg.build_system_in_use == BuildSystems.ICARUS_PYTHON3.value:
            ib_arg.build = 'Y'
            ib_arg.isort = 'Y'
            ib_arg.black = 'Y'
            ib_arg.flake8 = 'Y'
            ib_arg.mypy = 'Y'
            ib_arg.shfmt = 'Y'
            ib_arg.eolnorm = 'Y'
            ib_arg.whitespaces = 'Y'
            ib_arg.trailing = 'Y'
            ib_arg.eofnewline = 'Y'
            ib_arg.pytest = 'Y'
            ib_arg.gitleaks = 'Y'
            ib_arg.sphinx = 'Y'
        elif ib_arg.build_system_in_use == BuildSystems.ICARUS_CDK.value:
            ib_arg.build = 'Y'
            ib_arg.shfmt = 'Y'
            ib_arg.eolnorm = 'Y'
            ib_arg.whitespaces = 'Y'
            ib_arg.trailing = 'Y'
            ib_arg.eofnewline = 'Y'
            ib_arg.gitleaks = 'Y'
        else:
            raise utils.IcarusParserException(
                f'The --release target is not configured for the {ib_arg.build_system_in_use} build'
                ' systems'
            )

    # FORMAT target
    if cli_ib_arg.get('format'):
        if ib_arg.build_system_in_use == BuildSystems.ICARUS_PYTHON3.value:
            ib_arg.isort = 'Y'
            ib_arg.black = 'Y'
            ib_arg.shfmt = 'Y'
            ib_arg.eolnorm = 'Y'
            ib_arg.whitespaces = 'Y'
            ib_arg.trailing = 'Y'
            ib_arg.eofnewline = 'Y'
        elif ib_arg.build_system_in_use == BuildSystems.ICARUS_CDK.value:
            ib_arg.shfmt = 'Y'
            ib_arg.eolnorm = 'Y'
            ib_arg.whitespaces = 'Y'
            ib_arg.trailing = 'Y'
            ib_arg.eofnewline = 'Y'
        else:
            raise utils.IcarusParserException(
                'The --format target is not configured for the'
                f' f{ib_arg.build_system_in_use} build systems'
            )

    # TEST target
    if cli_ib_arg.get('test'):
        if ib_arg.build_system_in_use == BuildSystems.ICARUS_PYTHON3.value:
            ib_arg.pytest = 'Y'
        elif ib_arg.build_system_in_use == BuildSystems.ICARUS_CDK.value:
            # This is just a placeholder for now
            ib_arg.pytest = 'N'
        else:
            raise utils.IcarusParserException(
                f'The --test target is not configured for the f{ib_arg.build_system_in_use}'
                ' build systems'
            )

    # DOCS target
    if cli_ib_arg.get('docs'):
        if ib_arg.build_system_in_use == BuildSystems.ICARUS_PYTHON3.value:
            ib_arg.sphinx = 'Y'
        elif ib_arg.build_system_in_use == BuildSystems.ICARUS_CDK.value:
            # This is just a placeholder for now
            ib_arg.sphinx = 'N'
        else:
            raise utils.IcarusParserException(
                f'The --docs target is not configured for the f{ib_arg.build_system_in_use}'
                ' build systems'
            )

    for arg_name, arg_value in cli_ib_arg.items():
        if arg_name == 'verbose':
            assert isinstance(arg_value, int)
            if arg_value > 0:
                ib_arg.initial_command_received += " -v"
                continue
        if arg_value:
            ib_arg.initial_command_received += f" {arg_value}"

    # Count running hooks
    for hook in ib_arg.all_hooks:
        if getattr(ib_arg, hook) == 'Y':
            ib_arg.running_hooks_name.append(hook)

    ib_arg.running_hooks_count = str(len(ib_arg.running_hooks_name))

    if ib_arg.build == 'Y' and ib_arg.running_hooks_count == str(1):
        ib_arg.is_only_build_hook = 'Y'

    # Path CLI
    if cli_ib_arg.get('path_name'):
        assert isinstance(cli_ib_arg['path_name'], str)
        ib_arg.path_name = cli_ib_arg['path_name']

    # Cache CLI
    if cli_ib_arg.get('cache_root'):
        ib_arg.cache_root = 'Y'
    if cli_ib_arg.get('cache_clean'):
        ib_arg.cache_clean = 'Y'


def _read_icarus_build_cfg(ib_arg: IcarusBuilderArg) -> None:
    """
    Read the icarus build config file.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :return:
    """

    project_root_dir_abs = _find_project_root_dir()
    config_filepath = os.path.join(project_root_dir_abs, config.ICARUS_CFG_FILENAME)

    ib_arg.icarus_config_filename = config.ICARUS_CFG_FILENAME
    ib_arg.icarus_config_filepath = config_filepath
    ib_arg.project_root_dir_abs = project_root_dir_abs


def _parse_icarus_build_cfg(ib_arg: IcarusBuilderArg) -> None:
    """
    Parse the icarus build config file.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :return:
    """

    try:
        with open(ib_arg.icarus_config_filepath) as icarus_build_config:
            ibc = yaml.safe_load(icarus_build_config)
    except Exception as e:
        raise utils.IcarusParserException(
            f"Error parsing {ib_arg.icarus_config_filepath} -- {repr(e)}"
        )

    pkg = ibc.get('package', [])
    bs = ibc.get('build-system', [])
    ipy = ibc.get(BuildSystems.ICARUS_PYTHON3.value, [])
    icdk = ibc.get(BuildSystems.ICARUS_CDK.value, [])  # noqa
    ignrs = ibc.get('ignore', [])

    try:
        ib_arg.package_name_pascal_case = [d['name'] for d in pkg if d.get('name')][0]
    except Exception:
        pass

    try:
        ib_arg.package_language = [d['language'] for d in pkg if d.get('language')][0]
    except Exception:
        pass

    try:
        ib_arg.package_version_full = [d['version'] for d in pkg if d.get('version')][0]
    except Exception:
        pass

    try:
        ib_arg.build_system_in_use = [d['system'] for d in bs if d.get('system')][0]
    except Exception:
        pass

    try:
        ib_arg.build_root_dir = [d['build-root'] for d in bs if d.get('build-root')][0]
    except Exception:
        pass

    try:
        ib_arg.python_version_default_for_icarus = [
            d['python-default'] for d in ipy if d.get('python-default')
        ][0]

    except Exception:
        pass

    try:
        ib_arg.python_versions_for_icarus = [d['python'] for d in ipy if d.get('python')][0]
    except Exception:
        pass

    try:
        ib_arg.tool_requirements_paths = [
            d['tool-dependencies'] for d in ipy if d.get('tool-dependencies')
        ][0]
    except Exception:
        pass

    try:
        ib_arg.run_requirements_paths = [
            d['run-dependencies'] for d in ipy if d.get('run-dependencies')
        ][0]
    except Exception:
        pass

    try:
        ib_arg.dev_requirements_paths = [
            d['dev-dependencies'] for d in ipy if d.get('dev-dependencies')
        ][0]
    except Exception:
        pass

    try:
        read_the_docs_dict = [d['read-the-docs'] for d in ipy if d.get('read-the-docs')][0]
        ib_arg.read_the_docs_requirements_path = [
            d['requirements'] for d in read_the_docs_dict if d.get('requirements')
        ][0]
    except Exception:
        pass

    try:
        ib_arg.icarus_ignore_array = [i.strip() for i in ignrs]
    except Exception:
        pass


def _validate_icarus_build_cfg(ib_arg: IcarusBuilderArg) -> None:
    """
    Validate the icarus build config file.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :return:
    """

    if not ib_arg.package_name_pascal_case:
        raise utils.IcarusParserException(
            f'No name specified in package {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg.package_name_pascal_case, str):
            raise utils.IcarusParserException(
                f'name in package {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if not ib_arg.package_language:
        raise utils.IcarusParserException(
            f'No language specified in package {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg.package_language, str):
            raise utils.IcarusParserException(
                f'language in package {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if not ib_arg.package_version_full:
        raise utils.IcarusParserException(
            f'No version specified in package {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg.package_version_full, str):
            raise utils.IcarusParserException(
                f'version in package {config.ICARUS_CFG_FILENAME} must be a string'
            )
        if len(ib_arg.package_version_full.split('.')) not in {3}:
            raise utils.IcarusParserException(
                f'Invalid version in package {config.ICARUS_CFG_FILENAME}, version must follow'
                ' Semantic Versioning (SemVer): MAJOR.MINOR.PATCH (see https://semver.org).'
            )

    if not ib_arg.build_system_in_use:
        raise utils.IcarusParserException(
            f'No system specified in build-system {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg.build_system_in_use, str):
            raise utils.IcarusParserException(
                f'system in build-system {config.ICARUS_CFG_FILENAME} must be a string'
            )
        if ib_arg.build_system_in_use not in BuildSystems:
            raise utils.IcarusParserException(
                f'Invalid system in build-system {config.ICARUS_CFG_FILENAME}'
            )

    if not ib_arg.build_root_dir:
        raise utils.IcarusParserException(
            f'No build-root specified in build-system {config.ICARUS_CFG_FILENAME}'
        )
    else:
        if not isinstance(ib_arg.build_root_dir, str):
            raise utils.IcarusParserException(
                f'build-root in build-system {config.ICARUS_CFG_FILENAME} must be a string'
            )

    if ib_arg.build_system_in_use == BuildSystems.ICARUS_PYTHON3.value:
        if not ib_arg.python_versions_for_icarus:
            raise utils.IcarusParserException(
                f'No python version(s) specified in {BuildSystems.ICARUS_PYTHON3.value}'
                f' {config.ICARUS_CFG_FILENAME}'
            )
        elif isinstance(ib_arg.python_versions_for_icarus, list):
            if not all(isinstance(v, str) for v in ib_arg.python_versions_for_icarus):
                raise utils.IcarusParserException(
                    f'All python version(s) in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be strings'
                )
            if not all(len(v.split('.')) in {2, 3} for v in ib_arg.python_versions_for_icarus):
                raise utils.IcarusParserException(
                    f'All python version(s) in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be valid'
                )
        else:
            raise utils.IcarusParserException(
                f'Python version(s) in {BuildSystems.ICARUS_PYTHON3.value}'
                f' {config.ICARUS_CFG_FILENAME} must be a list of string'
            )

        if not ib_arg.python_version_default_for_icarus:
            raise utils.IcarusParserException(
                f'No python-default version specified in {BuildSystems.ICARUS_PYTHON3.value}'
                f' {config.ICARUS_CFG_FILENAME}'
            )
        else:
            if not isinstance(ib_arg.python_version_default_for_icarus, str):
                raise utils.IcarusParserException(
                    f'python-default version in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be a string'
                )
            if len(ib_arg.python_version_default_for_icarus.split('.')) not in {
                2,
                3,
            }:
                raise utils.IcarusParserException(
                    f'Invalid python-default version in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME}'
                )
            if ib_arg.python_version_default_for_icarus not in ib_arg.python_versions_for_icarus:
                raise utils.IcarusParserException(
                    f'python-default version in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be in the list of python versions'
                )

        if not ib_arg.tool_requirements_paths:
            # not a mandatory field
            pass
        elif isinstance(ib_arg.tool_requirements_paths, list):
            if not all(isinstance(v, str) for v in ib_arg.tool_requirements_paths):
                raise utils.IcarusParserException(
                    f'All tool-dependencies in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be strings'
                )
        else:
            if not isinstance(ib_arg.tool_requirements_paths, list):
                raise utils.IcarusParserException(
                    f'tool-dependencies in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be a list of strings'
                )

        if not ib_arg.run_requirements_paths:
            # not a mandatory field
            pass
        elif isinstance(ib_arg.run_requirements_paths, list):
            if not all(isinstance(v, str) for v in ib_arg.run_requirements_paths):
                raise utils.IcarusParserException(
                    f'All run-dependencies in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be strings'
                )
        else:
            if not isinstance(ib_arg.run_requirements_paths, list):
                raise utils.IcarusParserException(
                    f'run-dependencies in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be a list of strings'
                )

        if not ib_arg.dev_requirements_paths:
            # not a mandatory field
            pass
        elif isinstance(ib_arg.dev_requirements_paths, list):
            if not all(isinstance(v, str) for v in ib_arg.dev_requirements_paths):
                raise utils.IcarusParserException(
                    f'All dev-dependencies in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be strings'
                )
        else:
            if not isinstance(ib_arg.dev_requirements_paths, list):
                raise utils.IcarusParserException(
                    f'dev-dependencies in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be a list of strings'
                )

        if not ib_arg.read_the_docs_requirements_path:
            # not a mandatory field
            pass
        else:
            if not isinstance(ib_arg.read_the_docs_requirements_path, str):
                raise utils.IcarusParserException(
                    f'read-the-docs requirements in {BuildSystems.ICARUS_PYTHON3.value}'
                    f' {config.ICARUS_CFG_FILENAME} must be a string'
                )

    if ib_arg.build_system_in_use == BuildSystems.ICARUS_CDK.value:
        raise utils.IcarusParserException(
            f'CDK build system not yet supported in {BuildSystems.ICARUS_CDK.value}'
            f' {config.ICARUS_CFG_FILENAME}'
        )

    if not ib_arg.icarus_ignore_array:
        # not a mandatory field
        pass
    else:
        if isinstance(ib_arg.icarus_ignore_array, list):
            if not all(isinstance(v, str) for v in ib_arg.icarus_ignore_array):
                raise utils.IcarusParserException(
                    f'All icarus ignore in ignore {config.ICARUS_CFG_FILENAME} must be strings'
                )
            for v in ib_arg.icarus_ignore_array:
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


def _parse_pyproject_toml(ib_arg: IcarusBuilderArg) -> None:
    """
    Parse the pyproject.toml file.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :return:
    """

    pyproject_toml_filepath = os.path.join(ib_arg.project_root_dir_abs, 'pyproject.toml')

    try:
        with open(pyproject_toml_filepath, 'rb') as pyproject_toml:
            pyproject_toml_data = tomllib.load(pyproject_toml)
    except Exception:
        # This is an optional requirement we do not raise.
        pass

    try:
        ib_arg.run_requirements_pyproject_toml = pyproject_toml_data.get('project', {}).get(
            'dependencies', []
        )
    except Exception:
        pass


def _normalize_and_set_defaults_icarus_build_cfg(ib_arg: IcarusBuilderArg) -> None:
    """
    Normalize the values and set defaults.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :return:
    """

    stru = mylib.StringUtils()

    # Add pkg name snake anf dashed
    try:
        ib_arg.package_name_snake_case = stru.snake_case(ib_arg.package_name_pascal_case)
        ib_arg.package_name_dashed = ib_arg.package_name_snake_case.replace("_", "-")
    except Exception:
        raise utils.IcarusParserException(f"Invalid package name in {config.ICARUS_CFG_FILENAME}")

    # Add pkg version
    ib_arg.package_version_major = ib_arg.package_version_full.split('.')[0]
    ib_arg.package_version_minor = ib_arg.package_version_full.split('.')[1]
    ib_arg.package_version_patch = ib_arg.package_version_full.split('.')[2]

    # Remove duplicates and sort from newest to oldest version
    ib_arg.python_versions_for_icarus = sorted(
        set(ib_arg.python_versions_for_icarus), key=_sort_version, reverse=True
    )
    ib_arg.icarus_ignore_array = list(set(ib_arg.icarus_ignore_array))
    ib_arg.tool_requirements_paths = list(set(ib_arg.tool_requirements_paths))
    ib_arg.run_requirements_paths = list(set(ib_arg.run_requirements_paths))
    ib_arg.dev_requirements_paths = list(set(ib_arg.dev_requirements_paths))


def _normalize_and_set_python_version(ib_arg: IcarusBuilderArg) -> None:
    """
    Normalize the python version.

    :param ib_arg: The IcarusBuilderArg object to be updated.
    :return:
    """

    if ib_arg.build_system_in_use == BuildSystems.ICARUS_PYTHON3.value:
        if len(ib_arg.python_version_default_for_icarus.split('.')) == 2:
            ib_arg.python_default_version = ib_arg.python_version_default_for_icarus
            ib_arg.python_default_full_version = _get_latest_python_version(
                ib_arg.python_default_version
            )
        elif len(ib_arg.python_version_default_for_icarus.split('.')) == 3:
            ib_arg.python_default_version = '.'.join(
                ib_arg.python_version_default_for_icarus.split('.')[:2]
            )
            ib_arg.python_default_full_version = ib_arg.python_version_default_for_icarus

        def_v = f"{ib_arg.python_default_version}:{ib_arg.python_default_full_version}"
        tmp_py_v = []

        for v in ib_arg.python_versions_for_icarus:
            if len(v.split('.')) == 2:
                short_version = v
                full_version = _get_latest_python_version(v)
            elif len(v.split('.')) == 3:
                short_version = '.'.join(v.split('.')[:2])
                full_version = v
            tmp_py_v.append(':'.join([short_version, full_version]))

        # Python default always stays at index 0
        ib_arg.python_versions = [v for v in tmp_py_v if v == def_v] + [
            v for v in tmp_py_v if v != def_v
        ]


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
        ' icarus builder enabled directory.\n               To enable icarus builder create a'
        f' `{config.ICARUS_CFG_FILENAME}` in the project root directory.'
    )


def _get_latest_python_version(python_version: str) -> str:
    """
    Get the latest python full version for the given python version.

    :param python_version: The python version.
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
