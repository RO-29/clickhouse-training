# Module 1 — Fundamentals (standalone)

Self-contained single-node ClickHouse demo. Nothing outside this directory
is required.

## What you get

```
docker-compose.yml          # m1-clickhouse container, port 8123/9000
configs/clickhouse-config.xml
setup.sql · data.sql · queries.sql
up.sh · run.sh · down.sh
```

## Run

```bash
./up.sh        # docker compose up -d, waits for /ping
./run.sh       # creates DB, inserts ~2M rows, runs demo queries
./down.sh      # docker compose down -v  (drops volumes)
```

`./run.sh` self-bootstraps — if the container isn't up, it calls `up.sh`.

## What this proves

| Step                         | What you should see                                                                |
|------------------------------|------------------------------------------------------------------------------------|
| 3 sequential `INSERT`s       | 3 active parts in `system.parts` initially.                                       |
| Partition by `toYYYYMM`      | Parts grouped under `202601`, `202602`, `202603`.                                 |
| `OPTIMIZE TABLE … FINAL`     | Active part count drops; bytes per part rise.                                     |
| `system.tables`              | `primary_key` and `sorting_key` are both `event_time, user_id`.                   |
| `system.query_log`           | Date-range query reads << 2M rows because the PK is `event_time` first.          |

## Talking points

1. **Partition by month, not day** — partitions are physical directories.
2. **Sorting key vs primary key** — `ORDER BY` defines on-disk sort; the
   primary key is sparse (one entry per `index_granularity` rows).
3. **`index_granularity = 8192`** is why CH primary keys are tiny.
4. **`OPTIMIZE FINAL`** forces a merge for the demo. Don't run it routinely.

## Extras (curriculum coverage)

`extras.sql` runs after the main demo and exercises the curriculum topics
the core demo glossed over:

- **TTL** — `m1.events_ttl` with `TTL event_time + INTERVAL 7 DAY DELETE`.
- **Codecs** — `Delta`, `T64`, `ZSTD(3)` vs default LZ4 on the same shape
  of data; `system.columns` shows the resulting compression ratios.
- **Complex types** — `Enum8`, `Nullable`, `Array`, `Tuple`, `Map`, `Nested`
  in one table, queried with the appropriate accessors (`mapKeys`,
  `length`, dot-notation for `Nested`).
- **Schema introspection** — `DESCRIBE TABLE` and `SHOW CREATE TABLE`.
- **HTTP API** — `wget -qO- 'http://localhost:8123/?query=...'` from inside
  the container (the default user is loopback-only, so call from in-pod).

## Ports

| Service        | Container port | Host port |
|----------------|----------------|-----------|
| HTTP           | 8123           | 8123      |
| Native (TCP)   | 9000           | 9000      |
