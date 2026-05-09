# Module 1 — ClickHouse Fundamentals

> **Audience:** engineers who'll deploy, query, or operate ClickHouse in
> production. **Prerequisites:** any prior SQL experience, a working Docker
> install. **Time:** ~45 min reading + 30 min hands-on.

This module establishes the mental model for *everything* that follows. By
the end you will be able to:

- Explain why ClickHouse is fast (and where it isn't).
- Read on-disk part naming and tell active parts from inactive ones.
- Pick a sensible `ORDER BY` / `PARTITION BY` / `PRIMARY KEY`.
- Choose appropriate codecs for time-series and integer columns.
- Use TTL to drop or move aging data automatically.
- Use `system.*` tables to see exactly what the engine is doing.

---

## 1. The 30-second pitch

ClickHouse is a **column-oriented OLAP DBMS** designed for one job: scan
huge tables fast, returning aggregations in milliseconds. Three properties
make it work:

| Property                  | What it buys you                                                                                |
|---------------------------|-------------------------------------------------------------------------------------------------|
| **Columnar storage**      | Each column is its own file → analytical queries read only the columns they touch.              |
| **Vectorised execution**  | Operators process arrays of values, not rows-one-at-a-time → SIMD-friendly, cache-friendly.     |
| **Sparse primary index**  | One mark per ~8192 rows → indexes stay tiny even on trillion-row tables.                         |
| **Aggressive compression** | Per-column codecs (LZ4, ZSTD, Delta, T64) typically reach 10–100× compression on real data.    |

It is *not* a transactional database. There is no row-level UPDATE/DELETE
in the traditional sense, no foreign keys, no MVCC. It excels at append-mostly
analytical workloads.

---

## 2. Storage architecture

```
┌────────────────────────────────────────────────────────────────┐
│                         ClickHouse Server                      │
└────────────────────────────────────────────────────────────────┘
        │                    │                       │
        ▼                    ▼                       ▼
┌──────────────┐    ┌────────────────┐    ┌─────────────────────┐
│  HTTP :8123  │    │   TCP :9000    │    │  Inter-server :9009 │
│  (REST/JSON) │    │ (native binary)│    │  (replica fetches)  │
└──────────────┘    └────────────────┘    └─────────────────────┘
        │                    │                       │
        └────────────────────┴───────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │ Query Pipeline │  parser → analyzer → planner →
                    │                │  pipeline → vectorised execution
                    └────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  Storage Layer │
                    │   (MergeTree)  │
                    └────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
   /var/lib/clickhouse/  /var/lib/clickhouse/  /var/lib/clickhouse/
   data/<db>/<table>/    metadata/<db>/        store/<...uuid>/
   ├─ <part_name>/       ├─ <table>.sql        (atomic-engine table data)
   │  ├─ columns.txt     └─ <table>.sql.bak
   │  ├─ checksums.txt
   │  ├─ count.txt
   │  ├─ default_compression_codec.txt
   │  ├─ minmax_<col>.idx (per partition column)
   │  ├─ partition.dat
   │  ├─ primary.idx     ← sparse PK (one entry per granule)
   │  ├─ <col>.bin       ← column data, compressed
   │  └─ <col>.mrk2      ← marks: offsets into <col>.bin
   ├─ <part_name>/
   └─ ...
```

### Files inside one part — what each is for

| File                              | Purpose                                                                |
|-----------------------------------|------------------------------------------------------------------------|
| `<column>.bin`                    | The column's compressed data, in granule order.                        |
| `<column>.mrk2` (or `.mrk`)       | Marks: byte offset into `.bin` for each granule (so reads can seek).   |
| `primary.idx`                     | Sparse primary key — one row per granule.                              |
| `count.txt`                       | Cached row count of this part.                                         |
| `columns.txt`                     | Column-name → type mapping for this part.                              |
| `checksums.txt`                   | SHA1 of every other file. Reads against this to detect corruption.     |
| `default_compression_codec.txt`   | Codec used for any column that didn't specify one.                     |
| `minmax_<col>.idx`                | Min/max of partition columns — partition-pruning input.                |
| `partition.dat`                   | Serialized partition value (e.g. `202601`).                            |

---

## 3. The MergeTree engine

`MergeTree` is *the* default table engine. Everything that does
replication, deduplication, TTL, or sharding is a variant of it.

### Required + optional clauses

```sql
CREATE TABLE events (
    event_time  DateTime,
    user_id     UInt32,
    revenue     Float64
)
ENGINE = MergeTree
ORDER BY (event_time, user_id)        -- 1. defines on-disk sort + default PK
PARTITION BY toYYYYMM(event_time)     -- 2. optional. keeps related rows together
PRIMARY KEY (event_time)              -- 3. optional. must be PREFIX of ORDER BY
SAMPLE BY intHash32(user_id)          -- 4. optional. enables SAMPLE clause
TTL event_time + INTERVAL 90 DAY      -- 5. optional. auto-delete or move
SETTINGS
    index_granularity = 8192,         -- rows per mark (default)
    min_rows_for_wide_part = 10000000;
```

### How `ORDER BY` interacts with `PRIMARY KEY`

- `ORDER BY` is required and defines **on-disk sort order**.
- `PRIMARY KEY` is the **sparse index**. If omitted (the common case), it
  equals `ORDER BY`. If specified, **it must be a prefix of ORDER BY**.
- Common pattern: `PRIMARY KEY (a, b)` + `ORDER BY (a, b, c, d)` — the
  index is small (only `a, b` go into `primary.idx`) but rows are
  fully sorted, so `c, d` filters still get sequential reads.

### `index_granularity = 8192`

- One **mark** is written per 8192 rows in the part.
- The **primary key** has one entry per mark, **not per row**. That's why
  PK on a 100-billion-row table fits in a few hundred MB instead of TB.
- Tradeoff: highly selective point lookups can't be more selective than a
  granule. For point lookups, add a skip-index or a secondary table.

```
                     ┌───── granule 0 (8192 rows) ─────┐
                     │                                  │
events.event_time:   2026-01-01 00:00:00 ...  2026-01-01 09:23:11
events.user_id:      4321 ............................. 9087
                     ▲
                     │  one entry in primary.idx points here:
                     │     (2026-01-01 00:00:00, 4321)
                     │
                     ┌───── granule 1 (8192 rows) ─────┐
                     │                                  │
                     2026-01-01 09:23:11 ...  2026-01-01 18:42:55
```

A `WHERE event_time BETWEEN '2026-01-01 06:00' AND '2026-01-01 12:00'`
query reads `primary.idx`, finds **only the granules that could contain
matching rows**, and reads just those `<col>.bin` byte ranges. A 2-billion-row
scan becomes a 100K-row scan.

---

## 4. Parts, partitions, merges

A **part** is an immutable directory under
`/var/lib/clickhouse/data/<db>/<table>/`. Every `INSERT` produces a new
part. Background workers later **merge** small parts into bigger ones,
sorted by the table's `ORDER BY`. This is the engine's name.

```
INSERT 1 ──► all_1_1_0/   (rows 1..500k)
INSERT 2 ──► all_2_2_0/   (rows 500k..1M)
INSERT 3 ──► all_3_3_0/   (rows 1M..2M)

   background merge ─────────────► all_1_3_1/   (rows 1..2M, sorted)

   later, the originals are removed:
                                 │
                                 ▼
                        active parts:  all_1_3_1/
                        inactive parts: all_1_1_0/, all_2_2_0/, all_3_3_0/  (deleted soon)
```

### Decoding a part name

```
        all_  1_3_1
        ─┬─   ─┬───
         │     │  └── merge level (0 = freshly inserted, 1 = 1st merge, …)
         │     │
         │     └── min_block..max_block of source parts
         │
         └── partition (here, all rows in one partition called 'all')
```

If the table has `PARTITION BY toYYYYMM(...)`, parts look like
`202601_5_5_0` instead — partition `202601`, blocks 5..5, level 0.

### Why merges matter

- Without merges: one tiny part per insert → millions of small files →
  the file system and the engine both choke.
- With merges: a logarithmic number of parts; reads stream sequentially;
  query planning visits few directories.
- **Don't insert one row at a time** — batch! 1k–100k rows per insert is
  the sweet spot. Single-row inserts are the #1 cause of "ClickHouse is
  slow" tickets.

### Partitions ≠ shards

A **partition** is a *logical group of parts within one node* (one
directory tree per partition value). A **shard** is a *whole node* in a
cluster. Use partitioning to drop old data cheaply (`DROP PARTITION`) and
to bound merge work; use sharding to spread data across machines.

Rule of thumb: **partition by month** for most workloads. Day-partitioning
is for very high-throughput tables (>1B rows/day). Year-partitioning is
for cold archival. Anything more granular than the access pattern is
counterproductive — too many partitions = slow merges + metadata bloat.

---

## 5. Compression and codecs

Every column is compressed independently. Codecs can be **stacked**.

```sql
CREATE TABLE metrics (
    ts        DateTime CODEC(Delta(4), LZ4),    -- delta-of-delta, then LZ4
    cpu       UInt32   CODEC(T64, LZ4),         -- bit-pack, then LZ4
    rps       UInt64   CODEC(T64, ZSTD(3)),     -- bit-pack, then ZSTD level 3
    label     String   CODEC(ZSTD(6))           -- ZSTD level 6 for text
)
ENGINE = MergeTree ORDER BY ts;
```

| Codec                   | Best for                                                              |
|-------------------------|-----------------------------------------------------------------------|
| `LZ4` (default)         | Anything; very fast, ~2× compression on text, more on integers.       |
| `ZSTD(level)`           | Larger compression than LZ4 (~30–50% smaller), slower. Levels 1–22.   |
| `Delta(N)`              | Monotonic series (timestamps, counters). Stores differences.          |
| `DoubleDelta`           | Timestamps with regular intervals (e.g. metrics every 1s).            |
| `Gorilla`               | Float time-series (Facebook's Gorilla algorithm).                     |
| `T64`                   | Integer columns where most values fit in fewer bits than the type.    |
| `LowCardinality(T)`     | Not a codec — a *type* wrapper for high-repetition strings.           |

The demo's `extras.sql` shows the actual ratios on identical data:
`Delta + LZ4` reaches **0.5 % of raw** on a monotonic timestamp column
(199× compression).

---

## 6. TTL — automatic data lifecycle

Three flavours, all expressed on a date/time column:

```sql
-- Whole-row TTL: delete rows after 90 days
ENGINE = MergeTree
ORDER BY (...)
TTL event_time + INTERVAL 90 DAY DELETE;

-- Column-level TTL: drop the column, keep the row
ENGINE = MergeTree ORDER BY (...)
( ...
    payload String TTL event_time + INTERVAL 30 DAY,
    ...);

-- Move-to-cold-disk TTL (with a multi-disk storage policy):
TTL event_time + INTERVAL 30 DAY TO VOLUME 'cold',
    event_time + INTERVAL 1 YEAR DELETE;
```

TTL runs **at merge time** in the background. It's not instant; for the
demo we use `merge_with_ttl_timeout = 60` so the next `OPTIMIZE` actually
purges old rows.

---

## 7. The `system.*` tables you'll live in

These are CH's introspection surface. Memorise the shape of each.

| Table                       | Use when…                                                            |
|-----------------------------|----------------------------------------------------------------------|
| `system.tables`             | "What's the schema, ORDER BY, partition key?"                       |
| `system.parts`              | "How many parts? Active vs inactive? Sizes? Compressed/uncompressed?" |
| `system.parts_columns`      | Per-column sizes within each part.                                   |
| `system.columns`            | Schema-level column info: type, codec, default expression.           |
| `system.merges`             | Currently-running merges. Empty when idle.                           |
| `system.mutations`          | `ALTER UPDATE/DELETE` jobs. They run async.                          |
| `system.query_log`          | One row per finished query: duration, rows read, memory.             |
| `system.query_thread_log`   | Per-thread breakdown of each query.                                  |
| `system.events`             | Lifetime counters: `InsertedRows`, `MergedRows`, etc.                |
| `system.metrics`            | Current values: connections, queued queries.                         |
| `system.asynchronous_metrics` | Sampled gauges: cache size, FS free.                                |
| `system.processes`          | Currently-running queries (the SHOW PROCESSLIST equivalent).         |
| `system.settings`           | Every server/session setting and its current value.                  |
| `system.disks` / `system.storage_policies` | Multi-disk configuration.                              |

`SYSTEM FLUSH LOGS;` forces the buffered logs to disk so the next SELECT
finds them.

---

## 8. The hands-on demo

### What you get

```
docker-compose.yml          m1-clickhouse · ports 8123/9000
configs/clickhouse-config.xml
setup.sql · data.sql · queries.sql · extras.sql
up.sh · run.sh · down.sh
```

### Run

```bash
./up.sh        # docker compose up -d, waits for /ping
./run.sh       # creates DB, inserts ~2M rows, runs demo queries
./down.sh      # docker compose down -v  (drops volumes)
```

`./run.sh` self-bootstraps — if the container isn't up, it calls `up.sh`.

### Execution flow — what runs, in order

| #  | Step                                | What happens                                                                                                                                                  |
|----|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap                      | If `m1-clickhouse` isn't responding to `/ping`, the script calls `up.sh` first. `up.sh` tears down any other demo module that's holding port 8123, then `docker compose up -d`. |
| 1  | `setup.sql`                         | Creates database `m1` and one MergeTree table `m1.events` partitioned by month, ordered by `(event_time, user_id)`, default `index_granularity = 8192`.       |
| 2  | `data.sql` (~2M rows in 3 inserts)  | Three `INSERT … SELECT FROM numbers(...)` (500k + 500k + 1M). Three on purpose: leaves three active parts so merges have something to do.                    |
| 3  | `queries.sql`                       | Eight observation queries: row count, `system.parts`, partitions/sizes, PK vs sorting key, `OPTIMIZE FINAL`, post-merge part count, date-range aggregation, and `SYSTEM FLUSH LOGS` + `system.query_log` to see how many rows the previous SELECT actually read. |
| 4  | `extras.sql`                        | Curriculum extras: TTL table, codec-comparison table (`Delta`, `T64`, `ZSTD(3)` vs LZ4), complex-types table (`Enum`, `Nullable`, `Array`, `Tuple`, `Map`, `Nested`), `DESCRIBE TABLE`, `SHOW CREATE TABLE`. |
| 5  | HTTP API smoke test                 | `wget -qO- 'http://localhost:8123/?query=SELECT count() FROM m1.events'` from inside the container — should return `2000000`.                                |

### What to look for

| Step                      | What you should see                                                          |
|---------------------------|------------------------------------------------------------------------------|
| 3 sequential INSERTs      | 3 active parts in `system.parts` initially.                                  |
| Partition by `toYYYYMM`   | Parts grouped under `202601`, `202602`, `202603`.                            |
| `OPTIMIZE TABLE … FINAL`  | Active part count drops; bytes per part rise.                                |
| `system.tables`           | `primary_key` and `sorting_key` both `event_time, user_id`.                  |
| Codec comparison          | `Delta(4)+LZ4` ≈ 0.5 % of raw on monotonic timestamps; `T64+LZ4` ≈ 3 % of raw on monotonic UInt64. |
| Date-range query          | `read_rows` in `query_log` is *much* less than 2M — proof that PK pruning works. |

---

## 9. Configuration reference (the demo's config)

`configs/clickhouse-config.xml` is bind-mounted into the container under
`/etc/clickhouse-server/config.d/00-custom.xml`. CH layers `config.d/`
files on top of the base `config.xml`.

```xml
<clickhouse>
    <logger>
        <level>notice</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size><count>10</count>
    </logger>

    <!-- Persistent system logs: one row per query/part/merge. Without
         these, system.query_log and friends are empty after restart. -->
    <query_log><database>system</database><table>query_log</table></query_log>
    <query_thread_log><database>system</database><table>query_thread_log</table></query_thread_log>
    <part_log><database>system</database><table>part_log</table></part_log>

    <listen_host>0.0.0.0</listen_host>     <!-- accept TCP from anywhere -->
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <interserver_http_port>9009</interserver_http_port>

    <max_connections>4096</max_connections>
    <background_pool_size>16</background_pool_size>          <!-- merge workers -->
    <background_schedule_pool_size>16</background_schedule_pool_size>

    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
</clickhouse>
```

> **Important on CH 26.x**: user-level settings (`max_memory_usage`,
> `max_rows_to_read`, etc.) cannot live at the top level of `config.xml`
> any more — they belong in `users.d/<file>.xml` under
> `<profiles><default>...</default></profiles>`. Putting them at the top
> level used to work; on 26.4+ the server refuses to start.

---

## 10. Common pitfalls

| Symptom                                                      | Cause                                                                | Fix                                                                                       |
|--------------------------------------------------------------|----------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Inserts get progressively slower; CPU spent in merges        | Many small inserts → too many parts.                                 | Batch inserts (1k–100k rows). Use Buffer engine *only* if you can't.                      |
| `Too many parts (N). Merges are processing significantly slower than inserts` | Same as above, but now hard-failing.                | Slow down inserts; raise `parts_to_throw_insert` only as a temporary lifeline.            |
| Tiny query reads millions of rows                            | PK doesn't cover the filter; or filter isn't on a PK-prefix column.  | Re-shape `ORDER BY`, or add a skip-index/projection (Module 6).                           |
| `Memory limit exceeded`                                      | Aggregation needs more than `max_memory_usage` (default 10 GB).      | Raise the limit, or use `max_bytes_before_external_group_by` to spill to disk.            |
| `Code: 60. Unknown table 'system.query_log'`                 | First `SELECT` on `query_log` arrives before its periodic flush.     | `SYSTEM FLUSH LOGS;` before the SELECT.                                                   |
| INSERT VALUES hangs forever via `clickhouse-client`          | `--multiquery --query "..."` + open stdin → CH waits for more data.  | Pipe the SQL via `printf %s "$SQL" | clickhouse-client` (this demo does that already).    |

---

## 11. Talking points for the live session

1. **Why columnar?** Walk through "SELECT avg(revenue) FROM events
   WHERE country = 'US'": only 2 columns are read; rows are processed in
   batches; the entire query touches ~kilobytes of memory.
2. **Why merges?** Show `system.merges` mid-INSERT — there's almost always
   a background job running.
3. **Sorting key vs primary key.** Most tables use only `ORDER BY` and let
   the PK equal it. The split is a tuning knob for the rare case where
   ORDER BY has high-cardinality trailing columns you don't want in the
   index.
4. **`index_granularity = 8192`** is why the PK is tiny. Demonstrate by
   showing `primary.idx` size vs row count.
5. **`OPTIMIZE FINAL`** is a debugging convenience. **Never** run it from
   cron — it'll take down a busy server.
6. **Append-only mindset.** Every INSERT writes a fresh part. Conventional
   "UPDATE" is done via Replacing/Collapsing engines (Module 2) or
   `ALTER TABLE … UPDATE` (which writes an async mutation, *not* an UPDATE).

---

## 12. Container ports

| Service        | Container port | Host port |
|----------------|----------------|-----------|
| HTTP           | 8123           | 8123      |
| Native (TCP)   | 9000           | 9000      |
| Inter-server   | 9009           | (not exposed; cluster-only) |

The default user is loopback-only when no `CLICKHOUSE_PASSWORD` is set,
so the demo's HTTP smoke test runs `wget` from *inside* the container.
Production: define users in `users.d/` (Module 5 walks through this).

---

## 13. Going deeper

- **Module 2** — every `*MergeTree` variant in detail.
- **Module 6** — the same primary-key/projection knobs, with measured
  query timings on 60M rows.
- **ClickHouse docs** — <https://clickhouse.com/docs> (especially the
  MergeTree, Codecs, and System Tables sections).

When you're comfortable with this module, tear down (`./down.sh`) and
move to Module 2.
