# Dataset manifests

One YAML manifest per dataset (`<dataset>.yml`). The schema and rules are in
`engine/docs/spec.md` section 8 and `engine/README.md`; worked examples for every protocol are in
`engine/examples/datasets/`.

After adding or changing a manifest:

```bash
lds-engine validate
lds-engine generate      # then commit datasets/, snowflake/ and models/lds_ingest/ together
```

Column names must match the supplier's file headers (case-insensitive), because pipes load with
`MATCH_BY_COLUMN_NAME`.
