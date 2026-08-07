#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Remapping internal links in preparation for merge..."

log DEBUG "Extracting links using pandoc"

find "$ORG_REMAPPED_DIR" -name '*.org' -print0 |
    parallel -0 pandoc -f org-auto_identifiers -t org \
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

log DEBUG "Ingesting '$REL_CONFIG_PATH' into '$REL_META_PATH' as table 'config'"

duckdb "$META_PATH" -c "
    INSTALL yaml FROM community;
    LOAD yaml;

    CREATE OR REPLACE TABLE config AS (
        SELECT output, title, unnest(inputs, recursive := true), excludes
        FROM (SELECT unnest(remap, recursive := true) FROM 'config.yaml'));
"

# TODO produce a dictionary of links per file based on the meta.duckdb

log DEBUG "Adding 'source_regex' column to the 'config' table"

duckdb "$META_PATH"  "
    ALTER TABLE config ADD COLUMN source_regex VARCHAR;
    ALTER TABLE config ADD COLUMN excludes_regex VARCHAR;

    UPDATE config
    SET source_regex = source.
            replace('**', '(?:[^/]+/)*').
            replace('*', '[^/]*').
            replace('.', '\.'),
        excludes_regex = array_to_string(excludes, '|').
            replace('**', '(?:[^/]+/)*').
            replace('*', '[^/]*').
            replace('.', '\.');
"

log DEBUG "Creating 'link_remaps' table"

duckdb "$META_PATH" "
    CREATE OR REPLACE TABLE link_remaps AS (
        WITH matches AS (
            SELECT
                *,
                regexp_matches(abs_path, source_regex)
                    AND (
                        excludes_regex IS NULL
                        OR NOT regexp_matches(abs_path, excludes_regex)
                     )
                    AS is_match
            FROM config, links
            WHERE is_match
        )
        SELECT link, output AS remap, abs_path
        FROM matches
    );
"

# TODO add original title for linked sources to the link_remaps table

# TODO pass the dictionary as metadata to pandoc and rewrite the links
