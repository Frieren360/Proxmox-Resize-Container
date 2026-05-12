# Proxmox Resize Container

This utility provides an automated way to resize LXC container disks in Proxmox. It simplifies the process of shrinking ZFS-backed container volumes through a straightforward command-line interface.

## Overview

Resizing Proxmox LXC container disks manually involves multiple steps and manual ZFS commands. This script automates the process by allowing you to specify the target disk size and container IDs, and it handles the resize operation for you.

## Prerequisites

- Proxmox environment with LXC containers
- Root access or sudo privileges on the Proxmox node
- All target containers must be powered off before resizing
- A recent backup of your containers (highly recommended)

## Before You Start: Backup Your Containers

It is critical to create a backup before attempting to resize any disks. This ensures you can restore your system if something goes wrong.

To create a backup via the Proxmox Web UI:

1. Navigate to your VM settings
2. Go to the Backup section
3. Click "Backup now"
4. Wait for the task to complete and display "TASK OK" in the logs
5. Verify the backup appears in your backup list

## Installation

1. Clone or download this repository to your Proxmox node
2. Make the script executable:
   ```
   chmod +x proxmox-resize.sh
   ```
3. Ensure both `proxmox-resize.sh` and `functions.sh` are in the same directory

## Usage

### Basic Command

```
./proxmox-resize.sh -s SIZE VMID [VMID2] [VMID3] ...
```

### Parameters

- `-s SIZE`: The target disk size for the container. Use integer or decimal values followed by size units (K, M, or G). For example: 64G, 512M, 100K
- `VMID`: The Virtual Machine ID of the container to resize. You can specify multiple VMIDs separated by spaces to resize multiple containers in one command

### Examples

Resize a single container (VMID 100) to 64GB:
```
./proxmox-resize.sh -s 64G 100
```

Resize multiple containers (VMIDs 100, 101, 102) to 32GB each:
```
./proxmox-resize.sh -s 32G 100 101 102
```

Resize a container to 256MB:
```
./proxmox-resize.sh -s 256M 100
```

## How It Works

The script performs the following operations for each container:

1. Looks up the ZFS subvolume name corresponding to the VMID
2. Retrieves the current disk usage for that subvolume
3. Validates that the current usage is less than the target size (you cannot shrink below the amount of data actually used)
4. Sets the ZFS refquota to enforce the new disk size limit

### Finding Your Container's VMID

If you need to find the VMID of a container, use these ZFS commands:

List all ZFS subvolumes:
```
zfs list
```

Search for a specific container by VMID:
```
zfs list | grep VMID
```

Example output:
```
root@node:~# zfs list | grep 79990
PVE1/subvol-79990-disk-1                 769M  31.2G   769M  /PVE1/subvol-79990-disk-1
```

Get detailed information about a specific subvolume:
```
zfs list PVE1/subvol-79990-disk-1
```

## Understanding the Resize Process

### What Gets Resized

The script modifies the ZFS refquota for the container's disk subvolume. This is the maximum amount of disk space the container can use, not the physical allocated space.

### Size Constraints

- You cannot shrink a container's disk below the amount of data it currently contains
- The script will display an error if you attempt to set a size smaller than the current usage
- Always ensure sufficient free space exists on the ZFS pool for the operation

### Container Status

- Containers must be powered off before resizing to prevent data inconsistency
- After resizing completes, the container can be powered back on normally
- The resize operation does not affect the container's data or configuration

## Troubleshooting

### Error: "Cannot shrink below used disk space"

This means the target size is smaller than the amount of data currently stored on the container. Options to resolve this:

1. Increase the target size to be larger than the current usage
2. Free up disk space inside the container and try again with a smaller target size

### Error: "Size is missing. Specify the size with the -s flag"

You forgot to include the size parameter. Use the `-s` flag followed by the size value.

### Error: "Please specify the VMID of at least one container"

You did not provide any VMIDs. Ensure at least one VMID is specified after the size parameter.

### Checking Current Disk Usage

Before resizing, verify the current disk usage of your container:

```
zfs list | grep VMID
```

The second column in the output shows used space, and the third column shows available space.

## Technical Details

### Supported Size Units

- K: Kilobytes
- M: Megabytes
- G: Gigabytes

Examples:
- 64G = 64 gigabytes
- 512M = 512 megabytes
- 100K = 100 kilobytes

### Manual Resizing (Without the Script)

If you prefer to resize manually or need to debug an issue, the underlying command is:

```
zfs set refquota=SIZE PVE_NAME/subvol-VMID-disk-1
```

For example, to manually set a 16GB quota for VMID 79990:

```
zfs set refquota=16G PVE1/subvol-79990-disk-1
```

## Safety Recommendations

1. Always backup before resizing
2. Test on non-critical containers first
3. Keep the containers powered off during the resize
4. Verify the resize was successful by checking the container's filesystem after powering it back on
5. Allow some buffer space between current usage and the new size limit to prevent future issues

## Requirements

- POSIX-compliant shell (sh, bash, etc.)
- Proxmox with ZFS storage backend
- Standard Unix utilities: grep, awk, zfs
