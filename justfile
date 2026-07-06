set shell := ["bash", "-cu"]

# List all recipes
default:
    @just -l -u

_print msg:
    @printf "$(tput setaf 8)  %s$(tput sgr0)\n" {{ quote(msg) }}

_info msg:
    @printf "$(tput setaf 4)▶ %s$(tput sgr0)\n" {{ quote(msg) }}

_error msg:
    @printf "$(tput setaf 1)▶ %s$(tput sgr0)\n" {{ quote(msg) }}

_check bin:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -n "Checking {{ bin }}... "
    test -x "$(command -v {{ bin }})" || (echo "failed (no executable {{ bin }} was found)"; exit 1)
    echo ok

# Check if system dependencies are available
check:
    @just _check rsync
    @just _check duckdb
    @just _check pandoc

# Delete output (data/to-org/)
clean:
    find data/org/ -mindepth 1 ! -name .gitkeep -exec rm -rfv {} +
    rm -fv data/meta.duckdb

# Delete input (data/from-md/) and output (data/to-org/)
dist-clean: clean
    find data/md/ -mindepth 1 ! -name .gitkeep -exec rm -rfv {} +

# Compare existing markdown notes with its source to make sure they're in sync
diff-md src:
    rsync -Praz --delete --exclude=".*" --dry-run "{{ src }}/" data/md/

# Resync markdown notes with its source
sync-md src:
    rsync -Praz --delete --exclude=".*" "{{ src }}/" data/md/

_map-paths:
    #!/usr/bin/env bash
    just _info "Mapping directory and file names to kebab-case..."

    find data/md/ -type f ! -name ".*" ! -name '*.excalidraw.md' | duckdb data/meta.duckdb -c "
        CREATE TABLE paths AS
        SELECT * FROM read_csv_auto(
            '/dev/stdin',
            header=false,
            columns={'src': VARCHAR}
        )
    "

    duckdb data/meta.duckdb -c "
        UPDATE paths SET src = src.replace('data/md/', '');

        ALTER TABLE paths ADD COLUMN ft VARCHAR;
        UPDATE paths SET ft = src.
            parse_filename().
            regexp_extract('.*\.(.*)', 1).
            lower();

        ALTER TABLE paths ADD COLUMN dst VARCHAR;

        UPDATE paths SET dst = src.replace('data/md/', 'data/org/');

        UPDATE paths SET dst = dst.
            lower().
            strip_accents().
            replace('.', '-').
            regexp_replace('(.*)-(.*)$', '\1.org').
            regexp_replace('[ \-–—]+', '-', 'g').
            regexp_replace(E'[\',]', '', 'g').
            replace('&', 'and');

        UPDATE paths SET dst = dst.regexp_replace('attachments', 'assets');
    "

_create-dirs:
    #!/usr/bin/env bash
    just _info "Creating directory structure for org files..."
    duckdb data/meta.duckdb -csv -noheader -c "
        SELECT DISTINCT 'data/org/' || dst.parse_dirpath()
        FROM paths
        WHERE ft = 'md'
        ORDER BY dst
    " | xargs mkdir -v -p

_convert-to-org:
    #!/usr/bin/env bash
    just _info "Converting all markdown files into org files..."
    duckdb data/meta.duckdb -c "
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
        just _print {1}
        merge="yes"
        todo="TODO"
        pandoc -f markdown-implicit_header_references -t org \
            --standalone \
            --wrap=preserve \
            --metadata title={1} \
            --metadata merge="$merge" \
            --metadata todo="$todo" \
            --lua-filter=filter.lua \
            {2} -o - |
            sed "/:PROPERTIES:/,/^:END:/d" >"{3}"
    '

_remap-and-merge:
    @just _info "Applying user-specific directory remaps and note merges..."

# Convert from markdown to org files, including directory structure
convert: check
    #!/usr/bin/env bash

    if [ -f data/meta.duckdb ]; then
        just _error "file exists: data/meta.duckdb"
        exit 1
    fi

    just _map-paths
    just _create-dirs
    just _convert-to-org
    just _remap-and-merge

preview-meta cols="*":
    duckdb data/meta.duckdb -c "SELECT {{ cols }} FROM paths"
