#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/logging.sh"
. "$SCRIPT_DIR/lib/fs.sh"

log INFO "Finding and moving assets according to '$CONFIG_PATH'..."

for tidx in $(yq ".assets[] | path | .[-1]" "$CONFIG_PATH"); do
    target_dir="$ORG_REMAPPED_DIR/$(yq .assets[$tidx].target "$CONFIG_PATH")"
    assets_dir="$(basename "$target_dir")"
    mapfile -t root_dirs < <(yq .assets[$tidx].roots[] "$CONFIG_PATH")
    mapfile -t root_dirs < <(printf '%s\n' "${root_dirs[@]/#/$ORG_REMAPPED_DIR/}")

    log INFO "Moving assets to target directory '$target_dir'..."
    log DEBUG "Searching for assets under root directories: ${#root_dirs[@]}"

    mkdir -pv "$target_dir"

    if (("${#root_dirs[@]}")); then
        mapfile -t assets_dirs < <(find "${root_dirs[@]}" -type d -name "$assets_dir")
        printf '%s\n' "${assets_dirs[@]}"
        # find "${assets_dirs[@]}" -type f -exec echo mv -v {} "$target_dir" \;
    fi
done

prune_empty_dirs "$ORG_REMAPPED_DIR"
