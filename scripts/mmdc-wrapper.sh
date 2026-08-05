#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: ${0##*/} WORKDIR [MERMAID-CLI ARGS...]"
    exit 1
}

[ "$#" -ge 1 ] || usage

workdir="$(readlink -f "$1")"
shift

podman run --rm \
    --userns=keep-id:uid=1001,gid=1001 \
    --volume "${workdir}:/data:z" \
    --workdir /data \
    ghcr.io/mermaid-js/mermaid-cli/mermaid-cli:11.16.1 "$@"
