#!/bin/sh
help_text() {
        printf "$0 -s SIZE CONTAINERS \n"
        printf "SIZE corresponds to any integer/decimal with the disk size units at the end such as 64G.\n"
        printf "CONTAINERS refers to the VMIDs of each container and can be specified multiple times with each VMID seperated by a space.\n\n"
}

error_message() {
        case "$1" in
                missing_size_lxc)
                        help_text
                        printf "Size is missing in function\n\n"
                        exit 1
                        ;;
                missing_size)
                        help_text
                        printf "Size is missing. Specify the size with the -s flag.\n\n"
                        exit 1
                        ;;
                no_containers)
                        help_text
                        printf "Please specify the VMID of atleast one container.\n\n"
                        exit 1
                        ;;
                zfs_gt_lxc)
                        printf "Cannot shrink below used disk space.\n\n"
                        exit 1
                        ;;
                *)
                        help_text
                        exit 1
                        ;;
        esac
}

to_bytes() {
    printf '%s\n' "$1" | awk '
    /K$/ { sub(/K$/,""); printf "%.0f\n", $0 * 1024; next }
    /M$/ { sub(/M$/,""); printf "%.0f\n", $0 * 1024 * 1024; next }
    /G$/ { sub(/G$/,""); printf "%.0f\n", $0 * 1024 * 1024 * 1024; next }
    { print $0 }
    '
}

resize_lxc() {
        while getopts "c:s:" opt; do
                case "$opt" in
                        c) container="$OPTARG" ;;
                        s) lxc_size="$OPTARG" ;;
                esac
        done

        shift $((OPTIND - 1))

        [ -z "$lxc_size" ] && error_message missing_size_lxc
        
        PVE_NAME=$(zfs list | grep "$arg" | awk '{print $1}')
        ZFS_USED="$(zfs list $PVE_NAME | awk 'NR > 1 {print $2}')"
        [ "$(to_bytes $ZFS_USED)" -lt "$(to_bytes $lxc_size)" ] && zfs set refquota="$lxc_size" "$PVE_NAME" || error_message zfs_gt_lxc
}
