# lds.data-ingestion: notes for agents

- The engine is the `engine/` submodule (lds.core.engine); read `engine/README.md` and
  `engine/docs/spec.md` before changing manifests. Do not edit files under `engine/` here: change
  the engine repository and update the submodule.
- Never hand-edit `snowflake/` or `models/lds_ingest/`. Change `datasets/*.yml` or `lds_engine.yml`
  and run `lds-engine generate`; commit manifests and generated files together.
- Environment-specific names live only in `engine/environments/<env>.yml`.
- Before committing: `lds-engine validate && lds-engine check && scripts/local.sh`.
- Never run `scripts/deploy.sh` without `--dry-run` unless told which environment to deploy to.
- Do not invent supplier column names: manifest columns must match the supplier's file headers.
