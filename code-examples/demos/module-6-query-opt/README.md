# Module 6 — Query Optimization

**Goal:** see, with measurements, why ordering, projections, and skip-indexes
matter. Same 20M rows in three layouts.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-single.yml up -d
```

Single-node compose limits the container to 4G RAM; the demo fits comfortably
in that.

## Run

```bash
./run.sh
```

It takes ~30–60s for the inserts on a laptop. The query phase is a few
seconds.

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

## Cleanup

```bash
docker exec -i clickhouse-single clickhouse-client --query "DROP DATABASE m6"
```
