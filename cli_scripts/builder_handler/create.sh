#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/create.sh
# Created 1/20/25 - 10:44 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs
package_root_dir_abs="$(realpath -- "${cli_scripts_dir_abs}/..")"
declare -r package_root_dir_abs
cli_script_base="${cli_scripts_dir_abs}/base.sh"
declare -r cli_script_base

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
convert_to_snake_case() {
    local input_str="$1"

    # Remove leading and trailing whitespace
    local sanitized_input_str=$(echo "${input_str}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Validate input: only alphanumeric characters are allowed
    if ! [[ "${sanitized_input_str}" =~ ^[a-zA-Z0-9]+$ ]]; then
        echo ""
        return
    fi

    # Convert camelCase to snake_case
    local snake_case_str=$(echo "${sanitized_input_str}" | sed -r 's/([0-9]+)/_\1_/g; s/([a-z])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]' | sed -r 's/__/_/g; s/^_+|_+$//g')

    # Output the snake_case string
    echo "${snake_case_str}"
}

python_package_init() {
    local input_str="${1}"
    local package_language="${2}"

    # Remove leading and trailing whitespace
    local package_name_pascal_case="$(echo "${input_str}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    local package_language_cleaned="$(echo "${package_language}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    local package_name_snake_case=$(convert_to_snake_case "${package_name_pascal_case}")
    local package_name_dashed="$(echo "${package_name_snake_case}" | sed 's/_/-/g')"
    local absolute_current_path="$(realpath "$(pwd)")"
    local package_absolute_path="${absolute_current_path}/${package_name_pascal_case}"
    local package_src_folder="${package_absolute_path}/src/${package_name_snake_case}"

    if [[ -z "${package_name_snake_case}" ]]; then
        echo -e "Invalid input: only alphanumeric characters are allowed in the package name."
        exit 1
    else
        echo -e "Package name: ${package_name_pascal_case} => (${package_name_snake_case})"
    fi

    echo -e "\nMaking package directory: ${absolute_current_path}/${package_name_pascal_case}..."
    if [[ -d "${package_absolute_path}" ]]; then
        echo "Package \`${package_name_pascal_case}\` already exists."
        exit 1
    fi

    mkdir -p -- "${package_absolute_path}"
    chmod 755 "${package_absolute_path}"
    git clone "git@github.com:64rl0/PythonTemplatePackage.git" "${package_absolute_path}"

    # Remove git folder from cloned template
    rm -rf "${package_absolute_path}/.git"

    # Rename main package folder
    mv "${package_absolute_path}/src/project_name_here" "${package_absolute_path}/src/${package_name_snake_case}"

    # Create .env file
    touch "${package_absolute_path}/.env"

    # Rename package placeholders
    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS
        find "${package_absolute_path}" -type f -exec sed -i '' "s/ProjectNameHere/${package_name_pascal_case}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i '' "s/project_name_here/${package_name_snake_case}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i '' "s/project-name-here/${package_name_dashed}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i '' "s/ProjectLanguageHere/${package_language_cleaned}/g" {} \;
    else
        # Linux
        find "${package_absolute_path}" -type f -exec sed -i "s/ProjectNameHere/${package_name_pascal_case}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i "s/project_name_here/${package_name_snake_case}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i "s/project-name-here/${package_name_dashed}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i "s/ProjectLanguageHere/${package_language_cleaned}/g" {} \;
    fi

    echo -e "\nInitiating Git repository..."
    cd "${package_absolute_path}"
    git init
    git add .
    git commit -q -m "FEAT: Initial commit for ${package_name_pascal_case} automatically created by ${cli_name} create"

    echo -e "\n${bold_green}${green_check_mark} Package ${package_name_pascal_case} successfully created!${end}"
}

function main() {
    if [[ "${2}" == 'Python3' ]]; then
        python_package_init "$@"
    else
        echo -e "Invalid package language: ${2}"
    fi
}

main "$@"
