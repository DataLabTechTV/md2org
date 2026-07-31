#!/usr/bin/env bash

usage() {
    echo "Usage: ${0##*/} SRC DST"
    echo
    echo "Arguments:"
    echo "  SRC     Source .excalidraw.md file"
    echo "  DST     Target .excalidraw file"
    exit 2
}

[ "$#" -eq 2 ] || usage

SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR/lib/logging.sh"

src=$1
dst=$2

log DEBUG "$src"

tmpfile="$(mktemp)"
awk "BEGIN { json=0 } /^\`\`\`/ { json=!json; next } json" "$src" |
    tr -d "\n" |
    go-lz-string decompress -m base64 \
    >"$tmpfile"

embed_tmpfile="$(mktemp)"
awk "
    BEGIN { files=0 }
    /^## Embedded Files/ { files=1; next }
    /^%%/ { files=0 }
    files
" "$src" |
    tr -s "\n" |
    sed -e "s/://" -e "s/[][]//g" |
    while IFS= read -r line; do
        hash=$(echo $line | cut -d" " -f1)
        filename=$(echo $line | cut -d" " -f 2-)
        path=$(find data/md/ -path "*$filename*")
        mime=$(file --brief --mime-type "$path")
        base64=$(printf "data:%s;base64,%s\n" \
            "$mime" \
            "$(base64 -w0 "$path")")
        printf "{\"key\":\"%s\",\"value\":{\"mimeType\":\"%s\",\"id\":\"%s\",\"dataURL\":\"%s\"}}\n" \
            "$hash" \
            "$mime" \
            "$hash" \
            "$base64"
    done >"$embed_tmpfile"

# # FIXME this doesnt work yet
# jq -s --slurpfile entries <(jq -s "." "$embed_tmpfile") '
#     .files = (
#         .files + (
#             $entries[0] | map({(.key): .value}) | add
#         )
#     )
# ' "$tmpfile"

mv "$tmpfile" "$dst"
