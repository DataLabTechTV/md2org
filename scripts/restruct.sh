#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Reseting '$ORG_REMAPPED_DIR'..."
rsync -Praz --delete --exclude='.gitkeep' "$ORG_DIR/" "$ORG_REMAPPED_DIR/"

shopt -s globstar nullglob

log INFO "Applying user-specific remaps..."

for oidx in $(yq ".remap[] | path | .[-1]" config.yaml); do
    output="data/org-remapped/"$(yq ".remap[$oidx].output" config.yaml)
    log INFO "Parsing sources for output: $output"

    for iidx in $(yq ".remap[$oidx].inputs[] | path | .[-1]" config.yaml); do
        input=".remap[$oidx].inputs[$iidx]"

        source="$(yq "${input}.source" config.yaml)"
        outer_heading="$(yq "${input}.outer_heading" config.yaml)"
        todo="$(yq "${input}.todo" config.yaml)"
        path_as_headings="$(yq "${input}.path_as_headings // false" config.yaml)"

        path_as_headings_root="null"
        if [ "$path_as_headings" = "true" ]; then
            path_as_headings_root="${source%%[*?[]*}"
            path_as_headings_root="${path_as_headings_root%/*}"
        fi

        source="$ORG_REMAPPED_DIR/$source"
        files=( $source )

        printf "%s\t$ORG_REMAPPED_DIR\t$todo\t$outer_heading\t$path_as_headings\t$path_as_headings_root\n" \
            "${files[@]}" |
        parallel --colsep='\t' --jobs=-2 \
            "$SCRIPT_DIR/restruct-file.sh \"{1}\" \"{2}\" \"{3}\" \"{4}\" \"{5}\" \"{6}\""
    done
done
