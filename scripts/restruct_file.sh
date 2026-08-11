#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

usage() {
    echo "Usage: ${0##*/} PATH ROOT TODO OUTER_HEADING PATH_AS_HEADINGS PATH_AS_HEADINGS_ROOT FILENAME_AS_DATE"
    echo
    echo "Arguments:"
    echo "  PATH                    absolute path of the input org file"
    echo "  ROOT                    absolute path of the the root directory for processed org files"
    echo "  TODO                    optional org mode TODO keyword (ignored if 'null')"
    echo "  OUTER_HEADING           optional outer heading to be added (ignored if 'null')"
    echo "  PATH_AS_HEADINGS        set status for convert directories along the path to headers [true/false]"
    echo "  PATH_AS_HEADINGS_ROOT   absolute path of the root directory to build headers from (ignored if 'null')"
    echo "  PREFIX_TO_PRIORITY      filename prefixes (e.g., P0, P1) become org mode priorities (e.g., [#A], [#B])"
    echo "  PREFIX_TO_ORDER         filename prefixes (e.g., 01, 02) become an org mode property (e.g., :Order: 1, :Order: 2)"
    echo "  FILENAME_AS_DATE        expects filenames in the 'YYYY-mm-dd.org' format, to parse into dates with weekday under year sections"
    exit 2
}

[ "$#" -ge 8 ] || usage

path=$1
root=$2
todo=$3
outer_heading=$4
path_as_headings=$5
path_as_headings_root=$6
prefix_to_priority=$7
prefix_to_order=$8
filename_as_date=$9

log INFO "Retructuring '$path'..."

log DEBUG "root: $root"
log DEBUG "todo: $todo"
log DEBUG "outer_heading: $outer_heading"
log DEBUG "path_as_headings: $path_as_headings"
log DEBUG "path_as_headings_root: $path_as_headings_root"
log DEBUG "prefix_to_priority: $prefix_to_priority"
log DEBUG "prefix_to_order: $prefix_to_order"
log DEBUG "filename_as_date: $filename_as_date"

ignore_tmpfile=$(mktemp "/tmp/md2org-ignore.XXXXXXXXXX.yaml")
yq '{"ignore": .ignore}' "$CONFIG_PATH" >"$ignore_tmpfile"

tmpfile=$(mktemp "/tmp/md2org-restruct.org.XXXXXXXXXX")

pandoc -f org-auto_identifiers -t org \
    --standalone \
    --wrap="preserve" \
    --metadata="root:$root" \
    --metadata="todo:$todo" \
    --metadata="outer_heading:$outer_heading" \
    --metadata="path_as_headings:$path_as_headings" \
    --metadata="path_as_headings_root:$path_as_headings_root" \
    --metadata="prefix_to_priority:$prefix_to_priority" \
    --metadata="prefix_to_order:$prefix_to_order" \
    --metadata="filename_as_date:$filename_as_date" \
    --metadata-file="$ignore_tmpfile" \
    --lua-filter="$FILTERS_DIR/restruct.lua" \
    "$path" -o "$tmpfile"

mv "$tmpfile" "$path"

rm -fv "$ignore_tmpfile"
