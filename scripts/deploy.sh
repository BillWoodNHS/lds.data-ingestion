#!/usr/bin/env bash
# Deploy to one Snowflake environment (one account per environment):
#   1. render the deployable SQL for the environment (build/<env>/<dataset>.sql)
#   2. run it with the Snowflake CLI as the environment's deployer role
#   3. run dbt as the environment's transformer role
# Account, roles and warehouse come from engine/environments/<env>.yml (via `lds-engine env`).
# Credentials come from the caller: SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH and optionally
# SNOWFLAKE_PRIVATE_KEY_PASSPHRASE.
#
# Usage: scripts/deploy.sh <dev|test|uat|prod> [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_NAME="${1:?usage: scripts/deploy.sh <env> [--dry-run]}"
DRY_RUN="${2:-}"
export DBT_SEND_ANONYMOUS_USAGE_STATS=false

lds-engine validate
lds-engine check
rm -rf "build/$ENV_NAME"
lds-engine build --env "$ENV_NAME"

# Export LDS_* platform values for this environment.
while IFS='=' read -r key value; do export "$key=$value"; done < <(lds-engine env --env "$ENV_NAME")

shopt -s nullglob
files=(build/"$ENV_NAME"/*.sql)
echo "Environment $ENV_NAME: account $LDS_SNOWFLAKE_ACCOUNT, ${#files[@]} dataset file(s)"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  for f in "${files[@]}"; do echo "  would run $f as $LDS_ROLE_DEPLOYER"; done
  echo "  would run: dbt build --target $ENV_NAME as $LDS_ROLE_TRANSFORMER"
  exit 0
fi

: "${SNOWFLAKE_USER:?SNOWFLAKE_USER is required}"
: "${SNOWFLAKE_PRIVATE_KEY_PATH:?SNOWFLAKE_PRIVATE_KEY_PATH is required}"

for f in "${files[@]}"; do
  echo "Running $f"
  # Templating is off: build output has no placeholders left, and PATTERN regexes must reach
  # Snowflake unchanged.
  snow sql --temporary-connection \
    --account "$LDS_SNOWFLAKE_ACCOUNT" \
    --user "$SNOWFLAKE_USER" \
    --authenticator SNOWFLAKE_JWT \
    --private-key-file "$SNOWFLAKE_PRIVATE_KEY_PATH" \
    --role "$LDS_ROLE_DEPLOYER" \
    --enable-templating NONE \
    --filename "$f"
done

dbt deps --profiles-dir profiles --quiet
dbt build --profiles-dir profiles --target "$ENV_NAME"
