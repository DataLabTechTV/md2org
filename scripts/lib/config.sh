#!/usr/bin/env bash

CONFIG_SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
BASE_DIR="$(readlink -f "$CONFIG_SCRIPT_DIR/../..")"

SCRIPTS_DIR="$BASE_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"
FILTERS_DIR="$BASE_DIR/filters"

DATA_DIR=$(readlink -f "$BASE_DIR/data")
MD_DIR="$DATA_DIR/md"
ORG_DIR="$DATA_DIR/org"
ORG_REMAPPED_DIR="$DATA_DIR/org-remapped"

META_PATH="$DATA_DIR/meta.duckdb"
