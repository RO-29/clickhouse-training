# Module 6 — Query Optimization

**Goal:** see, with measurements, why ordering, projections, and skip-indexes
matter. Same 20M rows in three layouts.

## Run

```bash
./up.sh        # m6-clickhouse with 6G memory limit
./run.sh       # 60M inserts (~30–60s) + demo queries
./down.sh
```

## Container

`m6-clickhouse` on host ports 8123 (HTTP) and 9000 (Native).

## What you should observe

| Query                               | BAD ordering              | GOOD ordering             | PROJ + skip idx                    |
|-------------------------------------|---------------------------|---------------------------|------------------------------------|
| Q1 — time range                     | scans most parts          | reads few granules        | reads few granules                |
| Q2 — country aggregation per month  | scans all rows            | scans time range          | reads from projection (tiny)       |
| Q3 — point lookup by `user_id`      | scans all rows            | scans all rows            | bloom filter prunes most marks     |

The exact numbers vary by hardware; what's stable is the *ratio*. On my MBP:

```
Q2 BAD : ~1.8 s   read_rows ~20M
Q2 GOOD: ~0.25 s  read_rows ~5M
Q2 PROJ: ~0.02 s  read_rows ~3k
```

## Levers we used

1. **`ORDER BY (event_time, user_id)`** — events are inserted (and then read)
   chronologically; the PK shape matches the access pattern.
2. **`PARTITION BY toYYYYMM(event_time)`** — month-range filters skip whole
   partitions.
3. **Projection** `(country, day → count, sum, avg)` — a precomputed mini
   table managed by the engine. Triggered automatically when the query
   matches its shape (`optimize_use_projections = 1`, default).
4. **Bloom-filter skip index** on `user_id` — for high-cardinality point
   lookups when `user_id` isn't in the PK prefix.

## Things to call out

- **A skip index isn't a B-tree.** It only *eliminates* granules; if every
  granule's filter says "maybe", you scan everything anyway.
- **Projections cost storage** roughly equal to the projection's data. Not
  free — measure.
- **`EXPLAIN PROJECTION = 1`** tells you whether the planner picked the
  projection. If it didn't, your projection definition probably doesn't match
  the query.
- **`system.query_log`** is the source of truth — `tail -f` it during demos.

## Extras (curriculum coverage)

`extras.sql` adds the optimisation tools the core demo skipped:

- **PREWHERE** — explicit and auto-rewritten forms; `EXPLAIN SYNTAX`
  shows what the planner picks.
- **SAMPLE** — `SAMPLE BY intHash32(user_id)` table copy; `SAMPLE 0.1`
  gives an order-of-magnitude faster approximation.
- **More skip indexes** — `minmax`, `set`, `tokenbf_v1` on the same
  table; `EXPLAIN indexes = 1` shows which one fires.
- **JOIN strategies** — `ANY` vs `ALL` vs Dictionary lookup
  (`dictGetString`).
- **Materialized View** — `country_daily_mv` with a backfill, so
  per-country/per-day aggregations come from a tiny precomputed table.

## Cleanup

`./down.sh` drops the volume. To clear data without tearing down:

```bash
docker exec -i m6-clickhouse clickhouse-client --query "DROP DATABASE m6"
```
