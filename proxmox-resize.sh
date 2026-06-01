#!/bin/sh
set -eu

command -v pct >/dev/null || {
    printf 'pct not found\n'
    exit 1
}

command -v zfs >/dev/null || {
    printf 'zfs not found\n'
    exit 1
}

readonly SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/functions.sh"
. "$SCRIPT_DIR/proxmox-resize.conf"

size=""

while getopts "s:" opt; do
        case "$opt" in
                s) size="$OPTARG" ;;
        esac
done

shift $((OPTIND - 1))

[ "$#" -eq 0 ] && error_message no_containers

[ -z "$size" ] && error_message missing_size

readonly MAX_JOBS=4
running=0
pids=""

for arg in "$@"; do
(
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
    ) &
        pid=$!
        pids="$pids $pid"
        running=$((running + 1))
    if [ "$running" -ge "$MAX_JOBS" ]; then
        set -- $pids

        oldest=$1

        wait "$oldest"
        rc=$?

        shift
        pids="$*"

        running=$((running - 1))

        [ "$rc" -ne 0 ] && exit "$rc"
    fi
done
for pid in $pids; do
    wait "$pid" || exit $?
done
