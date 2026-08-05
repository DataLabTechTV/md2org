#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Checking for input markdown files under '$MD_DIR'..."

mapfile -t files < <(find "$MD_DIR" -type f -name '*.md')

if [ "${#files[@]}" -ge 1 ]; then
    log DEBUG "Markdown files found under '$MD_DIR': ${#files[@]}"
else
    log ERROR "No markdown files found under '$MD_DIR'"
    exit 2
fi
