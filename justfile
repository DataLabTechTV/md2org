set shell := ["bash", "-cu"]

# List all recipes
default:
    @just -l -u

_print msg *args:
    #!/bin/bash
    printf "$(tput setaf 8)  {{ msg }}$(tput sgr0)\n" {{ quote(args) }}

_info msg *args:
    #!/bin/bash
    printf "$(tput setaf 4)▶ {{ msg }}$(tput sgr0)\n" {{ quote(args) }}

_error msg *args:
    #!/bin/bash
    printf "$(tput setaf 1)▶ {{ msg }}$(tput sgr0)\n" {{ quote(args) }}

_check bin:
    #!/bin/bash
    set -euo pipefail
    echo -n "Checking {{ bin }}... "
    test -x "$(command -v {{ bin }})" || (echo "failed (no executable {{ bin }} was found)"; exit 1)
    echo ok

# Check if system dependencies are available
check:
    @just _check rsync
    @just _check duckdb
    @just _check mlr
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
    #!/bin/bash
    just _info "Mapping directory and path names..."

    find data/md/ -type f ! -name ".*" | duckdb data/meta.duckdb -c "
        CREATE TABLE mapping AS
        SELECT * FROM read_csv_auto(
            '/dev/stdin',
            header=false,
            columns={'src': VARCHAR}
        )
    "

    duckdb data/meta.duckdb -c "
        UPDATE mapping SET src = replace(src, 'data/md/', '');

        ALTER TABLE mapping ADD COLUMN ft VARCHAR;
        UPDATE mapping SET ft = lower(regexp_extract(parse_filename(src), '.*\.(.*)', 1));

        ALTER TABLE mapping ADD COLUMN dst VARCHAR;

        UPDATE mapping SET dst = src.replace('data/md/', 'data/org/');

        UPDATE mapping SET dst = dst.
            lower().
            strip_accents().
            replace('.', '-').
            regexp_replace('(.*)-(.*)$', '\1.org').
            regexp_replace('[ \-–—]+', '-', 'g').
            regexp_replace(E'[\',]', '', 'g').
            replace('&', 'and')
        WHERE ft = 'md';

        UPDATE mapping SET dst = dst.
            parse_dirpath().
            lower().
            strip_accents().
            replace('.', '-').
            regexp_replace('(.*)-(.*)$', '\1.org').
            regexp_replace('[ \-–—]+', '-', 'g').
            regexp_replace(E'[\',]', '', 'g').
            replace('&', 'and') ||
            '/' ||
            dst.parse_filename().strip_accents()
        WHERE ft <> 'md';
    "

_create-dirs:
    #!/bin/bash
    just _info "Creating directory structure for org files..."
    duckdb data/meta.duckdb -csv -noheader -c "
        SELECT DISTINCT 'data/org/' || dst.parse_dirpath()
        FROM mapping
        WHERE ft = 'md'
        ORDER BY dst
    " | xargs mkdir -v -p

_convert-to-org:
    #!/bin/bash
    just _info "Converting all markdown files into org files..."
    duckdb data/meta.duckdb -csv -noheader -c "
        SELECT
            src.parse_filename().regexp_replace('\.md', '') AS title,
            'data/md/' || src,
            'data/org/' || dst
        FROM mapping
        WHERE ft = 'md'
        ORDER BY dst
    " |
    mlr --icsv --otsv cat |
    while IFS=$'\t' read -r title src dst; do
        just _print "$title"
        pandoc -f markdown-implicit_header_references -t org \
            --standalone \
            --wrap=preserve \
            --metadata title="$title" \
            "$src" -o - |
            sed '/:PROPERTIES:/,/^:END:/d' >"$dst"
    done

_remap-and-merge:
    @just _info "Applying user-specific directory remaps and note merges..."

# Convert from markdown to org files, including directory structure
convert: check
    #!/bin/bash

    if [ -f data/meta.duckdb ]; then
        just _error "file exists: data/meta.duckdb"
        exit 1
    fi

    just _map-paths
    just _create-dirs
    just _convert-to-org
    just _remap-and-merge

preview-meta cols="*":
    duckdb data/meta.duckdb -c "SELECT {{ cols }} FROM mapping"
