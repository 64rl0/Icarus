# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# docs/conf.py
# Created 5/20/25 - 11:12 AM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

"""
Configuration file for the Sphinx documentation builder.

For the full list of built-in configuration values, see the
documentation:
https://www.sphinx-doc.org/en/master/usage/configuration.html
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
import datetime

# END IMPORTS
# ======================================================================


# Project information
project = 'Icarus'
version = 'v.'
release = 'r.'
copyright = f"{datetime.datetime.now().year}, Carlo Gatti"
author = "Carlo Gatti"

# General configuration
extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.intersphinx",
    "sphinx.ext.napoleon",
    "sphinx.ext.todo",
    "sphinx.ext.viewcode",
]

# Options for templating
templates_path = ['_templates']

# Options for source files
exclude_patterns = ['Thumbs.db', '.DS_Store']
master_doc = "index"
source_suffix = {
    '.rst': 'restructuredtext',
}

# Options for HTML output
html_theme = 'alabaster'
html_static_path = ['_static']


def _keep_trailing_newline(app):
    """
    Flip the Jinja setting before the first template is rendered
    """

    app.builder.templates.environment.keep_trailing_newline = True


def setup(app):
    """
    Run as soon as the builder is initialised
    """

    app.connect("builder-inited", _keep_trailing_newline)
