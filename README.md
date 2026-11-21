# lds.data-ingestion

The London Data Service ingestion layer. Each dataset is described by one YAML manifest in
`datasets/`. The [lds.core.engine](https://github.com/BillWoodNHS/lds.core.engine) engine, included
here as the `engine/` submodule, generates everything needed to land and expose that dataset in
Snowflake. Nothing in `snowflake/` or `models/lds_ingest/` is written by hand.

## Layout

```
datasets/<dataset>.yml        hand-written manifests (see datasets/README.md)
lds_engine.yml                engine configuration: naming, database roles, PII taxonomy, dev filters
engine/                       lds.core.engine (submodule)
  environments/<env>.yml      the ONE place for account, storage, integration, warehouse and role names
snowflake/<dataset>/          GENERATED, committed: database, stage, file format, raw tables, pipes
models/lds_ingest/<dataset>/  GENERATED, committed: dbt sources, landed views and tests
macros/                       dbt project macros (schema naming)
profiles/profiles.yml         dbt targets: local (DuckDB) and dev/test/uat/prod (Snowflake)
scripts/local.sh              full local run on DuckDB
scripts/deploy.sh             deploy one environment
azure-pipelines/              CI (pull requests) and deployment (dev -> test -> uat -> prod)
build/                        NOT committed: deployable SQL per environment
```

## Setup

```bash
git clone --recurse-submodules https://github.com/BillWoodNHS/lds.data-ingestion.git
cd lds.data-ingestion
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt          # engine, dbt-core, dbt-duckdb, dbt-snowflake
pipx install "snowflake-cli>=3.34,<4"    # only needed to deploy; kept separate (dependency conflicts)
```

Or run `make setup`.

## Adding or changing a dataset

1. Write or edit `datasets/<dataset>.yml`. Copy from `engine/examples/datasets/`; there is one
   example per protocol.
2. Run `lds-engine validate`. It lists every problem with its location and rule, e.g.
   `emis.yml: tables[0].keys[1]: [R2] ...`.
3. Run `lds-engine generate` to write `snowflake/` and `models/lds_ingest/`.
4. Run `scripts/local.sh`, which builds the generated models and tests on DuckDB.
5. Commit the manifest and the generated files together. CI fails if they are out of step.

A change to any column's `role` needs a MAJOR bump of `manifest_version`; CI enforces this.

## Local testing (no Snowflake)

```bash
scripts/local.sh
```

This validates the manifests and checks the generated files are current. It then creates the raw
tables in `local.duckdb` and runs `dbt build --target local`. DuckDB has no per-dataset databases, so
`<database>.<schema>` becomes the schema `<database>__<schema>`, e.g. `lds_emis__raw`. Open
`local.duckdb` to insert sample rows into the raw tables and rerun `dbt build --profiles-dir profiles`.

## Observability

Every dataset gets generated monitoring, described in `engine/docs/observability.md`:
- `<dataset>__status`: health per table (`ok` / `attention` / `incomplete`);
- row accounting (`reconciliation`, `not_presented`);
- lineage columns on `latest` and `continuum`;
- `unclassified_columns`;
- source freshness;
- in Snowflake, load audit, unloaded files and pipe health.

Every run is logged to `lds_audit.run_log`, and the rows behind every test warning or failure are
kept in `lds_audit`.

## Environments and deployment

There is one Snowflake account per environment: `dev`, `test`, `uat` and `prod`.
- **Names:** account, storage account, integration, warehouse and account-role names are held only
  in `engine/environments/<env>.yml`. Committed files contain placeholders. `lds-engine build --env
  <env>` fills them in, and `lds-engine env --env <env>` prints them.
- **Changing a name:** edit the file in the engine, then update the submodule here
  (`git submodule update --remote engine`) and commit.
- **Dev subset:** `lds_engine.yml` → `environments.dev.path_filters` can restrict dev to a subset of
  files, e.g. one extract group or a range of extract timestamps.

To deploy by hand (normally the pipeline does this):

```bash
scripts/deploy.sh dev --dry-run    # show what would run
SNOWFLAKE_USER=... SNOWFLAKE_PRIVATE_KEY_PATH=... scripts/deploy.sh dev
```

`deploy.sh` does four things:
1. Validates and checks the generated files.
2. Builds `build/<env>/<dataset>.sql`.
3. Runs each file with the Snowflake CLI as the environment's `deployer` role.
4. Runs `dbt build` as the `transformer` role.

## Azure DevOps

| Pipeline | File | Runs |
|---|---|---|
| CI | `azure-pipelines/ci.yml` | on pull requests: validate, check, check-roles, build every environment, local DuckDB run. Needs no Snowflake access. |
| Deploy | `azure-pipelines/deploy.yml` | on `main`: dev → test → uat → prod, each gated by its Azure DevOps environment. |

One-off setup in Azure DevOps (names TBC):
- **GitHub service connection:** needs read access to both this repo and `lds.core.engine`, for the
  submodule checkout.
- **Environments:** `lds-dev`, `lds-test`, `lds-uat`, `lds-prod`, with approvals on test, uat and prod.
- **Variable groups:** `lds-snowflake-<env>`, holding `SNOWFLAKE_USER` and
  `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` (secret).
- **Secure files:** `lds-snowflake-<env>.p8`, the deploy user's private key (key-pair auth).

## Still to decide (TBC)

- Platform names in `engine/environments/*.yml`: accounts, storage accounts, integrations,
  warehouses and roles.
- Naming conventions in `lds_engine.yml` (the current values are placeholders).
- IG confirmation of the PII taxonomy.
- The dbt connection's default database (`LDS_DBT_DATABASE` in `profiles/profiles.yml`). Generated
  models set their own database, so this is only the connection's starting point.
- Azure DevOps service connection, variable group, secure file and environment names.
