#!/bin/sh

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/functions.sh"

while getopts "s:" opt; do
        case "$opt" in
                s) size="$OPTARG" ;;
        esac
done

shift $((OPTIND - 1))

[ "$#" -eq 0 ] && error_message no_containers

[ -z "$size" ] && error_message missing_size

for arg in "$@"; do
        resize_lxc -s $size -c $arg
done
