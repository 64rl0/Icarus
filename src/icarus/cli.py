# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/cli.py
# Created 1/20/25 - 6:52 PM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

"""
This module ...
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
import argparse

# Local Folder (Relative) Imports
from . import config, handlers, utils

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'initialize_parser',
    'parse_args',
    'execute',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)

# Type aliases
#


def initialize_parser() -> argparse.ArgumentParser:
    """
    Initializes and configures the argument parser for the CLI
    application.

    :return: The configured argument parser object.
    """

    tl_par = utils.IcarusArgumentParser(
        prog=config.CLI_NAME,
        description=config.CLI_DESCRIPTION,
        epilog=config.CLI_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    tl_par.add_argument(
        '--version',
        '--update',
        required=False,
        action='store_const',
        const='--version',
        default='',
        help='display version information and exit',
    )

    tl_par.add_argument(
        '--verbose',
        '-v',
        required=False,
        action='count',
        default=0,
        help='increase output verbosity',
    )

    sl_par = tl_par.add_subparsers(
        title='commands', dest='tl_command', required=False, metavar='<command>'
    )

    # =============
    # Main Commands
    # =============
    # Amazon
    amazon_par = sl_par.add_parser(
        name='amazon',
        help='utilities for Amazon environment',
        description=(
            'description:\n  The \'icarus amazon\' command provides various utilities for'
            ' interacting with and managing the Amazon environment.\n  These tools are designed'
            ' to streamline workflows, simplify setup, and ensure proper configuration for'
            ' development\n  and operational tasks within Amazon\'s infrastructure.'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    amazon_sub = amazon_par.add_subparsers(
        title='subcommands', dest='amazon_command', required=True, metavar='<subcommand>'
    )

    # Builder
    builder_par = sl_par.add_parser(
        name='builder',
        help='utilities for software development',
        description=(
            'description:\n  The \'icarus builder\' command provides utilities for software'
            ' development. These tools are designed to\n  automate tasks, manage development'
            ' environments, and simplify workflows for creating, maintaining, and\n  deploying'
            ' software projects.'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_sub = builder_par.add_subparsers(
        title='subcommands', dest='builder_command', required=False, metavar='<subcommand>'
    )

    # MacOS
    macos_par = sl_par.add_parser(
        name='macos',
        help='utilities for macOS',
        description=(
            'description:\n  The \'icarus macos\' command provides utilities for managing'
            ' macOS-specific tasks. These include tools\n  for handling encrypted volumes,'
            ' managing mount points, and automating startup configurations to enhance\n  macOS'
            ' system workflows.'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    macos_sub = macos_par.add_subparsers(
        title='subcommands', dest='macos_command', required=True, metavar='<subcommand>'
    )

    # Unison
    unison_par = sl_par.add_parser(
        name='unison',
        help='utilities to manage Unison demon',
        description=(
            'description:\n  The \'icarus unison\' command provides tools for managing Unison'
            ' profiles. Unison is used to synchronize\n  files across devices, and this command'
            ' simplifies tasks such as starting and stopping syncs, checking\n  profile status,'
            ' clearing locks, and automating startup configuration for Unison operations.'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    unison_sub = unison_par.add_subparsers(
        title='subcommands', dest='unison_command', required=True, metavar='<subcommand>'
    )

    # Provision
    provision_par = sl_par.add_parser(
        name='provision',
        help='utilities for provisioning and maintaining a workstation',
        description=(
            'description:\n'
            '  The \'icarus provision\' command offers utilities for provisioning and'
            ' maintaining a workstation.\n  Its tools streamline first-time'
            ' machine setup and ongoing upkeep by automating tasks. Use this\n  command'
            ' to ensure your local environment stays aligned with project standards'
            ' and ready for\n  productive work.'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    provision_sub = provision_par.add_subparsers(
        title='subcommands', dest='provision_command', required=True, metavar='<subcommand>'
    )

    # ==================
    # Amazon subcommands
    # ==================
    amazon_auth_init_parent_parser = utils.IcarusArgumentParser(add_help=False)
    amazon_auth_init_parent_parser.add_argument(
        '-i',
        required=False,
        action='extend',
        nargs='+',
        metavar='IDs',
        default=[],
        help='takes multiple DevDsk IDs i.e. -i 1 2 3',
    )
    amazon_auth_init_parent_parser.add_argument(
        '--mw-args',
        required=False,
        action='append',
        metavar='ARG',
        default=[],
        help='specify one arg to pass to mwinit i.e. --mw-arg=--ncl',
    )

    amazon_sub.add_parser(
        name='auth-init',
        parents=[amazon_auth_init_parent_parser],
        help='run midway authentication on localhost and optional remote DevDsk(s)',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    amazon_sub.add_parser(
        name='auth-init-exp',
        parents=[amazon_auth_init_parent_parser],
        help='run midway authentication express on localhost and optional remote DevDsk(s)',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    amazon_midway_cookie = amazon_sub.add_parser(
        name='midway-cookie',
        help='check the cookies validity',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    amazon_midway_cookie.add_argument(
        '--filepath',
        required=False,
        metavar='PATH',
        default='',
        help='the filepath of the cookie file, if none then ~/.midway/cookie',
    )

    amazon_devdsk_formation = amazon_sub.add_parser(
        name='devdsk-formation',
        help='run DevDsk Formation on a remote DevDsk',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    amazon_devdsk_formation.add_argument('-i', required=True, metavar='ID', help='the DevDsk ID')

    amazon_sub.add_parser(
        name='update-hosts',
        help='update /etc/hosts file',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    amazon_sub.add_parser(
        name='update-hosts-d',
        help='install a LaunchDaemon to update the hosts file every hour',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    amazon_sub.add_parser(
        name='brazil-setup',
        help='creating case-sensitive volumes (\'workplace\' and \'brazil-pkg-cache\')',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    amazon_spurdog_ro = amazon_sub.add_parser(
        name='spurdog-ro',
        help='check membership for Spurdog Program',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    amazon_spurdog_ro.add_argument(
        '-u', required=True, metavar='ALIAS', help='username to check Spurdog Program membership'
    )
    amazon_spurdog_ro.add_argument(
        '--auth',
        required=False,
        action='store_const',
        const='--auth',
        default='',
        help='run mwinit before querying',
    )

    # ===================
    # Builder subcommands
    # ===================
    builder_par.add_argument(
        '--exec',
        required=False,
        nargs='+',
        metavar='CMD',
        default='',
        help='run a command inside the runtime environment',
    )
    builder_par.add_argument(
        '--build',
        required=False,
        action='store_const',
        const='--build',
        default='',
        help='create/re-create the project runtime environment',
    )
    builder_par.add_argument(
        '--clean',
        required=False,
        action='store_const',
        const='--clean',
        default='',
        help='clean the project runtime environment',
    )
    builder_par.add_argument(
        '--release',
        required=False,
        action='store_const',
        const='--release',
        default='',
        help='run the full “release” pipeline',
    )
    builder_par.add_argument(
        '--format',
        required=False,
        action='store_const',
        const='--format',
        default='',
        help='run the formatting tools',
    )
    builder_par.add_argument(
        '--test',
        required=False,
        action='store_const',
        const='--test',
        default='',
        help='run the automated test suite',
    )
    builder_par.add_argument(
        '--isort',
        required=False,
        action='store_const',
        const='--isort',
        default='',
        help='sort python imports with isort',
    )
    builder_par.add_argument(
        '--black',
        required=False,
        action='store_const',
        const='--black',
        default='',
        help='re-format python code with black',
    )
    builder_par.add_argument(
        '--flake8',
        required=False,
        action='store_const',
        const='--flake8',
        default='',
        help='run static analysis with flake8',
    )
    builder_par.add_argument(
        '--mypy',
        required=False,
        action='store_const',
        const='--mypy',
        default='',
        help='type-check the codebase with mypy',
    )
    builder_par.add_argument(
        '--shfmt',
        required=False,
        action='store_const',
        const='--shfmt',
        default='',
        help='format shell scripts with shfmt',
    )
    builder_par.add_argument(
        '--whitespaces',
        required=False,
        action='store_const',
        const='--whitespaces',
        default='',
        help='normalize mixed or excessive whitespace',
    )
    builder_par.add_argument(
        '--trailing',
        required=False,
        action='store_const',
        const='--trailing',
        default='',
        help='remove trailing whitespace',
    )
    builder_par.add_argument(
        '--eofnewline',
        required=False,
        action='store_const',
        const='--eofnewline',
        default='',
        help='ensure files end with a single newline',
    )
    builder_par.add_argument(
        '--eolnorm',
        required=False,
        action='store_const',
        const='--eolnorm',
        default='',
        help='normalize line endings to LF',
    )
    builder_par.add_argument(
        '--gitleaks',
        required=False,
        action='store_const',
        const='--gitleaks',
        default='',
        help='scan for secrets with gitleaks',
    )
    builder_par.add_argument(
        '--pytest',
        required=False,
        action='store_const',
        const='--pytest',
        default='',
        help='execute the unit/integration-test suite via pytest',
    )
    builder_par.add_argument(
        '--docs',
        required=False,
        action='store_const',
        const='--docs',
        default='',
        help='generate user documentation',
    )

    builder_create = builder_sub.add_parser(
        name='create',
        help='initiate a new package in the current folder',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_create.add_argument(
        '-n',
        required=True,
        metavar='PACKAGE_NAME',
        help='the package name in PascalCase',
    )
    builder_create.add_argument(
        '-l',
        required=True,
        choices=['Python3'],
        metavar='PACKAGE_LANGUAGE',
        help='the package name language',
    )

    builder_build = builder_sub.add_parser(
        name='build',
        help='create/re-create the project runtime environment',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_build.set_defaults(build='--build')

    builder_clean = builder_sub.add_parser(
        name='clean',
        help='clean the project runtime environment',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_clean.set_defaults(clean='--clean')

    builder_release = builder_sub.add_parser(
        name='release',
        help='run the full “release” pipeline',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_release.set_defaults(release='--release')

    builder_format = builder_sub.add_parser(
        name='format',
        help='run the formatting tools',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_format.set_defaults(format='--format')

    builder_test = builder_sub.add_parser(
        name='test',
        help='run the automated test suite',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_test.set_defaults(test='--test')

    builder_sub.add_parser(
        name='build-runtime',
        help='build the interpreter runtime',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    builder_exec = builder_sub.add_parser(
        name='exec',
        help='run a command inside the runtime environment',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    builder_exec.add_argument(
        'exec',
        nargs='+',
        metavar='CMD',
        default='',
        help='command to run inside the runtime environment',
    )

    # =================
    # MacOS subcommands
    # =================
    macos_sub.add_parser(
        name='find-unencrypted-volumes',
        help='find all unencrypted volumes',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    macos_make_encrypted_volume = macos_sub.add_parser(
        name='make-encrypted-volume',
        help='make an encrypted APFS volume',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    macos_make_encrypted_volume.add_argument(
        '-n', required=True, metavar='NAME', help='name of the encrypted volume'
    )
    macos_make_encrypted_volume.add_argument(
        '-q',
        required=False,
        metavar='QUOTA',
        default='',
        help='size of the encrypted volume in Gb i.e. -q 50g',
    )

    macos_encrypt_volume = macos_sub.add_parser(
        name='encrypt-volume',
        help='encrypt an APFS volume',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    macos_encrypt_volume.add_argument(
        '-n', required=True, metavar='NAME', help='name of the volume to encrypt'
    )

    macos_mount_volume = macos_sub.add_parser(
        name='mount-volume',
        help='mount the specified volume at the specified mount point',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    macos_mount_volume.add_argument(
        '-n', required=True, metavar='NAME', help='name of the volume to mount'
    )
    macos_mount_volume.add_argument(
        '-p', required=True, metavar='MOUNT', help='mount point for the volume'
    )

    macos_mount_at_startup = macos_sub.add_parser(
        name='mount-at-startup',
        help='install a LaunchDaemon to mount the volume at System Startup',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    macos_mount_at_startup.add_argument(
        '-n', required=True, metavar='NAME', help='name of the volume to mount'
    )
    macos_mount_at_startup.add_argument(
        '-p', required=True, metavar='MOUNT', help='mount point for the volume'
    )

    macos_sub.add_parser(
        name=f'{config.CLI_NAME}-update-daemon',
        help=f'install the {config.CLI_NAME} auto-update daemon (LaunchAgent)',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    # ==================
    # Unison subcommands
    # ==================
    unison_sub.add_parser(
        name='status',
        help='check the running status of each Unison profile',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    unison_sub.add_parser(
        name='restart',
        help='restart Unison profile(s) sync',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    unison_sub.add_parser(
        name='stop',
        help='stop Unison profile(s) sync',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    unison_clear_locks = unison_sub.add_parser(
        name='clear-locks',
        help='clear Unison locks on localhost and an optional remote DevDsk',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    unison_clear_locks.add_argument(
        '-i', required=False, metavar='ID', default='', help='the DevDsk ID'
    )

    unison_sub.add_parser(
        name='start-at-startup',
        help='install a LaunchDaemon to start Unison at System Startup',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    unison_sub.add_parser(
        name='run-profiles',
        help='[DO NOT USE] internally used only to run Unison profiles',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    # =====================
    # Provision subcommands
    # =====================
    provision_sub.add_parser(
        name='dotfiles-update',
        help='update dotfiles from their specified repository',
        description='',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )

    return tl_par


def parse_args(parser: argparse.ArgumentParser) -> argparse.Namespace:
    """
    Parse the command-line arguments using the provided parser.

    :param parser: The argument parser configured with the required
        commands, subcommands, and arguments.
    :return: A namespace object containing the parsed arguments and
        their values.
    """

    args = parser.parse_args()

    return args


def execute(args: argparse.Namespace) -> int:
    """
    Execute the logic based on the parsed arguments.

    This function acts as a dispatcher, routing the parsed command-line
    arguments to the appropriate handler function based on the
    `tl_command` value. Each top-level command corresponds to a specific
    handler function that implements the logic for that command.

    :param args: The parsed arguments from the command-line.
    :return: Exit code of the script.
    """

    # Check for global commands first
    if args.version:
        module_logger.debug(f"Running {args=} handler={handlers.handle_global_command.__name__}")

        return_code = handlers.handle_global_command(args=args)

        return return_code

    # Dispatch tl_command
    if args.tl_command == 'amazon':
        module_logger.debug(
            f"Running {args.tl_command=} handler={handlers.handle_amazon_command.__name__}"
        )
        return_code = handlers.handle_amazon_command(args=args)

        return return_code

    elif args.tl_command == 'builder':
        module_logger.debug(
            f"Running {args.tl_command=} handler={handlers.handle_builder_command.__name__}"
        )
        return_code = handlers.handle_builder_command(args=args)

        return return_code

    elif args.tl_command == 'macos':
        module_logger.debug(
            f"Running {args.tl_command=} handler={handlers.handle_macos_command.__name__}"
        )
        return_code = handlers.handle_macos_command(args=args)

        return return_code

    elif args.tl_command == 'unison':
        module_logger.debug(
            f"Running {args.tl_command=} handler={handlers.handle_unison_command.__name__}"
        )
        return_code = handlers.handle_unison_command(args=args)

        return return_code

    elif args.tl_command == 'provision':
        module_logger.debug(
            f"Running {args.tl_command=} handler={handlers.handle_provision_command.__name__}"
        )
        return_code = handlers.handle_provision_command(args=args)

        return return_code

    else:
        module_logger.debug(f"Running {args.tl_command=} -> this argument is required")
        raise utils.IcarusParserException('the following arguments are required: <command>')
