#!/bin/sh
set -eu

help_text() {
        printf "Usage: $0 -s SIZE CONTAINERS \n"
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
                        printf "Cannot shrink below used disk space.\n"
                        exit 1
                        ;;
                lxc_not_found_on_any_node)
                        printf "Could not find container %s on any remote nodes.\n" "$2"
                        exit 2
                        ;;
                lxc_not_found)
                        printf "Could not find container %s.\n" "$2"
                        exit 3
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
        remote_node=""
        
        while getopts "c:n:s:" opt; do
                case "$opt" in
                        c) container="$OPTARG" ;;
                        s) lxc_size="$OPTARG" ;;
                        n) remote_node="$OPTARG" ;;
                esac
        done

        shift $((OPTIND - 1))

        [ -z "$lxc_size" ] && error_message missing_size_lxc

        lxc_size=${lxc_size%B}

        # for remote nodes in a cluster
        if [ -n "$remote_node" ]; then
                 ROOTFS="$(
                         ssh "$remote_node" "pct config $container | awk -F': ' '/^rootfs:/ {print \$2}'"
        )"

                if [ -z "$ROOTFS" ]; then
                    error_message lxc_not_found "$container"
                fi

                VOLUME="${ROOTFS%%,*}"
                PVE_NAME="$(
                    ssh "$remote_node" "zfs list -H -o name -t filesystem | grep -m1 subvol-${container}-"
                )"

                if [ -z "$PVE_NAME" ]; then
                    return 3
                fi

                ZFS_USED="$(
                    ssh "$remote_node" "
                        zfs list '$PVE_NAME' 2>/dev/null | awk 'NR > 1 {print \$2}'
                    "
                )"

                USED_BYTES="$(to_bytes "$ZFS_USED")"
                SIZE_BYTES="$(to_bytes "$lxc_size")"

                if [ "$USED_BYTES" -lt "$SIZE_BYTES" ]; then
                    ssh "$remote_node" "zfs set refquota=$lxc_size quota=$lxc_size $PVE_NAME"
                    ssh "$remote_node" "pct set $container -rootfs '$VOLUME,size=$lxc_size'"
                else
                    error_message zfs_gt_lxc "$container"
                fi
        else
                ROOTFS="$(pct config "$container" | awk -F': ' '/^rootfs:/ {print $2}')"
                VOLUME="${ROOTFS%%,*}"
                PVE_NAME="$(zfs list -H -o name -t filesystem | grep -m1 "subvol-${container}-")"

                if [ -z "$PVE_NAME" ]; then
                    return 3
                fi

                ZFS_USED="$(zfs list "$PVE_NAME" 2>/dev/null | awk 'NR > 1 {print $2}')"

                USED_BYTES="$(to_bytes "$ZFS_USED")"
                SIZE_BYTES="$(to_bytes "$lxc_size")"

                if [ "$USED_BYTES" -lt "$SIZE_BYTES" ]; then
                    zfs set refquota="$lxc_size" quota="$lxc_size" "$PVE_NAME" >/dev/null 2>&1
                    ROOTFS="$(awk -F': ' '/^rootfs:/ {print $2}' /etc/pve/lxc/${container}.conf)"
                    NEW_ROOTFS="$(printf '%s\n' "$ROOTFS" | sed -E "s/size=[^,]+/size=${lxc_size}/")"
                    pct set "$container" -rootfs "$NEW_ROOTFS"
                else
                    error_message zfs_gt_lxc "$container"
                fi
        fi
}
