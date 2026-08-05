#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"
. "$SCRIPT_DIR/lib/image.sh"

export SCRIPT_DIR ORG_DIR
export -f log

log INFO "Converting '*.mmd' diagrams to '*.png'..."

find "$ORG_DIR" -name '*.mmd' -path '*/diagrams/*' |
    parallel --jobs=-2 '
        read src < <(realpath --relative-to="$ORG_DIR" {1})
        dst="${src%.mmd}.png"
        dst="${dst/\/diagrams\//\/assets\/}"

        log DEBUG "Source: $src"
        "$SCRIPT_DIR/mmdc_wrapper.sh" "$ORG_DIR" -q -s 3 -i "$src" -o "$dst"
    '
