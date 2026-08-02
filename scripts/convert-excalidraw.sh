#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"


log INFO "Converting '*.excalidraw.md' to '*.excalidraw' and copying to 'diagrams/' directories..."
duckdb "$META_PATH" -c "
    COPY (
        SELECT
            '$REL_MD_DIR/' || src,
            '$REL_ORG_DIR/' || dst
        FROM paths
        WHERE ft = 'excalidraw'
    ) TO '/dev/stdout' (FORMAT CSV, DELIMITER '\t', QUOTE '', HEADER false)
" | parallel --colsep='\t' --jobs=-2 "$SCRIPT_DIR/excalidraw-md-to-native.sh"

log INFO "Converting '*.excalidraw' to '*.png'..."
"$SCRIPT_DIR/excalirender-wrapper.sh" "$ORG_DIR" --recursive --scale 3.0 .

log INFO "Creating 'assets/' directories for '*.png' diagrams..."
duckdb "$META_PATH" -csv -noheader -c "
    SELECT DISTINCT '$REL_ORG_DIR/' || dst.
        replace('/diagrams/', '/assets/').
        parse_dirpath()
    FROM paths
    WHERE ft = 'excalidraw';
" | xargs mkdir -v -p

log INFO "Moving '*.png' diagrams to the corresponding 'assets/' directories..."
find "$ORG_DIR" -name '*.excalidraw' -path '*/diagrams/*' -print0 |
    while IFS= read -r -d '' file; do
        src="${file%.excalidraw}.png"

        dst="${file%.excalidraw}.png"
        dst="${dst/\/diagrams\//\/assets\/}"

        mv -v "$src" "$dst"
    done
