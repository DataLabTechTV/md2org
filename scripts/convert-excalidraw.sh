#!/usr/bin/env bash

SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Copying and converting Excalidraw diagrams to PNG..."

# Convert .excalidraw.md to .excalidraw, embedding images
duckdb "$META_PATH" -c "
    COPY (
        SELECT
            'data/md/' || src,
            'data/org/' || dst
        FROM paths
        WHERE ft = 'excalidraw'
    ) TO '/dev/stdout' (FORMAT CSV, DELIMITER '\t', QUOTE '', HEADER false)
" | parallel --colsep='\t' --jobs=-2 "$SCRIPT_DIR/excalidraw-md-to-native.sh"

# Create directories
duckdb "$META_PATH" -csv -noheader -c "
    SELECT DISTINCT 'data/org/' || dst.
        replace('/diagrams/', '/assets/').
        parse_dirpath()
    FROM paths
    WHERE ft = 'excalidraw';
" | xargs mkdir -v -p

"$SCRIPT_DIR/excalirender-wrapper.sh" ./data/org --recursive --scale 3.0 .
