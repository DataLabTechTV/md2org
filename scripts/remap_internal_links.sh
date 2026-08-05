#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

# find "$ORG_REMAPPED_DIR" -type f ! -name ".*" -exec realpath --relative-to="$ORG_REMAPPED_DIR" {} +

pandoc -f org -t org \
    --lua-filter="$FILTERS_DIR/extract-internal-links.lua" \
    "$(find "$ORG_REMAPPED_DIR" -name '*.org')" \
    -o /dev/null
