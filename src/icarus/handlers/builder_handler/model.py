# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/types.py
# Created 2/16/26 - 4:33 PM UK Time (London) by carlogtt

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
import dataclasses
import enum
from typing import Any, Literal, Union

# Local Application Imports
from icarus import config, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'BuildSystems',
    'IcarusBuilderOperation',
    'IcarusBuilderCliArg',
    'IcarusBuilderArg',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


class BuildSystems(enum.Enum):
    ICARUS_PYTHON3 = 'icarus-python3'
    ICARUS_CDK = 'icarus-cdk'


class IcarusBuilderOperation(enum.Enum):
    UNDEFINED = 'undefined'
    BUILD_RUNTIME = 'build-runtime'
    CREATE = 'create'
    BUILDER = 'builder'
    BUMPVER = 'bumpver'
    PATH = 'path'
    CACHE = 'cache'


@dataclasses.dataclass(kw_only=True)
class IcarusBuilderCliArg:
    operation: IcarusBuilderOperation = IcarusBuilderOperation.UNDEFINED
    args: dict[str, Union[int, str, list[str]]] = dataclasses.field(default_factory=dict)


@dataclasses.dataclass(kw_only=True)
class IcarusBuilderArg:
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
        Literal['sphinx'],
        Literal['readthedocs'],
        Literal['pypi'],
        Literal['merge'],
        Literal['exectool'],
        Literal['execrun'],
        Literal['execdev'],
        Literal['bumpver'],
    ] = (
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
        'sphinx',
        'readthedocs',
        'pypi',
        'merge',
        'exectool',
        'execrun',
        'execdev',
        'bumpver',
    )
    running_hooks_name: list[str] = dataclasses.field(default_factory=list)
    running_hooks_count: str = ''
    platform_identifier: str = utils.platform_id()
    verbose: str = 'N'
    icarus_config_filename: str = ''
    icarus_config_filepath: str = ''
    project_root_dir_abs: str = ''
    build_root_dir: str = ''
    package_name_pascal_case: str = ''
    package_name_snake_case: str = ''
    package_name_dashed: str = ''
    package_language: str = ''
    package_version_full: str = ''
    package_version_major: str = ''
    package_version_minor: str = ''
    package_version_patch: str = ''
    build_system_in_use: str = ''
    python_version_default_for_icarus: str = ''
    python_versions_for_icarus: list[str] = dataclasses.field(default_factory=list)
    python_default_version: str = ''
    python_default_full_version: str = ''
    python_versions: list[str] = dataclasses.field(default_factory=list)
    tool_requirements_paths: list[str] = dataclasses.field(default_factory=list)
    run_requirements_paths: list[str] = dataclasses.field(default_factory=list)
    run_requirements_pyproject_toml: list[str] = dataclasses.field(default_factory=list)
    dev_requirements_paths: list[str] = dataclasses.field(default_factory=list)
    read_the_docs_requirements_path: str = ''
    icarus_ignore_array: list[str] = dataclasses.field(default_factory=list)
    is_release: str = ''
    is_only_build_hook: str = ''
    merge: str = ''
    bumpver: str = ''
    build: str = ''
    clean: str = ''
    isort: str = ''
    black: str = ''
    flake8: str = ''
    mypy: str = ''
    shfmt: str = ''
    eolnorm: str = ''
    whitespaces: str = ''
    trailing: str = ''
    eofnewline: str = ''
    gitleaks: str = ''
    pytest: str = ''
    sphinx: str = ''
    readthedocs: str = ''
    pypi: str = ''
    exectool: str = ''
    execrun: str = ''
    execdev: str = ''
    initial_command_received: str = 'icarus builder'
    initial_exectool_command_received: list[str] = dataclasses.field(default_factory=list)
    initial_execrun_command_received: list[str] = dataclasses.field(default_factory=list)
    initial_execdev_command_received: list[str] = dataclasses.field(default_factory=list)
    # Path CLI
    path_name: str = ''
    list_paths: str = ''
    # Cache CLI
    cache_root: str = ''
    cache_clean: str = ''

    def as_dict(self) -> dict[str, Any]:
        """
        Convert the IcarusBuilderArg object to a dictionary.

        :return:
        """

        return dataclasses.asdict(self)

    def as_bash_argv(self) -> str:
        """
        Convert a dictionary to a bash ib_arg string.

        :return:
        """

        temp_ib_arg = {}

        module_logger.debug('*' * 50)

        for k, v in self.as_dict().items():
            temp_ib_arg[k] = self._convert_value(v)
            module_logger.debug(f"ib_arg -> {k}={temp_ib_arg[k]}")

        module_logger.debug('*' * 50)

        ib_arg_str = ' '.join([f"{k}={v}" for k, v in temp_ib_arg.items()])

        return ib_arg_str

    def _convert_value(self, value) -> str:
        """
        Convert a value to a string representation suitable for use in a
        Bash script.

        :param value:
        :return:
        """

        if isinstance(value, str):
            return repr(value)
        elif isinstance(value, list) or isinstance(value, tuple):
            return f"( {' '.join(self._convert_value(el) for el in value)} )"
        else:
            raise utils.IcarusParserException(f"Invalid type for `{value}`")
