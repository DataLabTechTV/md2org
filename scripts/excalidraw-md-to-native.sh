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

log DEBUG "$src"

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
        hash=$(echo "$line" | cut -d" " -f1)
        filename=$(echo "$line" | cut -d" " -f 2-)
        path=$(find "$MD_DIR" -path "*$filename*")
        mime=$(file --brief --mime-type "$path")
        base64=$(printf "data:%s;base64,%s\n" \
            "$mime" \
            "$(base64 -w0 "$path")")
        printf "{\"mimeType\":\"%s\",\"id\":\"%s\",\"dataURL\":\"%s\"}\n" \
            "$mime" \
            "$hash" \
            "$base64"
    done >"$embed_tmpfile"

jq --slurpfile entries <(jq -s '.' "$embed_tmpfile") '
    .files = (
        .files + (
            $entries[0] | map({(.id): .}) | add
        )
    )
' "$tmpfile" >"$dst"

rm -fv "$tmpfile"
rm -fv "$embed_tmpfile"
