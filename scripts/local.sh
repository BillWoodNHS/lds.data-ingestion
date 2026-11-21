#!/usr/bin/env bash
# Local end-to-end check, no Snowflake needed: validate manifests, confirm generated files are up to
# date, create the raw tables in a local DuckDB file and run every generated dbt model and test.
# Usage: scripts/local.sh            (LDS_DUCKDB_PATH overrides the database file)
set -euo pipefail
cd "$(dirname "$0")/.."

export LDS_DUCKDB_PATH="${LDS_DUCKDB_PATH:-local.duckdb}"
export DBT_SEND_ANONYMOUS_USAGE_STATS=false

lds-engine validate
lds-engine check
rm -f "$LDS_DUCKDB_PATH" "$LDS_DUCKDB_PATH.wal"
lds-engine local-ddl --apply "$LDS_DUCKDB_PATH"
dbt deps --profiles-dir profiles --quiet
dbt build --profiles-dir profiles --target local
