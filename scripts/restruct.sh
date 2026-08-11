#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"

log INFO "Reseting '$ORG_REMAPPED_DIR'..."
rsync -Praz --delete --exclude='.gitkeep' "$ORG_DIR/" "$ORG_REMAPPED_DIR/"

shopt -s globstar nullglob

log INFO "Restructuring org files according to '$CONFIG_PATH'..."

for oidx in $(yq ".remap[] | path | .[-1]" "$CONFIG_PATH"); do
    output="$REL_ORG_REMAPPED_DIR/$(yq ".remap[$oidx].output" "$CONFIG_PATH")"
    log DEBUG "Parsing sources for output '$output'..."

    mapfile -t excludes < <(yq ".remap[$oidx].excludes[]" "$CONFIG_PATH")
    if (("${#excludes[@]}")); then
        mapfile -t excludes < <(printf '%s\n' "${excludes[@]/#/$ORG_REMAPPED_DIR/}")
        exclude_files=( $excludes )
    fi

    for iidx in $(yq ".remap[$oidx].inputs[] | path | .[-1]" "$CONFIG_PATH"); do
        input=".remap[$oidx].inputs[$iidx]"

        source="$(yq "${input}.source" "$CONFIG_PATH")"
        outer_heading="$(yq "${input}.outer_heading" "$CONFIG_PATH")"
        todo="$(yq "${input}.todo" "$CONFIG_PATH")"
        path_as_headings="$(yq "${input}.path_as_headings // false" "$CONFIG_PATH")"
        prefix_to_priority="$(yq "${input}.prefix_to_priority // false" "$CONFIG_PATH")"
        prefix_to_order="$(yq "${input}.prefix_to_order // false" "$CONFIG_PATH")"
        filename_as_date="$(yq "${input}.filename_as_date // false" "$CONFIG_PATH")"

        path_as_headings_root="null"
        if [ "$path_as_headings" = "true" ]; then
            path_as_headings_root="${source%%[*?[]*}"
            path_as_headings_root="${path_as_headings_root%/*}"
        fi

        source="$ORG_REMAPPED_DIR/$source"
        files=( $source )
        mapfile -t files < <(comm -23 \
            <(printf '%s\n' "${files[@]}" | sort) \
            <(printf '%s\n' "${exclude_files[@]}" | sort))

        fmt="%s\t$ORG_REMAPPED_DIR\t$todo\t$outer_heading"
        fmt+="\t$path_as_headings\t$path_as_headings_root"
        fmt+="\t$prefix_to_priority\t$prefix_to_order"
        fmt+="\t$filename_as_date\n"

        printf "$fmt" "${files[@]}" |
            parallel --colsep='\t' --jobs=-2 \
                "$SCRIPT_DIR/restruct_file.sh \
                \"{1}\" \"{2}\" \"{3}\" \"{4}\" \
                \"{5}\" \"{6}\" \"{7}\" \"{8}\" \
                \"{9}\""
    done
done

opt_dot_ignore="$(yq '.options.dot_ignore // false' "$CONFIG_PATH")"

if [ "$opt_dot_ignore" = "true" ]; then
    ignore=(
        'assets/'
        'diagrams/'
        '*.png'
        '*.jpg'
        '*.jpeg'
        '*.webp'
        '*.svg'
        '*.wav'
        '*.mp3'
        '*.mp4'
        '*.avi'
        '*.mkv'
    )
    log INFO "Creating '.ignore' for ${ignore[*]}..."
    printf '%s\n' "${ignore[@]}" >"$ORG_REMAPPED_DIR/.ignore"
fi
