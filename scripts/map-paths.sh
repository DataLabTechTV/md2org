#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Mapping directory and file names to kebab-case..."
log DEBUG "Metadata DB: %s" "$META_PATH"

find "$MD_DIR" -type f ! -name ".*" -exec realpath --relative-to="$BASE_DIR" {} + |
    duckdb "$META_PATH" "
        CREATE TABLE paths AS
        SELECT * FROM read_csv_auto(
            '/dev/stdin',
            header=false,
            columns={'src': VARCHAR}
        )
    "

duckdb "$META_PATH" "
    UPDATE paths SET src = src.replace('$REL_MD_DIR/', '');

    ALTER TABLE paths ADD COLUMN ft VARCHAR;
    UPDATE paths SET ft = src.
        parse_filename().
        regexp_extract('.*\.(.*)', 1).
        lower();
    UPDATE paths SET ft = 'excalidraw'
    WHERE src ILIKE '%.excalidraw.md';

    ALTER TABLE paths ADD COLUMN dst VARCHAR;

    UPDATE paths SET dst = src.replace('$REL_MD_DIR/', '$REL_ORG_DIR/');

    UPDATE paths SET dst = dst.
        lower().
        strip_accents().
        replace('.', '-').
        regexp_replace('(.*)-(.*)$', '\1.' || (CASE WHEN ft = 'md' THEN 'org' ELSE ft END)).
        regexp_replace('[ \-–—]+', '-', 'g').
        regexp_replace(E'[\',]', '', 'g').
        replace('&', 'and');

    UPDATE paths
    SET dst = dst.replace('/attachments/', '/assets/')
    WHERE ft <> 'excalidraw';

    UPDATE paths
    SET dst = dst.
        replace('/attachments/', '/diagrams/').
        replace('-excalidraw.excalidraw', '.excalidraw')
    WHERE ft = 'excalidraw';
"

mapfile -t ignore_filetypes < <(yq '.ignore.filetypes[]' "$CONFIG_PATH")

if (("${#ignore_filetypes[@]}")); then
    log DEBUG "Ignore filetypes: %s" "${ignore_filetypes[*]}"
    ft="$(printf "'%s', " "${ignore_filetypes[@]}" | sed 's/, $//')"
    duckdb "$META_PATH" "DELETE FROM paths WHERE ft IN ($ft)"
fi
