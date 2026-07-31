set shell := ["bash", "-cu"]

# List all recipes
default:
    @just -l -u

_debug msg *args:
    #!/usr/bin/env bash
    . scripts/lib/logging.sh
    log DEBUG {{ msg }} {{ args }}

_info msg *args:
    #!/usr/bin/env bash
    . scripts/lib/logging.sh
    log INFO {{ msg }} {{ args }}

_warn msg *args:
    #!/usr/bin/env bash
    . scripts/lib/logging.sh
    log WARN {{ msg }} {{ args }}

_error msg *args:
    #!/usr/bin/env bash
    . scripts/lib/logging.sh
    log ERROR {{ msg }} {{ args }}

_check bin:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -n "Checking {{ bin }}... "
    test -x "$(command -v {{ bin }})" || (echo "failed (no executable {{ bin }} was found)"; exit 1)
    echo ok

# Check if system dependencies are available
check:
    #!/usr/bin/env bash
    set -e
    just _check rsync
    just _check duckdb
    just _check pandoc
    just _check jq
    just _check yq
    just _check xmlstarlet
    just _check podman
    just _check base64
    just _check magick
    just _check go-lz-string || echo "Install with: go install github.com/daku10/go-lz-string/cmd/go-lz-string@v0.0.7"

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

# Convert from markdown to org files, including directory structure
convert: check
    ./scripts/map-paths.sh
    ./scripts/create-dirs.sh
    ./scripts/convert-to-org.sh
    ./scripts/convert-excalidraw.sh

    # TODO copy remaining files, excluding md and excalidraw
    # ./scripts/copy-assets.sh

    # TODO convert into kebab case paths according to meta.duckdb
    # ./scripts/fix-image-paths.sh

    # TODO convert into kebab case paths according to meta.duckdb
    # ./scripts/fix-link-paths.sh

    # ./scripts/restruct.sh
    # ./scripts/merge.sh

    # TODO convert links pointing to merged source files into links to the merged output section
    # ./scripts/fix-merged-link-paths.sh
