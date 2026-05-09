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

## Execution flow — what `./run.sh` actually does, in order

When you call `./run.sh`, the script walks through these steps. Each one
prints a `==>` banner so you can follow along on the terminal.

| #  | Step                                | What happens                                                                                                                                                  |
|----|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | **self-bootstrap**                  | If `m1-clickhouse` isn't already responding to `/ping`, the script calls `up.sh` first. `up.sh` tears down any other demo module that's holding port 8123, then `docker compose up -d` brings the CH container up. |
| 1  | `setup.sql`                         | Creates database `m1` and one MergeTree table `m1.events` with `PARTITION BY toYYYYMM(event_time)`, `ORDER BY (event_time, user_id)`, default `index_granularity = 8192`. |
| 2  | `data.sql` (~2M rows in 3 inserts)  | Three `INSERT … SELECT FROM numbers(...)` statements (500k + 500k + 1M rows). Three inserts on purpose: leaves three active parts so the next step has something to merge. |
| 3  | `queries.sql`                       | Eight observation queries: row count, `system.parts`, partitions/sizes, primary key vs sorting key from `system.tables`, `OPTIMIZE … FINAL`, post-merge part count, a date-range aggregation, and a `SYSTEM FLUSH LOGS` + `system.query_log` lookup to see how many rows the previous SELECT actually read. |
| 4  | `extras.sql`                        | Curriculum extras: a TTL-bearing table (`events_ttl`), a codec-comparison table (`codecs_demo` with `Delta`, `T64`, `ZSTD(3)` columns), a complex-types table with `Enum`, `Nullable`, `Array`, `Tuple`, `Map`, `Nested`, plus `DESCRIBE TABLE` / `SHOW CREATE TABLE`. |
| 5  | HTTP API smoke test                 | Inside the container, `wget -qO- 'http://localhost:8123/?query=SELECT count() FROM m1.events'` should return `2000000` — proves the HTTP interface works. |

The container stays up after `run.sh` exits. Tear down with `./down.sh`.

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
