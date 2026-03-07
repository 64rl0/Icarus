#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/cli_scripts/builder_handler/builder_base.sh
# Created 2/14/26 - 9:10 AM UK Time (London) by carlogtt

function declare_path_names() {
    # This function will declare all the path names as global readonly variables

    # SIMPLE RECIPE
    path_platform_identifier_name="platform-identifier"
    declare -g -r path_platform_identifier_name
    path_ws_root_name="workspace.root"
    declare -g -r path_ws_root_name
    path_ws_src_root_name="workspace.src-root"
    declare -g -r path_ws_src_root_name
    path_ws_build_root_name="workspace.build-root"
    declare -g -r path_ws_build_root_name
    path_ws_user_space_root_name="workspace.user-space-root"
    declare -g -r path_ws_user_space_root_name

    # CONFIG RECIPE
    path_pkg_config_name="pkg.config"
    declare -g -r path_pkg_config_name

    # LANGUAGE RECIPE
    path_pkg_language_name="pkg.language"
    declare -g -r path_pkg_language_name

    # NAME RECIPE
    path_pkg_name_pascal_name="pkg.name-pascal"
    declare -g -r path_pkg_name_pascal_name
    path_pkg_name_snake_name="pkg.name-snake"
    declare -g -r path_pkg_name_snake_name
    path_pkg_name_dashed_name="pkg.name-dashed"
    declare -g -r path_pkg_name_dashed_name
    path_tool_name_name="tool.name"
    declare -g -r path_tool_name_name
    path_run_name_name="run.name"
    declare -g -r path_run_name_name
    path_run_excluderoot_name_name="run_excluderoot.name"
    declare -g -r path_run_excluderoot_name_name
    path_devrun_name_name="devrun.name"
    declare -g -r path_devrun_name_name
    path_devrun_excluderoot_name_name="devrun_excluderoot.name"
    declare -g -r path_devrun_excluderoot_name_name

    # VERSION RECIPE
    path_pkg_version_full_name="pkg.version"
    declare -g -r path_pkg_version_full_name
    path_pkg_version_major_name="pkg.version-major"
    declare -g -r path_pkg_version_major_name
    path_pkg_version_minor_name="pkg.version-minor"
    declare -g -r path_pkg_version_minor_name
    path_pkg_version_patch_name="pkg.version-patch"
    declare -g -r path_pkg_version_patch_name
    path_tool_version_full_name="tool.version"
    declare -g -r path_tool_version_full_name
    path_run_version_full_name="run.version"
    declare -g -r path_run_version_full_name
    path_run_excluderoot_version_full_name="run_excluderoot.version"
    declare -g -r path_run_excluderoot_version_full_name
    path_devrun_version_full_name="devrun.version"
    declare -g -r path_devrun_version_full_name
    path_devrun_excluderoot_version_full_name="devrun_excluderoot.version"
    declare -g -r path_devrun_excluderoot_version_full_name

    # RUNTIMEFARM RECIPE
    path_pkg_runtimefarm_name="pkg.runtimefarm"
    declare -g -r path_pkg_runtimefarm_name
    path_tool_runtimefarm_name="tool.runtimefarm"
    declare -g -r path_tool_runtimefarm_name
    path_run_runtimefarm_name="run.runtimefarm"
    declare -g -r path_run_runtimefarm_name
    path_run_excluderoot_runtimefarm_name="run_excluderoot.runtimefarm"
    declare -g -r path_run_excluderoot_runtimefarm_name
    path_devrun_runtimefarm_name="devrun.runtimefarm"
    declare -g -r path_devrun_runtimefarm_name
    path_devrun_excluderoot_runtimefarm_name="devrun_excluderoot.runtimefarm"
    declare -g -r path_devrun_excluderoot_runtimefarm_name

    # PYTHONHOME RECIPE
    path_pkg_pythonhome_name="pkg.pythonhome"
    declare -g -r path_pkg_pythonhome_name
    path_tool_pythonhome_name="tool.pythonhome"
    declare -g -r path_tool_pythonhome_name
    path_run_pythonhome_name="run.pythonhome"
    declare -g -r path_run_pythonhome_name
    path_run_excluderoot_pythonhome_name="run_excluderoot.pythonhome"
    declare -g -r path_run_excluderoot_pythonhome_name
    path_devrun_pythonhome_name="devrun.pythonhome"
    declare -g -r path_devrun_pythonhome_name
    path_devrun_excluderoot_pythonhome_name="devrun_excluderoot.pythonhome"
    declare -g -r path_devrun_excluderoot_pythonhome_name

    # PYTHONPATH RECIPE
    path_pkg_pythonpath_name="pkg.pythonpath"
    declare -g -r path_pkg_pythonpath_name
    path_tool_pythonpath_name="tool.pythonpath"
    declare -g -r path_tool_pythonpath_name
    path_run_pythonpath_name="run.pythonpath"
    declare -g -r path_run_pythonpath_name
    path_run_excluderoot_pythonpath_name="run_excluderoot.pythonpath"
    declare -g -r path_run_excluderoot_pythonpath_name
    path_devrun_pythonpath_name="devrun.pythonpath"
    declare -g -r path_devrun_pythonpath_name
    path_devrun_excluderoot_pythonpath_name="devrun_excluderoot.pythonpath"
    declare -g -r path_devrun_excluderoot_pythonpath_name

    # BIN RECIPE
    path_pkg_bin_name="pkg.bin"
    declare -g -r path_pkg_bin_name
    path_tool_bin_name="tool.bin"
    declare -g -r path_tool_bin_name
    path_run_bin_name="run.bin"
    declare -g -r path_run_bin_name
    path_run_excluderoot_bin_name="run_excluderoot.bin"
    declare -g -r path_run_excluderoot_bin_name
    path_devrun_bin_name="devrun.bin"
    declare -g -r path_devrun_bin_name
    path_devrun_excluderoot_bin_name="devrun_excluderoot.bin"
    declare -g -r path_devrun_excluderoot_bin_name

    # ARTIFACT RECIPE
    path_pkg_artifact_name="pkg.artifact"
    declare -g -r path_pkg_artifact_name

    path_all_names=(
        "${path_platform_identifier_name}"
        "${path_ws_root_name}"
        "${path_ws_src_root_name}"
        "${path_ws_build_root_name}"
        "${path_ws_user_space_root_name}"

        "${path_pkg_config_name}"

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

        "${path_pkg_pythonpath_name}"
        "${path_tool_pythonpath_name}"
        "${path_run_pythonpath_name}"
        "${path_run_excluderoot_pythonpath_name}"
        "${path_devrun_pythonpath_name}"
        "${path_devrun_excluderoot_pythonpath_name}"

        "${path_pkg_bin_name}"
        "${path_tool_bin_name}"
        "${path_run_bin_name}"
        "${path_run_excluderoot_bin_name}"
        "${path_devrun_bin_name}"
        "${path_devrun_excluderoot_bin_name}"

        "${path_pkg_artifact_name}"
    )
    declare -a -r -g path_all_names
}

function declare_global_vars() {
    # These variables are passed in by the cli parser
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
    declare -r -g pypi
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
    declare -r -g cache_root_dir
    declare -r -g cache_clean
    declare -r -g cache_size

    # These variables are shared across the build system
    cache_root="${tmp_root}/builder/cache"
    declare -r -g cache_root

    runtime_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/runtime"
    declare -r -g runtime_root

    path_root="${project_root_dir_abs}/${build_root_dir}/${platform_identifier}/env/path"
    declare -r -g path_root

    path_cache_root="${path_root}/path-cache"
    declare -r -g path_cache_root

    report_filepath="file://${project_root_dir_abs}/.icarus/report/index.html"
    declare -g -r report_filepath
}

function bootstrap_workspace() {
    # This function will create the basic structure for the workspace
    local dir
    local -a root_tree

    root_tree=(
        "${cache_root}"
        "${runtime_root}"
        "${path_root}"
        "${path_cache_root}"
    )

    for dir in "${root_tree[@]}"; do
        mkdir -p "${dir}" || {
            echo_error "Failed to create '${dir}'." "errexit"
        }
    done
}
