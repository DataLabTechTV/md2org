#!/usr/bin/env bash

CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(readlink -f "$CONFIG_SCRIPT_DIR/../..")"

SCRIPTS_DIR="$BASE_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"
FILTERS_DIR="$BASE_DIR/filters"

DATA_DIR="$(readlink -f "$BASE_DIR/data")"
MD_DIR="$DATA_DIR/md"
ORG_DIR="$DATA_DIR/org"
ORG_REMAPPED_DIR="$DATA_DIR/org-remapped"
REL_MD_DIR="$(realpath --relative-to="$BASE_DIR" "$MD_DIR")"
REL_ORG_DIR="$(realpath --relative-to="$BASE_DIR" "$ORG_DIR")"
REL_ORG_REMAPPED_DIR="$(realpath --relative-to="$BASE_DIR" "$ORG_REMAPPED_DIR")"

META_PATH="$DATA_DIR/meta.duckdb"
