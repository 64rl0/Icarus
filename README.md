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

### `-a | --auth-init [-i DEVDSK_ID]`

Initializes midway authentication by setting up necessary credentials on the localhost and optionally on specified remote Developer Desks. This command can accept multiple IDs.

- `-i` Specify one or more Developer Desk IDs to initialize authentication simultaneously.
- Example: `icarus --amazon --auth-init -i 1 2 3`

### `-c | --midway-cookie`

Checks the validity of the current authentication cookies to ensure sessions are still valid.

### `-d | --devdsk-formation -i DEVDSK_ID`

Executes configuration scripts on a specified remote Developer Desk.

- `-i` Mandatory identifier for the Developer Desk.
- Example: `icarus --amazon --devdsk-formation -i 4`

### `-s | --update-hosts`

Updates the `/etc/hosts` file with IP addresses for network configuration.

### `-u | --update-hosts-d`

Install a LaunchDaemon to update the `/etc/hosts` file every hour.

### `-b | --brazil-setup`

Create case-sensitive volumes: 
- 'workplace'
- 'brazil-pkg-cache'

### `-r | --spurdog-ro`

Check membership for Spurdog Program.

- `-u` Mandatory identifier for the Amazon User Alias.
- Example: `icarus --amazon --spurdog-ro -u carlogtt`

&nbsp;
## --builder
Tools and utilities to aid in software development processes.

### `-p | --python-package-init -n PACKAGE_NAME`

Creates a new Python package directory structure in the current working directory using the specified package name in PascalCase.

- `-n` Specifies the name of the Python package.
- Example: `icarus --builder --python-package-init -n MyNewPackage`

### `-d | --dotfiles-update`

Update dotfiles from their specified repository.

&nbsp;
## --macos
Features designed to manage and secure MacOS systems.

### `-f | --find-unencrypted-volumes`

Scans and lists all unencrypted volumes on the system, aiding in security assessments.

### `-c | --make-encrypted-volume -n VOLUME_NAME [-q QUOTA]`

Creates a new encrypted APFS volume with an optional quota.

- `-n` Name of the volume.
- `-q` Quota for the volume in GB (optional).
- Example: `icarus --macos --make-encrypted-volume -n SecureVolume -q 50g`

### `-e | --encrypt-volume -n VOLUME_NAME`

Encrypts an existing APFS volume, enhancing data security.

- `-n` Name of the volume to encrypt.
- Example: `icarus --macos --encrypt-volume -n ExistingVolume`

### `-m | --mount-volume -n VOLUME_NAME -p MOUNT_POINT`

Mounts a specified volume at a given mount point.

- `-n` Name of the volume.
- `-p` Mount point path.
- Example: `icarus --macos --mount-volume -n MyVolume -p /mnt/myvolume`

### `-l | --install-launchd -n VOLUME_NAME -p MOUNT_POINT`

Installs a LaunchDaemon that automatically mounts a specified volume at system startup.

- `-n` Volume name.
- `-p` Mount point.
- Example: `icarus --macos --install-launchd -n BootVolume -p /System/Volumes/BootVolume`

&nbsp;
## --unison
Controls for managing the Unison file synchronization tool.

### `-i | --status`

Checks and reports the running status of each configured Unison profile.

### `-s | --start`

Starts synchronization for one or more Unison profiles.

### `-k | --stop`

Stops synchronization for one or more active Unison profiles.

### `-c | --clear-locks [-i DEVDSK_ID]`

Clears synchronization locks on the localhost. If the `-i` option is provided, it additionally clears the locks on the specified remote Developer Desk

- `-i` Developer Desk ID (optional).
- Example
    - Local Only: `icarus --unison --clear-locks`
    - Remote Specific: `icarus --unison --clear-locks -i 3`

### `-l | --install-launchd`

Installs a LaunchDaemon to automatically start Unison at system startup.
