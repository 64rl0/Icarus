#!/usr/bin/env python3

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# bin/icarus.py
# Created 1/18/25 - 6:35 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL


# Standard Library Imports
import os
import subprocess
import sys


def main():
    # Determine the base path at runtime
    this_path = os.path.dirname(os.path.abspath(__file__))
    root_path = os.path.join(this_path, '..')

    # Locate the Python interpreter in the bundled venv
    venv_python = os.path.join(root_path, 'build_venv/bin/python3')

    # Path to main script
    main_script = os.path.join(root_path, 'entrypoint.py')

    # Check if the bundled interpreter exists
    if not os.path.exists(venv_python):
        print("Python interpreter not found. Please create it.")
        sys.exit(1)

    # Run the main script with the bundled interpreter
    command = [venv_python, main_script] + sys.argv[1:]
    result = subprocess.run(command)

    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
