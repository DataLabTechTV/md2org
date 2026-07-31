#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Converting all markdown files into org files..."

export -f log
duckdb "$META_PATH" -c "
    COPY (
        SELECT
            src.parse_filename().regexp_replace('\.md', '') AS title,
            'data/md/' || src,
            'data/org/' || dst
        FROM paths
        WHERE ft = 'md'
        ORDER BY dst
    ) TO '/dev/stdout' (FORMAT CSV, DELIMITER '\t', QUOTE '', HEADER false)
" | parallel --colsep='\t' --jobs=-2 '
    log DEBUG {1}
    pandoc -f markdown-auto_identifiers -t org \
        --standalone \
        --wrap="preserve" \
        --metadata="title:"{1} \
        {2} -o {3}
'
