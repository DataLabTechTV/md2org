set shell := ["bash", "-cu"]

# List all recipes
default:
    @just -l -u

_info msg *args:
    #!/bin/bash
    printf "$(tput setaf 4)▶ {{ msg }}$(tput sgr0)\n" {{ quote(args) }}

_check bin:
    #!/bin/bash
    set -euo pipefail
    echo -n "Checking {{ bin }}... "
    test -x "$(command -v {{ bin }})" || (echo "failed (no executable {{ bin }} was found)"; exit 1)
    echo ok

# Check if system dependencies are available
check:
    @just _check pandoc

# Delete output (data/to-org/)
clean:
    find data/to-org/ -mindepth 1 ! -name .gitkeep -exec rm -rfv {} +

# Delete input (data/from-md/) and output (data/to-org/)
dist-clean: clean
    find data/from-md/ -mindepth 1 ! -name .gitkeep -exec rm -rfv {} +

# Convert from markdown to org files, including directory structure
convert: check
    #!bin/bash

    # from data/md to data/org, kebab-case, .md => .org
    just _info "Mapping directory and path names..."

    # remapping note directories as specified in data/remaps.conf
    just _info "Applying user-specific remaps..."
