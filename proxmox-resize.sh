#!/bin/sh

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/functions.sh"
. "$SCRIPT_DIR/proxmox-resize.config"

while getopts "s:" opt; do
        case "$opt" in
                s) size="$OPTARG" ;;
        esac
done

shift $((OPTIND - 1))

[ "$#" -eq 0 ] && error_message no_containers

[ -z "$size" ] && error_message missing_size

for arg in "$@"; do
        if [ -n "$REMOTE_NODES" ]; then
                found=0
                if resize_lxc -s "$size" -c "$arg"; then
                        :
                else
                        for node in $REMOTE_NODES; do
                                if resize_lxc -s "$size" -c "$arg" -n "$node"; then
                                    found=1
                                    break
                                fi
                        done

                        if [ "$found" -ne 1 ]; then
                                error_message lxc_not_found_on_any_node "$arg"
                        fi
                fi
        else
                resize_lxc -s "$size" -c "$arg"
                rc=$?

                if [ "$rc" -ne 0 ]; then
                    if [ "$rc" -eq 3 ]; then
                        error_message lxc_not_found "$arg"
                    fi

                    exit 3
                fi
        fi
done
