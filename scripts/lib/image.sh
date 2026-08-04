#!/usr/bin/env bash

remove_transparency() {
    if [ "$#" -lt 1 ]; then
        echo "remove_transparency: insufficient arguments"
        return 1
    fi

    path="$1"
    log INFO "Removing transparent background from '$path'..."

    tmpfile=$(mktemp "/tmp/md2org-remove-transparency.XXXXXXXXXX.png")
    magick "$path" -background white -alpha remove -alpha off "$tmpfile"
    mv -v "$tmpfile" "$path"
}
