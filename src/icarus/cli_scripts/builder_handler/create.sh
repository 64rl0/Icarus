#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/create.sh
# Created 1/20/25 - 10:44 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs

# Sourcing base file
. "${cli_scripts_dir_abs}/base.sh" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
python_package_init() {
    local package_language package_name_pascal_case package_name_snake_case package_name_dashed absolute_current_path package_absolute_path

    validate_command "git"

    package_language="${1}"
    package_name_pascal_case="${2}"
    package_name_snake_case="${3}"
    package_name_dashed="${4}"

    absolute_current_path="$(realpath "$(pwd)")"
    package_absolute_path="${absolute_current_path}/${package_name_pascal_case}"

    if [[ -d "${package_absolute_path}" ]]; then
        echo_error "[ABORT] Package \`${package_name_pascal_case}\` already exists."
        exit 1
    fi

    echo -e "\nMaking package directory: ${absolute_current_path}/${package_name_pascal_case}..."
    mkdir -p -- "${package_absolute_path}"
    chmod 755 "${package_absolute_path}"
    echo

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
        find "${package_absolute_path}" -type f -exec sed -i '' "s/ProjectLanguageHere/${package_language}/g" {} \;
    else
        # Linux
        find "${package_absolute_path}" -type f -exec sed -i "s/ProjectNameHere/${package_name_pascal_case}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i "s/project_name_here/${package_name_snake_case}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i "s/project-name-here/${package_name_dashed}/g" {} \;
        find "${package_absolute_path}" -type f -exec sed -i "s/ProjectLanguageHere/${package_language}/g" {} \;
    fi

    echo -e "\nInitiating Git repository..."
    cd "${package_absolute_path}"
    git init
    git add .
    git commit -q -m "Initial commit for ${package_name_pascal_case} automatically created by ${cli_name} builder create"

    echo -e "\n${bold_green}${green_check_mark} Package ${package_name_pascal_case} successfully created!${end}"
}

function main() {
    if [[ "${1}" == 'Python3' ]]; then
        python_package_init "$@"
    else
        echo -e "Invalid package language: ${1}"
    fi
}

main "$@"
