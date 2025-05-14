function deactivate_venv() {
    if [[ -n "${OLD_PATH}" ]]; then
        PATH="${OLD_PATH}"
    else
        deactivate
    fi
    echo -e "\n${bold_yellow}${warning_sign} Virtual environment deactivated!${end}"
    echo
    echo
}

deactivate_venv
