#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Remapping internal links in preparation for merge..."

find "$ORG_REMAPPED_DIR" -name '*.org' -print0 |
    parallel -0 pandoc -f org -t org \
        --metadata="org_remapped_dir:$ORG_REMAPPED_DIR" \
        --lua-filter="$FILTERS_DIR/extract_internal_links.lua" \
        "{}" -o /dev/null |
    duckdb "$META_PATH" "
        CREATE OR REPLACE TABLE links AS
        SELECT * FROM read_csv_auto(
            '/dev/stdin',
            header=false,
            delim='\t',
            columns={
                'current_dir': VARCHAR,
                'link': VARCHAR,
                'abs_path': VARCHAR
            }
        )
    "

# TODO load config.yaml and use remap sources to map links to the corresponding output

log DEBUG "Ingesting '$CONFIG_PATH' into '$META_PATH' as 'config'"

duckdb "$META_PATH" -c "
    INSTALL yaml FROM community;
    LOAD yaml;
    CREATE OR REPLACE TABLE config AS (
        SELECT output, title, unnest(inputs, recursive := true)
        FROM (SELECT unnest(remap, recursive := true) FROM 'config.yaml'));
"

# TODO produce a dictionary of links per file based on the meta.duckdb
# select output, "source", "source".replace('**', '(?:[^/]+/)*').replace('*', '[^/]*').replace('.', '\.') as source_regex from config

# TODO pass the dictionary as metadata to pandoc and rewrite the links
