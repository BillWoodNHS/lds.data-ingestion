# Dataset manifests

One YAML manifest per dataset (`<dataset>.yml`). Every setting, its default and the validation
rules are in `engine/docs/manifest-reference.md`. To choose a protocol and see how it behaves, with
worked examples, start at `engine/docs/protocols/README.md`. Complete example manifests are in
`engine/examples/datasets/`.

After adding or changing a manifest:

```bash
lds-engine validate
lds-engine generate      # then commit datasets/, snowflake/ and models/lds_ingest/ together
```

Column names must match the supplier's file headers (case-insensitive), because pipes load with
`MATCH_BY_COLUMN_NAME`.
