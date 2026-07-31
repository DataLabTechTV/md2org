#!/usr/bin/env bash

usage() {
    echo "Usage: ${0##*/} WORKDIR [EXCALIRENDER ARGS...]"
    exit 1
}

[ "$#" -ge 1 ] || usage

workdir="$(readlink -f "$1")"
shift

podman run --rm \
    --volume "${workdir}:/data:z" \
    --workdir /data \
    docker.io/jonarc06/excalirender "$@"
