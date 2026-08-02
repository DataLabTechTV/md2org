#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Copying assets from '$MD_DIR' to '$ORG_DIR'..."

export -f log
duckdb "$META_PATH" -c "
    COPY (
        SELECT
            '$REL_MD_DIR/' || src,
            '$REL_ORG_DIR/' || dst
        FROM paths
        WHERE ft NOT IN ('md', 'excalidraw')
        ORDER BY dst
    ) TO '/dev/stdout' (FORMAT CSV, DELIMITER '\t', QUOTE '', HEADER false)
" | parallel --colsep='\t' --jobs=-2 "
    cp -v {1} {2}
"
