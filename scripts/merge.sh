#!/usr/bin/env bash

SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"
. "$SCRIPT_DIR/lib/fs.sh"

shopt -s globstar nullglob

log INFO "Applying user-specific org file merges..."

for oidx in $(yq ".remap[] | path | .[-1]" config.yaml); do
    output="data/org-remapped/$(yq ".remap[$oidx].output" config.yaml)"
    title="$(yq ".remap[$oidx].title // \"Title\"" config.yaml)"

    log INFO "Merging sources into output: $output"

    srcs=()

    for iidx in $(yq ".remap[$oidx].inputs[] | path | .[-1]" config.yaml); do
        input=".remap[$oidx].inputs[$iidx]"
        source="data/org-remapped/$(yq "${input}.source" config.yaml)"
        files=( $source )
        srcs+=( ${files[@]} )
    done

    if [ "${#srcs[@]}" -eq 0 ]; then
        log WARN "No sources for output: $output"
        continue
    fi

    log DEBUG "source: %s" "${srcs[@]}"

    outdir=$(dirname "$output")
    mkdir -p "$outdir"

    pandoc -f org-auto_identifiers -t org \
        --standalone \
        --wrap="preserve" \
        --metadata="title=$title" \
        --lua-filter="$FILTERS_DIR/merge.lua" \
        "${srcs[@]}" \
        -o "$output"

    log INFO "Removing sources and empty directories for output: $output"
    rm -v -- "${srcs[@]}"
    prune_empty_dirs "$ORG_REMAPPED_DIR"
done
