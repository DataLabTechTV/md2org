#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"
. "$SCRIPT_DIR/lib/fs.sh"

shopt -s globstar nullglob

log INFO "Merging org files according to 'config.yaml'..."

for oidx in $(yq ".remap[] | path | .[-1]" config.yaml); do
    output="$REL_ORG_REMAPPED_DIR/$(yq ".remap[$oidx].output" config.yaml)"
    title="$(yq ".remap[$oidx].title // \"Title\"" config.yaml)"

    log INFO "Merging sources into output '$output'..."

    srcs=()

    for iidx in $(yq ".remap[$oidx].inputs[] | path | .[-1]" config.yaml); do
        input=".remap[$oidx].inputs[$iidx]"
        source="$REL_ORG_REMAPPED_DIR/$(yq "${input}.source" config.yaml)"
        files=( $source )
        srcs+=( ${files[@]} )
    done

    if [ "${#srcs[@]}" -eq 0 ]; then
        log WARN "No sources for output '$output'"
        continue
    fi

    log DEBUG "[+] %s" "${srcs[@]}"

    outdir=$(dirname "$output")
    mkdir -p "$outdir"

    pandoc -f org-auto_identifiers -t org \
        --standalone \
        --wrap="preserve" \
        --metadata="title=$title" \
        --lua-filter="$FILTERS_DIR/merge.lua" \
        "${srcs[@]}" \
        -o "$output"

    log INFO "Removing sources and empty directories for output '$output'..."
    rm -v -- "${srcs[@]}"
    prune_empty_dirs "$ORG_REMAPPED_DIR"
done
