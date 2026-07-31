#!/usr/bin/env bash

prune_empty_dirs() {
    if [ "$#" -lt 1 ]; then
        echo "prune-empty-dirs: missing root directory argument"
        return 2
    fi

    root_path=$1

    while find "$root_path" -mindepth 1 -type d -empty -print -quit | grep -q .; do
        find "$root_path" -mindepth 1 -depth -type d -empty -exec rmdir -v {} +
    done
}
