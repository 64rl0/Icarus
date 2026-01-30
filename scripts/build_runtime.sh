#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# scripts/build_runtime.sh
# Created 3/2/24 - 8:09 AM UK Time (London) by carlogtt

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

declare -r bold_green=$'\033[1;32m'
declare -r end=$'\033[0m'
declare -r sparkles="\xE2\x9C\xA8"

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
project_root_dir_abs="$(realpath -- "${script_dir_abs}/..")"
declare -r project_root_dir_abs

platform_id="$(bash "${script_dir_abs}/platform_id.sh")"
declare -r platform_id

declare -r venv_name="runtime_env"
declare -r python_full_version_for_venv="3.13.11"
declare -r download_url="https://github.com/64rl0/PythonRuntime/releases/download/cpython-${python_full_version_for_venv}-${platform_id}/cpython-${python_full_version_for_venv}-${platform_id}.tar.gz"
declare -r pybin="${project_root_dir_abs}/${venv_name}/env/bin/python3"

# Prep env
echo -e "\n\n${bold_green}${sparkles} Preparing Runtime env...${end}"
rm -rf "${project_root_dir_abs:?}/${venv_name}"
mkdir -p "${project_root_dir_abs}/${venv_name}"
echo -e "done!"

# Download Python Runtime
echo -e "\n\n${bold_green}${sparkles} Downloading Python Runtime...${end}"
curl -L "${download_url}" -o "${project_root_dir_abs}/${venv_name}/cpython.tar.gz"
tar -xzf "${project_root_dir_abs}/${venv_name}/cpython.tar.gz" -C "${project_root_dir_abs}/${venv_name}"
mv "${project_root_dir_abs}/${venv_name}/${python_full_version_for_venv}" "${project_root_dir_abs}/${venv_name}/env"
rm -rf "${project_root_dir_abs}/${venv_name}/cpython.tar.gz"

# Install requirements
echo -e "\n\n${bold_green}${sparkles} Installing requirements...${end}"
"${pybin}" -m pip install --upgrade pip
"${pybin}" -m pip install "${project_root_dir_abs}"

# Cleanup
rm -rf "${project_root_dir_abs}/build"
rm -rf "${project_root_dir_abs}/src/icarus.egg-info"

# Build complete!
echo -e "\n\n${bold_green}${sparkles} ${venv_name} build Complete & Ready for use!${end}"
