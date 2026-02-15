#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/cli_scripts/builder_handler/builder_base.sh
# Created 2/14/26 - 9:10 AM UK Time (London) by carlogtt

path_platform_identifier_name="platform-identifier"

path_ws_root_name="workspace.root"
path_ws_src_root_name="workspace.src-root"
path_ws_build_root_name="workspace.build-root"
path_ws_user_space_root_name="workspace.user-space-root"

path_pkg_name_pascal_name="pkg.name-pascal"
path_pkg_name_snake_name="pkg.name-snake"
path_pkg_name_dashed_name="pkg.name-dashed"
path_pkg_language_name="pkg.language"
path_pkg_version_full_name="pkg.version"
path_pkg_version_major_name="pkg.version-major"
path_pkg_version_minor_name="pkg.version-minor"
path_pkg_version_patch_name="pkg.version-patch"
path_pkg_runtimefarm_name="pkg.runtimefarm"
path_pkg_pythonhome_name="pkg.pythonhome"

path_tool_runtimefarm_name="tool.runtimefarm"
path_tool_pythonhome_name="tool.pythonhome"

path_run_runtimefarm_name="run.runtimefarm"
path_run_pythonhome_name="run.pythonhome"

path_run_excluderoot_runtimefarm_name="run_excluderoot.runtimefarm"
path_run_excluderoot_pythonhome_name="run_excluderoot.pythonhome"

path_devrun_runtimefarm_name="devrun.runtimefarm"
path_devrun_pythonhome_name="devrun.pythonhome"

path_devrun_excluderoot_runtimefarm_name="devrun_excluderoot.runtimefarm"
path_devrun_excluderoot_pythonhome_name="devrun_excluderoot.pythonhome"

path_all_names=(
    "${path_platform_identifier_name}"
    "${path_pkg_name_pascal_name}"
    "${path_pkg_name_snake_name}"
    "${path_pkg_name_dashed_name}"
    "${path_pkg_language_name}"
    "${path_pkg_version_full_name}"
    "${path_pkg_version_major_name}"
    "${path_pkg_version_minor_name}"
    "${path_pkg_version_patch_name}"
    "${path_ws_root_name}"
    "${path_ws_src_root_name}"
    "${path_ws_build_root_name}"
    "${path_ws_user_space_root_name}"
    "${path_tool_runtimefarm_name}"
    "${path_tool_pythonhome_name}"
    "${path_pkg_runtimefarm_name}"
    "${path_pkg_pythonhome_name}"
    "${path_run_runtimefarm_name}"
    "${path_run_pythonhome_name}"
    "${path_run_excluderoot_runtimefarm_name}"
    "${path_run_excluderoot_pythonhome_name}"
    "${path_devrun_runtimefarm_name}"
    "${path_devrun_pythonhome_name}"
    "${path_devrun_excluderoot_runtimefarm_name}"
    "${path_devrun_excluderoot_pythonhome_name}"
)

declare -g -r path_platform_identifier_name
declare -g -r path_pkg_name_pascal_name
declare -g -r path_pkg_name_snake_name
declare -g -r path_pkg_name_dashed_name
declare -g -r path_pkg_language_name
declare -g -r path_pkg_version_full_name
declare -g -r path_pkg_version_major_name
declare -g -r path_pkg_version_minor_name
declare -g -r path_pkg_version_patch_name
declare -g -r path_ws_root_name
declare -g -r path_ws_src_root_name
declare -g -r path_ws_build_root_name
declare -g -r path_ws_user_space_root_name
declare -g -r path_tool_runtimefarm_name
declare -g -r path_tool_pythonhome_name
declare -g -r path_pkg_runtimefarm_name
declare -g -r path_pkg_pythonhome_name
declare -g -r path_run_runtimefarm_name
declare -g -r path_run_pythonhome_name
declare -g -r path_run_excluderoot_runtimefarm_name
declare -g -r path_run_excluderoot_pythonhome_name
declare -g -r path_devrun_runtimefarm_name
declare -g -r path_devrun_pythonhome_name
declare -g -r path_devrun_excluderoot_runtimefarm_name
declare -g -r path_devrun_excluderoot_pythonhome_name
declare -a -r -g path_all_names
