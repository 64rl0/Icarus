#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/cli_scripts/builder_handler/builder_base.sh
# Created 2/14/26 - 9:10 AM UK Time (London) by carlogtt

# Cache stays in the system tmp
path_to_cache_root="${tmp_root}/builder/cache"

# SIMPLE RECIPE
path_platform_identifier_name="platform-identifier"
path_ws_root_name="workspace.root"
path_ws_src_root_name="workspace.src-root"
path_ws_build_root_name="workspace.build-root"
path_ws_user_space_root_name="workspace.user-space-root"

# LANGUAGE RECIPE
path_pkg_language_name="pkg.language"

# NAME RECIPE
path_pkg_name_pascal_name="pkg.name-pascal"
path_pkg_name_snake_name="pkg.name-snake"
path_pkg_name_dashed_name="pkg.name-dashed"
path_tool_name_name="tool.name"
path_run_name_name="run.name"
path_run_excluderoot_name_name="run_excluderoot.name"
path_devrun_name_name="devrun.name"
path_devrun_excluderoot_name_name="devrun_excluderoot.name"

# VERSION RECIPE
path_pkg_version_full_name="pkg.version"
path_pkg_version_major_name="pkg.version-major"
path_pkg_version_minor_name="pkg.version-minor"
path_pkg_version_patch_name="pkg.version-patch"
path_tool_version_full_name="tool.version"
path_run_version_full_name="run.version"
path_run_excluderoot_version_full_name="run_excluderoot.version"
path_devrun_version_full_name="devrun.version"
path_devrun_excluderoot_version_full_name="devrun_excluderoot.version"

# RUNTIMEFARM RECIPE
path_pkg_runtimefarm_name="pkg.runtimefarm"
path_tool_runtimefarm_name="tool.runtimefarm"
path_run_runtimefarm_name="run.runtimefarm"
path_run_excluderoot_runtimefarm_name="run_excluderoot.runtimefarm"
path_devrun_runtimefarm_name="devrun.runtimefarm"
path_devrun_excluderoot_runtimefarm_name="devrun_excluderoot.runtimefarm"

# PYTHONHOME RECIPE
path_pkg_pythonhome_name="pkg.pythonhome"
path_tool_pythonhome_name="tool.pythonhome"
path_run_pythonhome_name="run.pythonhome"
path_run_excluderoot_pythonhome_name="run_excluderoot.pythonhome"
path_devrun_pythonhome_name="devrun.pythonhome"
path_devrun_excluderoot_pythonhome_name="devrun_excluderoot.pythonhome"

# BIN RECIPE
path_pkg_bin_name="pkg.bin"
path_tool_bin_name="tool.bin"
path_run_bin_name="run.bin"
path_run_excluderoot_bin_name="run_excluderoot.bin"
path_devrun_bin_name="devrun.bin"
path_devrun_excluderoot_bin_name="devrun_excluderoot.bin"

path_all_names=(
    "${path_platform_identifier_name}"
    "${path_ws_root_name}"
    "${path_ws_src_root_name}"
    "${path_ws_build_root_name}"
    "${path_ws_user_space_root_name}"

    "${path_pkg_language_name}"

    "${path_pkg_name_pascal_name}"
    "${path_pkg_name_snake_name}"
    "${path_pkg_name_dashed_name}"
    "${path_tool_name_name}"
    "${path_run_name_name}"
    "${path_run_excluderoot_name_name}"
    "${path_devrun_name_name}"
    "${path_devrun_excluderoot_name_name}"

    "${path_pkg_version_full_name}"
    "${path_pkg_version_major_name}"
    "${path_pkg_version_minor_name}"
    "${path_pkg_version_patch_name}"
    "${path_tool_version_full_name}"
    "${path_run_version_full_name}"
    "${path_run_excluderoot_version_full_name}"
    "${path_devrun_version_full_name}"
    "${path_devrun_excluderoot_version_full_name}"

    "${path_pkg_runtimefarm_name}"
    "${path_tool_runtimefarm_name}"
    "${path_run_runtimefarm_name}"
    "${path_run_excluderoot_runtimefarm_name}"
    "${path_devrun_runtimefarm_name}"
    "${path_devrun_excluderoot_runtimefarm_name}"

    "${path_pkg_pythonhome_name}"
    "${path_tool_pythonhome_name}"
    "${path_run_pythonhome_name}"
    "${path_run_excluderoot_pythonhome_name}"
    "${path_devrun_pythonhome_name}"
    "${path_devrun_excluderoot_pythonhome_name}"

    "${path_pkg_bin_name}"
    "${path_tool_bin_name}"
    "${path_run_bin_name}"
    "${path_run_excluderoot_bin_name}"
    "${path_devrun_bin_name}"
    "${path_devrun_excluderoot_bin_name}"
)

declare -g -r path_to_cache_root
declare -g -r path_platform_identifier_name
declare -g -r path_ws_root_name
declare -g -r path_ws_src_root_name
declare -g -r path_ws_build_root_name
declare -g -r path_ws_user_space_root_name
declare -g -r path_pkg_language_name
declare -g -r path_pkg_name_pascal_name
declare -g -r path_pkg_name_snake_name
declare -g -r path_pkg_name_dashed_name
declare -g -r path_tool_name_name
declare -g -r path_run_name_name
declare -g -r path_run_excluderoot_name_name
declare -g -r path_devrun_name_name
declare -g -r path_devrun_excluderoot_name_name
declare -g -r path_pkg_version_full_name
declare -g -r path_pkg_version_major_name
declare -g -r path_pkg_version_minor_name
declare -g -r path_pkg_version_patch_name
declare -g -r path_tool_version_full_name
declare -g -r path_run_version_full_name
declare -g -r path_run_excluderoot_version_full_name
declare -g -r path_devrun_version_full_name
declare -g -r path_devrun_excluderoot_version_full_name
declare -g -r path_pkg_runtimefarm_name
declare -g -r path_tool_runtimefarm_name
declare -g -r path_run_runtimefarm_name
declare -g -r path_run_excluderoot_runtimefarm_name
declare -g -r path_devrun_runtimefarm_name
declare -g -r path_devrun_excluderoot_runtimefarm_name
declare -g -r path_pkg_pythonhome_name
declare -g -r path_tool_pythonhome_name
declare -g -r path_run_pythonhome_name
declare -g -r path_run_excluderoot_pythonhome_name
declare -g -r path_devrun_pythonhome_name
declare -g -r path_devrun_excluderoot_pythonhome_name
declare -g -r path_pkg_bin_name
declare -g -r path_tool_bin_name
declare -g -r path_run_bin_name
declare -g -r path_run_excluderoot_bin_name
declare -g -r path_devrun_bin_name
declare -g -r path_devrun_excluderoot_bin_name
declare -a -r -g path_all_names

function declare_global_vars() {
    declare -r -g verbose
    declare -r -g all_hooks
    declare -r -g icarus_config_filename
    declare -r -g icarus_config_filepath
    declare -r -g project_root_dir_abs
    declare -r -g package_name_pascal_case
    declare -r -g package_name_snake_case
    declare -r -g package_name_dashed
    declare -r -g package_language
    declare -r -g package_version_full
    declare -r -g package_version_major
    declare -r -g package_version_minor
    declare -r -g package_version_patch
    declare -r -g build_system_in_use
    declare -r -g platform_identifier
    declare -r -g build_root_dir
    declare -r -g python_version_default_for_icarus
    declare -r -g python_versions_for_icarus
    declare -r -g tool_requirements_paths
    declare -r -g run_requirements_paths
    declare -r -g run_requirements_pyproject_toml
    declare -r -g dev_requirements_paths
    declare -r -g read_the_docs_requirements_path
    declare -r -g icarus_ignore_array
    declare -r -g build
    declare -r -g is_only_build_hook
    declare -r -g is_release
    declare -r -g merge
    declare -r -g clean
    declare -r -g isort
    declare -r -g black
    declare -r -g flake8
    declare -r -g mypy
    declare -r -g shfmt
    declare -r -g whitespaces
    declare -r -g eolnorm
    declare -r -g trailing
    declare -r -g eofnewline
    declare -r -g gitleaks
    declare -r -g pytest
    declare -r -g sphinx
    declare -r -g readthedocs
    declare -r -g exectool
    declare -r -g execrun
    declare -r -g execdev
    declare -r -g bumpver
    declare -r -g initial_command_received
    declare -r -g initial_exectool_command_received
    declare -r -g initial_execrun_command_received
    declare -r -g initial_execdev_command_received
    declare -r -g running_hooks_name
    declare -r -g running_hooks_count
    declare -r -g python_default_version
    declare -r -g python_default_full_version
    declare -r -g python_versions
    declare -r -g path_name
    declare -r -g list_paths
    declare -r -g cache_root
    declare -r -g cache_clean
}
