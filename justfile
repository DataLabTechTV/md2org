set shell := ["bash", "-cu"]

# List all recipes
default:
    @just -l -u

_debug msg *args:
    @printf "$(tput setaf 8)D {{ msg }}$(tput sgr0)\n" {{ args }}

_info msg *args:
    @printf "$(tput setaf 4)I {{ msg }}$(tput sgr0)\n" {{ args }}

_warn msg *args:
    @printf "$(tput setaf 3)W {{ msg }}$(tput sgr0)\n" {{ args }}

_error msg *args:
    @printf "$(tput setaf 1)E {{ msg }}$(tput sgr0)\n" {{ args }}

_prune-empty-dirs root_path:
    #!/usr/bin/env bash
    while find {{ root_path }} -mindepth 1 -type d -empty -print -quit | grep -q .; do
        find {{ root_path }} -mindepth 1 -depth -type d -empty -exec rmdir -v {} +
    done

_check bin:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -n "Checking {{ bin }}... "
    test -x "$(command -v {{ bin }})" || (echo "failed (no executable {{ bin }} was found)"; exit 1)
    echo ok

# Check if system dependencies are available
check:
    #!/usr/bin/env bash
    just _check rsync
    just _check duckdb
    just _check pandoc
    just _check yq

# Delete output (data/to-org/)
clean:
    find data/org/ data/org-remapped/ -mindepth 1 ! -name .gitkeep -exec rm -rfv {} +
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

    find data/md/ -type f ! -name ".*" | duckdb data/meta.duckdb -c "
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
            WHERE ft = 'md' AND src NOT ILIKE '%.excalidraw.md'
            ORDER BY dst
        ) TO '/dev/stdout' (FORMAT CSV, DELIMITER '\t', QUOTE '', HEADER false)
    " | parallel --colsep='\t' --jobs=-2 '
        just _debug {1}
        pandoc -f markdown-auto_identifiers -t org \
            --standalone \
            --wrap=preserve \
            --metadata title={1} \
            {2} -o {3}
    '

_convert-excalidraw:
    # TODO convert .excalidraw.md to .excalidraw
    # TODO move .excalidraw to a diagrams/ dir
    # TODO render .excalidraw as .png into an assets/ dir

_fix-link-paths:
    # TODO convert into kebab case paths according to meta.duckdb

_fix-image-paths:
    # TODO convert into kebab case paths according to meta.duckdb
    # TODO make sure that excalidraw diagram links point to the png assets (might need to revise meta.duckdb)

_reset-org-remapped:
    rsync -Praz --delete --exclude='.gitkeep' data/org/ data/org-remapped/

_restruct-file path root todo outer_heading path_as_headings path_as_headings_root:
    #!/usr/bin/env bash
    set -euo pipefail
    just _info "Preparing for merge: {{ path }}"
    just _debug "todo: {{ todo }}"
    just _debug "outer_heading: {{ outer_heading }}"
    just _debug "path_as_headings: {{ path_as_headings }}"
    just _debug "path_as_headings_root: {{ path_as_headings_root }}"
    tmpfile=$(mktemp)
    pandoc -f org-auto_identifiers -t org \
        --standalone \
        --wrap=preserve \
        --metadata root="{{ root }}" \
        --metadata todo="{{ todo }}" \
        --metadata outer_heading="{{ outer_heading }}" \
        --metadata path_as_headings="{{ path_as_headings }}" \
        --metadata path_as_headings_root="{{ path_as_headings_root }}" \
        --lua-filter=prepare_merge.lua \
        "{{ path }}" -o "$tmpfile"
    mv "$tmpfile" "{{ path }}"

_restruct:
    #!/usr/bin/env bash
    shopt -s globstar nullglob
    just _info "Applying user-specific remaps..."
    just _reset-org-remapped

    for oidx in $(yq ".remap[] | path | .[-1]" config.yaml); do
        output="data/org-remapped/"$(yq ".remap[$oidx].output" config.yaml)
        just _info "Parsing sources for output: $output"

        for iidx in $(yq ".remap[$oidx].inputs[] | path | .[-1]" config.yaml); do
            input=".remap[$oidx].inputs[$iidx]"

            source=$(yq "${input}.source" config.yaml)
            outer_heading=$(yq "${input}.outer_heading" config.yaml)
            todo=$(yq "${input}.todo" config.yaml)
            path_as_headings=$(yq "${input}.path_as_headings // false" config.yaml)

            path_as_headings_root="null"
            if [ "$path_as_headings" = "true" ]; then
                path_as_headings_root="${source%%[*?[]*}"
                path_as_headings_root="${path_as_headings_root%/*}"
            fi

            source="data/org-remapped/${source}"
            files=($source)

            printf '%s\n' "${files[@]}" | parallel --jobs=-2 "
                just _restruct-file {1} \
                    "data/org-remapped/" \
                    "$todo" \
                    "$outer_heading" \
                    "$path_as_headings" \
                    "$path_as_headings_root"
            "
        done
    done

_merge:
    #!/usr/bin/env bash
    shopt -s globstar nullglob
    just _info "Applying user-specific org file merges..."

    for oidx in $(yq ".remap[] | path | .[-1]" config.yaml); do
        output="data/org-remapped/"$(yq ".remap[$oidx].output" config.yaml)
        title=$(yq ".remap[$oidx].title // \"Title\"" config.yaml)
        just _info "Merging sources into output: $output"

        srcs=()

        for iidx in $(yq ".remap[$oidx].inputs[] | path | .[-1]" config.yaml); do
            input=".remap[$oidx].inputs[$iidx]"
            source="data/org-remapped/"$(yq "${input}.source" config.yaml)
            files=($source)
            srcs+=("${files[@]}")
        done

        if [ "${#srcs[@]}" -eq 0 ]; then
            just _warn "No sources for output: $output"
            continue
        fi

        just _debug 'source: %s' "${srcs[@]}"

        outdir=$(dirname "$output")
        mkdir -p "$outdir"

        pandoc -f org-auto_identifiers -t org \
            --standalone \
            --wrap=preserve \
            --metadata title="$title" \
            --lua-filter=merge.lua \
            "${srcs[@]}" \
            -o "$output"

        just _info "Removing sources and empty directories for output: $output"
        rm -v -- "${srcs[@]}"
        just _prune-empty-dirs data/org-remapped/
    done

_fix-merged-link-paths:
    # TODO convert links pointing to merged source files into links to the merged output section

# Convert from markdown to org files, including directory structure
convert: check
    #!/usr/bin/env bash
    rm -rfv data/meta.duckdb
    just _map-paths
    just _create-dirs
    just _convert-to-org
    just _convert-excalidraw
    just _fix-image-paths
    just _fix-link-paths
    just _restruct
    just _merge
    just _fix-merged-link-paths

inspect-meta cols="*":
    duckdb data/meta.duckdb -c "SELECT {{ cols }} FROM paths"
