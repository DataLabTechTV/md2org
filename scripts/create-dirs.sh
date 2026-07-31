#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Creating directory structure for org files..."

duckdb "$META_PATH" -csv -noheader -c "
    SELECT DISTINCT '$REL_ORG_DIR/' || dst.parse_dirpath()
    FROM paths
    ORDER BY dst
" | xargs mkdir -v -p
