# Icarus CLI
&nbsp;
# Usage

### `icarus [COMMAND] [ARGS] [OPTIONS]`

`COMMAND` Specifies the operation or environment to configure or manage.

`ARGS` Additional arguments or flags that control the behavior of the `[COMMAND]`. These vary depending on the chosen command.

`OPTIONS` Modifiers that further customize the behavior of `[ARGS]`. Options can adjust how commands and arguments behave or extend their functionality.

&nbsp;
# Commands

### `-h | --help`

Displays the help information detailing usage and command options.

&nbsp;
## --amazon
Utilities for managing and automating tasks within Amazon environments.

### `--auth-init`

Initializes midway authentication by setting up necessary credentials on the localhost and optionally on specified remote Developer Desks. This command can accept multiple IDs. If you want to pass additional args to the underlying mwinit program, then can use the flag `--mw-args` to pass them across, only one arg for mwinit is accepted for each `--mw-args`. 

- `[-i]` Specify one or more Developer Desk IDs to initialize authentication simultaneously.
- `[--mw-args]` Specify one arg to pass to mwinit.
- Example: `icarus --amazon --auth-init -i 1 2 3`
- Example: `icarus --amazon --auth-init -i 1 2 3 --mw-args -s`

### `--auth-init-exp`

Initializes midway authentication by setting up necessary credentials on the localhost and optionally on specified remote Developer Desks. This command can accept multiple IDs. If you want to pass additional args to the underlying mwinit program, then can use the flag `--mw-args` to pass them across, only one arg for mwinit is accepted for each `--mw-args`.
This command uses the expect program to pass the MWPIN to mwinit so that you will only need to tap your security key.
You must export the variable MWPIN set to your security key pin.

- `[-i]` Specify one or more Developer Desk IDs to initialize authentication simultaneously.
- `[--mw-args]` Specify one arg to pass to mwinit.
- Example: `icarus --amazon --auth-init-exp -i 1 2 3`
- Example: `icarus --amazon --auth-init-exp -i 1 2 3 --mw-args -s`

### `--midway-cookie`

Checks the validity of the current authentication cookies to ensure sessions are still valid.

### `--devdsk-formation`

Executes configuration scripts on a specified remote Developer Desk.

- `-i` Mandatory identifier for the Developer Desk.
- Example: `icarus --amazon --devdsk-formation -i 4`

### `--update-hosts`

Updates the `/etc/hosts` file with IP addresses for network configuration.

### `--update-hosts-d`

Install a LaunchDaemon to update the `/etc/hosts` file every hour.

### `--brazil-setup`

Create case-sensitive volumes:
- 'workplace'
- 'brazil-pkg-cache'

### `--spurdog-ro`

Check membership for Spurdog Program.

- `-u` Mandatory identifier for the Amazon User Alias.
- `--auth` Run mwinit before querying.
- Example: `icarus --amazon --spurdog-ro -u carlogtt`
- Example: `icarus --amazon --spurdog-ro -u carlogtt --auth`

&nbsp;
## --builder
Tools and utilities to aid in software development processes.

### `--python-package-init`

Creates a new Python package directory structure in the current working directory using the specified package name in PascalCase.

- `-n` Specifies the name of the Python package.
- Example: `icarus --builder --python-package-init -n MyNewPackage`

### `--dotfiles-update`

Update dotfiles from their specified repository.

&nbsp;
## --macos
Features designed to manage and secure MacOS systems.

### `--find-unencrypted-volumes`

Scans and lists all unencrypted volumes on the system, aiding in security assessments.

### `--make-encrypted-volume`

Creates a new encrypted APFS volume with an optional quota.

- `-n` Name of the volume.
- `[-q]` Quota for the volume in GB (optional).
- Example: `icarus --macos --make-encrypted-volume -n SecureVolume -q 50g`

### `--encrypt-volume`

Encrypts an existing APFS volume, enhancing data security.

- `-n` Name of the volume to encrypt.
- Example: `icarus --macos --encrypt-volume -n ExistingVolume`

### `--mount-volume`

Mounts a specified volume at a given mount point.

- `-n` Name of the volume.
- `-p` Mount point path.
- Example: `icarus --macos --mount-volume -n MyVolume -p /mnt/myvolume`

### `--install-launchd`

Installs a LaunchDaemon that automatically mounts a specified volume at system startup.

- `-n` Volume name.
- `-p` Mount point.
- Example: `icarus --macos --install-launchd -n BootVolume -p /System/Volumes/BootVolume`

&nbsp;
## --unison
Controls for managing the Unison file synchronization tool.

### `--status`

Checks and reports the running status of each configured Unison profile.

### `--start`

Starts synchronization for one or more Unison profiles.

### `--stop`

Stops synchronization for one or more active Unison profiles.

### `--clear-locks`

Clears synchronization locks on the localhost. If the `-i` option is provided, it additionally clears the locks on the specified remote Developer Desk

- `[-i]` Developer Desk ID (optional).
- Example
    - Local Only: `icarus --unison --clear-locks`
    - Remote Specific: `icarus --unison --clear-locks -i 3`

### `--install-launchd`

Installs a LaunchDaemon to automatically start Unison at system startup.
