#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

usage() {
    echo "Usage: ${0##*/} PATH ROOT TODO OUTER_HEADING PATH_AS_HEADINGS PATH_AS_HEADINGS_ROOT"
    echo
    echo "Arguments:"
    echo "  PATH                    absolute path of the input org file"
    echo "  ROOT                    absolute path of the the root directory for processed org files"
    echo "  TODO                    optional org mode TODO keyword (ignored if 'null')"
    echo "  OUTER_HEADING           optional outer heading to be added (ignored if 'null')"
    echo "  PATH_AS_HEADINGS        set status for convert directories along the path to headers [true/false]"
    echo "  PATH_AS_HEADINGS_ROOT   absolute path of the root directory to build headers from (ignored if 'null')"
    exit 2
}

[ "$#" -ge 6 ] || usage

path=$1
root=$2
todo=$3
outer_heading=$4
path_as_headings=$5
path_as_headings_root=$6

log INFO "Preparing for merge: $path"

log DEBUG "todo: $todo"
log DEBUG "outer_heading: $outer_heading"
log DEBUG "path_as_headings: $path_as_headings"
log DEBUG "path_as_headings_root: $path_as_headings_root"

tmpfile=$(mktemp)

pandoc -f org-auto_identifiers -t org \
    --standalone \
    --wrap="preserve" \
    --metadata="root:$root" \
    --metadata="todo:$todo" \
    --metadata="outer_heading:$outer_heading" \
    --metadata="path_as_headings:$path_as_headings" \
    --metadata="path_as_headings_root:$path_as_headings_root" \
    --lua-filter="$FILTERS_DIR/prepare_merge.lua" \
    "$path" -o "$tmpfile"

mv "$tmpfile" "$path"
