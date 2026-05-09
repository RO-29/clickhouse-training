# Module 2 — Table Engines

**Goal:** make the *behavioural* differences between MergeTree variants
concrete: Replacing, Summing, Aggregating, Collapsing, plus Log, Memory, Buffer.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-single.yml up -d
```

## Run

```bash
./run.sh
```

## What each section shows

| Engine                      | What you should observe                                                                  |
|-----------------------------|------------------------------------------------------------------------------------------|
| **ReplacingMergeTree**      | Naive `SELECT` returns dupes. `FINAL` and `argMax(...)` both return the deduped view.   |
| **SummingMergeTree**        | Row count drops sharply after `OPTIMIZE FINAL`; `sum()` totals stay identical.          |
| **AggregatingMergeTree**    | Stored as `*State`, queried via `*Merge` to finalize.                                    |
| **CollapsingMergeTree**     | Order 101 ends up as `paid` after collapse; old `pending` row is gone.                  |
| **Log**                     | Tiny ad-hoc table. No parts, no merges, no skip indexes.                                |
| **Memory**                  | Survives queries; gone on restart.                                                      |
| **Buffer**                  | Rows in `facts_buffer` until threshold; `facts_dest` is the durable target.             |

## When to pick which

- **MergeTree** — default. Insert wins; never updates in place.
- **ReplacingMergeTree** — slowly-changing dimensions. Don't rely on `FINAL`
  for hot paths; do `argMax` in the query.
- **SummingMergeTree** — pre-aggregated counters where adding rows is the
  semantics of merging.
- **AggregatingMergeTree** — non-trivial aggregates (uniq, quantile). Use with
  materialized views.
- **CollapsingMergeTree / VersionedCollapsingMergeTree** — current-state tables
  where rows get cancelled and replaced.
- **Log** — disposable tables. No durability guarantees.
- **Memory** — caches and tests.
- **Buffer** — only if you genuinely cannot batch inserts upstream. Risky:
  data is lost on crash.

## Cleanup

```bash
docker exec -i clickhouse-single clickhouse-client --query "DROP DATABASE m2"
```
