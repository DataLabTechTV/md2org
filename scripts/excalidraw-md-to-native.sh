#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: ${0##*/} SRC DST"
    echo
    echo "Arguments:"
    echo "  SRC     Source .excalidraw.md file"
    echo "  DST     Target .excalidraw file"
    exit 2
}

[ "$#" -eq 2 ] || usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

src=$1
dst=$2

log DEBUG "src: $src"
log DEBUG "dst: $dst"

tmpfile="$(mktemp "/tmp/md2org.excalidraw.XXXXXXXXXX")"
log DEBUG "tmpfile: $tmpfile"
awk 'BEGIN { json=0 } /^```/ { json=!json; next } json' "$src" |
    tr -d "\n" |
    go-lz-string decompress -m base64 \
    >"$tmpfile"

embed_tmpfile="$(mktemp "/tmp/md2org-excalidraw-files.jsonl.XXXXXXXXXX")"
log DEBUG "embed_tmpfile: $embed_tmpfile"
awk '
    BEGIN { files=0 }
    /^## Embedded Files/ { files=1; next }
    /^%%/ { files=0 }
    files
' "$src" |
    tr -s "\n" |
    sed -e "s/://" -e "s/[][]//g" |
    while IFS= read -r line; do
        hash="$(echo "$line" | cut -d" " -f1)"
        filename="$(echo "$line" | cut -d" " -f 2-)"
        path="$(find "$MD_DIR" -path "*$filename*")"
        mime="$(file --brief --mime-type "$path")"

        case $mime in
            image/svg*)
                viewbox=$(xmlstarlet sel -t -v '/*[local-name()="svg"]/@viewBox' "$path")
                read -r _ _ width height <<<"$viewbox"
                scale=$((600/"$width"))
                width=$(("$scale" * "$width"))
                height=$(("$scale" * "$height"))
                base64="$(xmlstarlet ed \
                    -i '/*[local-name()="svg" and not(@width)]' -t attr -n width -v "$width" \
                    -i '/*[local-name()="svg" and not(@height)]' -t attr -n height -v "$height" \
                    "$path" | base64 -w0)"
                ;;
            image/webp)
                base64="$(magick "$path" "png:-" | base64 -w0)"
                ;;
            *)
                base64="$(base64 -w0 "$path")"
                ;;
        esac

        dataURL=$(printf "data:%s;base64,%s\n" \
            "$mime" \
            "$base64")

        printf "{\"mimeType\":\"%s\",\"id\":\"%s\",\"dataURL\":\"%s\"}\n" \
            "$mime" \
            "$hash" \
            "$dataURL"
    done >"$embed_tmpfile"

jq --slurpfile entries <(jq -s '.' "$embed_tmpfile") '
    .files = (
        .files + (
            $entries[] | map({(.id): .}) | add
        )
    )
' "$tmpfile" >"$dst"

rm -fv "$tmpfile"
rm -fv "$embed_tmpfile"
