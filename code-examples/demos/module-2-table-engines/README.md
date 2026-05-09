# Module 2 — Table Engines

**Goal:** make the *behavioural* differences between MergeTree variants
concrete: Replacing, Summing, Aggregating, Collapsing, plus Log, Memory, Buffer.

## Run

```bash
./up.sh        # bring stack up
./run.sh       # demo
./down.sh      # tear down
```

`./run.sh` self-bootstraps if the stack isn't already up.

## Container

`m2-clickhouse` on host ports 8123 (HTTP) and 9000 (Native).

## Execution flow — what `./run.sh` actually does, in order

| #  | Step          | What happens                                                                                                                                                                                           |
|----|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap | If `m2-clickhouse` isn't responding to `/ping`, run `up.sh` (which tears down any other demo module first to avoid port conflicts).                                                                  |
| 1  | `setup.sql`   | Creates database `m2` and seven tables, one per engine: `users_replacing` (Replacing), `metrics_summing` (Summing), `events_agg` (Aggregating with `uniq`/`sum`/`quantileTDigest` states), `orders_collapsing` (Collapsing), `audit_log` (Log), `tmp_uploads` (Memory), `facts_dest` + `facts_buffer` (MergeTree + Buffer in front). |
| 2  | `data.sql`    | Loads each engine with shape-appropriate data: dupes for Replacing, partial counters for Summing, 200k aggregate STATES for Aggregating, +1/-1 sign rows for Collapsing, a few rows for Log/Memory/Buffer. |
| 3  | `queries.sql` | Walks through each engine's reading pattern: dedup via `argMax`, `OPTIMIZE FINAL` reductions, `*Merge` finalizers for Aggregating, the +1/-1 collapse for Collapsing, and a Buffer flush via `OPTIMIZE TABLE m2.facts_buffer` to push rows down to `facts_dest`. |
| 4  | `extras.sql`  | Three more engines/patterns: **VersionedCollapsingMergeTree** (out-of-order +/-1 resolved by version), a complete **Materialized View pipeline** (`events_src` → `events_per_minute_mv` → `events_per_minute` SummingMergeTree, with 200k synthetic events), and the **Nested type** (`invoices.line_items.{sku, qty, price}`) queried both with dot-notation and `ARRAY JOIN`. |

Container stays up after `./run.sh`. Tear down with `./down.sh`.

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

## Extras (curriculum coverage)

`extras.sql` exercises three more curriculum topics:

- **VersionedCollapsingMergeTree** — out-of-order +1/-1 rows resolved by
  the `version` column, not insertion order.
- **Materialized View** — `events_src` → `events_per_minute_mv` → 
  `events_per_minute` (SummingMergeTree). The MV runs at INSERT time, not
  query time.
- **Nested** — `invoices.line_items.{sku,qty,price}` stored as parallel
  arrays, queried both with dot-notation and `ARRAY JOIN`.

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

`./down.sh` drops the container and the volume. To clear data without
tearing down the stack:

```bash
docker exec -i m2-clickhouse clickhouse-client --query "DROP DATABASE m2"
```
