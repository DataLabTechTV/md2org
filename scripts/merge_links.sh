#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

usage() {
    echo "Usage: ${0##*/} OUTPUT"
    echo
    echo "Arguments:"
    echo "  OUTPUT      output path for metadata YAML dictionary"
    exit 2
}

[ "$#" -ge 1 ] || usage

output=$1

log INFO "Rewriting internal links to point to merged org files..."
log DEBUG "Output: $output"

log DEBUG "Extracting all existing links, ignoring anchors, using pandoc..."

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
        );

        UPDATE links
        SET abs_path = abs_path.
            regexp_replace('(.*)::.*', '\1');
    "

log DEBUG "Ingesting '$REL_CONFIG_PATH' into '$REL_META_PATH' as table 'config'..."

duckdb "$META_PATH" -c "
    INSTALL yaml FROM community;
    LOAD yaml;

    CREATE OR REPLACE TABLE config AS (
        SELECT output, title, unnest(inputs, recursive := true), excludes
        FROM (SELECT unnest(remap, recursive := true) FROM 'config.yaml'));
"

log DEBUG "Adding 'source_regex' and 'excludes_regex' columns to the 'config' table..."

glob_regex='[^/]+'
globstar_regex='(?:[^/]+/)*'

duckdb "$META_PATH"  "
    ALTER TABLE config ADD COLUMN source_regex VARCHAR;
    ALTER TABLE config ADD COLUMN excludes_regex VARCHAR;

    UPDATE config
    SET source_regex = source.
            replace('**/', '__GLOBSTAR__').
            replace('*', '$glob_regex').
            replace('__GLOBSTAR__', '$globstar_regex').
            replace('.', '\.'),
        excludes_regex = array_to_string(excludes, '|').
            replace('**/', '__GLOBSTAR__').
            replace('*', '$glob_regex').
            replace('__GLOBSTAR__', '$globstar_regex').
            replace('.', '\.');
"

log DEBUG "Creating 'merged_links' dictionary table..."

duckdb "$META_PATH" "
    CREATE OR REPLACE TABLE merged_links AS (
        WITH matches AS (
            SELECT DISTINCT
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
        SELECT
            link AS unmerged_link,
            output AS merged_link,
            abs_path AS unmerged_path
        FROM matches
    );
"

log DEBUG "Extracting 'custom_id' from merged link targets..."

custom_ids_tmpfile=$(mktemp "/tmp/md2org-custom_ids.XXXXXXXXXX")

duckdb "$META_PATH" -csv -noheader "SELECT DISTINCT unmerged_path FROM merged_links" |
    parallel pandoc -f org-auto_identifiers -t org \
        --metadata="org_remapped_dir:$ORG_REMAPPED_DIR" \
        --lua-filter="$FILTERS_DIR/extract_custom_id.lua" \
        "$ORG_REMAPPED_DIR/{}" -o /dev/null \
        >"$custom_ids_tmpfile"

log DEBUG "Creating 'custom_id' column..."
duckdb "$META_PATH" "ALTER TABLE merged_links ADD COLUMN custom_id VARCHAR"

log DEBUG "Updating 'custom_id' column in 'merged_links' table..."

duckdb "$META_PATH" "
    UPDATE merged_links
    SET custom_id = t.custom_id
    FROM (
        SELECT * FROM read_csv_auto(
            '$custom_ids_tmpfile',
            header=false,
            delim='\t',
            columns={
                'rel_path': VARCHAR,
                'custom_id': VARCHAR
            }
        )
    ) t
    WHERE unmerged_path = t.rel_path;
"

rm -fv "$custom_ids_tmpfile"

log DEBUG "Writing JSON merged links dictionary to '$output'..."

duckdb "$META_PATH" -c "
    COPY (
        SELECT
            json_group_object(
                unmerged_link,
                json_object(
                    'merged_link', merged_link,
                    'custom_id', custom_id
                )
            ) AS merged_links
        FROM merged_links
    ) TO '$output' (FORMAT json);
"
