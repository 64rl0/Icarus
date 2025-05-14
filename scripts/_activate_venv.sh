# Select the correct venv with the tools installed
devdsk="devdsk8"
python_runtime="python3.11"

function echo_project_root() {
    # Display Project info
    echo -e "\n${bold_green}${hammer_and_wrench} Project Root:${end}"
    echo "${project_root_dir_abs}"
}

function activate_venv() {
    # Use brazil runtime farm
    if [[ -d "${project_root_dir_abs}/build/private" ]]; then
        brazil_bin_dir="$(brazil-path testrun.runtimefarm)/${python_runtime}/bin"
    fi

    # Use project build_venv venv
    if [[ -d "${project_root_dir_abs}/build_venv" ]]; then
        path_to_venv_root="${project_root_dir_abs}/build_venv"
        venv_name="venv (build_venv)"
    # Use DevDsk dev_tools venv if we are on a DevDsk
    elif [[ -d "${HOME}/${devdsk}" ]]; then
        path_to_venv_root="${HOME}/${devdsk}/venvs/dev_tools"
        venv_name="venv DevDsk (dev_tools)"
    # Use Dropbox dev_tools venv if we are on local macbook
    elif [[ -d "${HOME}/Library/CloudStorage/Dropbox" ]]; then
        path_to_venv_root="${HOME}/Library/CloudStorage/Dropbox/SDE/VirtualEnvs/dev_tools"
        venv_name="venv Dropbox (dev_tools)"
    fi

    # Display Project info
    echo_project_root

    # Activate brazil runtime env first as it takes precedence
    if [[ -n "${brazil_bin_dir}" ]]; then
        OLD_PATH="${PATH}"
        PATH="${brazil_bin_dir}:${PATH}"
        venv_name="Brazil ENV"
        echo -e "\n${bold_green}${green_check_mark} Virtual environment activated:${end}"
        echo -e "${brazil_bin_dir}"
    # Activate venv if we are not in brazil venv
    elif [[ -n "${path_to_venv_root}" ]]; then
        source "${path_to_venv_root}/bin/activate"
        echo -e "\n${bold_green}${green_check_mark} Virtual environment activated:${end}"
        echo -e "venv: ${VIRTUAL_ENV}"
    #  Cannot activate any venv
    else
        echo -e "\n${bold_red}Cannot find any venv to activate!${end}"
        echo -e "${bold_red}Have you selected the correct DevDsk and/or build_venv in the formatter file?${end}"
        echo -e "${bold_red}Run 'make build' to build a local build_venv in ${project_root_dir_abs}/build_venv${end}\n"
        exit 1
    fi

    # Set runtime to be used in summary
    runtime="${bold_yellow}Runtime:${end} \n--| $(python3 --version)\n--| ${venv_name}"

    # Display env info
    echo -e "OS Version: $(uname)"
    echo -e "Kernel Version: $(uname -r)"
    echo -e "running: $(python3 --version)"
    echo
}

activate_venv
