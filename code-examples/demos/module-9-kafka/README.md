# Module 9 — Kafka Ingestion (standalone)

Self-contained stack: ClickHouse + Kafka + ZooKeeper + Kafka UI. Demonstrates
the canonical `Kafka engine → MV → MergeTree` pipeline.

## What you get

```
docker-compose.yml          # m9-clickhouse + m9-kafka + m9-zk + m9-kafka-ui
configs/clickhouse-config.xml
setup.sql                   # Kafka source + 2 destination tables + 2 MVs
produce.py                  # JSONEachRow producer (pure stdlib)
queries.sql
up.sh · run.sh · down.sh
```

## Container map

| Service     | Container       | Host ports                    |
|-------------|-----------------|-------------------------------|
| ClickHouse  | `m9-clickhouse` | 8123, 9000                    |
| Kafka       | `m9-kafka`      | 9092 (host), 29092 (internal) |
| ZooKeeper   | `m9-zk`         | (internal only)               |
| Kafka UI    | `m9-kafka-ui`   | 8080                          |

Internally the broker hostname is `m9-kafka:29092` (used in `setup.sql`).

## Run

```bash
./up.sh                      # start the whole stack
./run.sh                     # create topic, run setup, produce, verify
ROWS=500000 ./run.sh         # produce more
./down.sh
```

## Execution flow — what `./run.sh` actually does, in order

| #  | Step                                   | What happens                                                                                                                                                                                                                                                                                                                |
|----|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap                         | `up.sh` brings up the 4-container stack (`m9-clickhouse`, `m9-kafka`, `m9-zk`, `m9-kafka-ui`) and waits until `m9-clickhouse:/ping` and `m9-kafka:9092` both answer.                                                                                                                                                       |
| 1  | Create `events` topic                  | `kafka-topics --create --if-not-exists --topic events --partitions 3 --replication-factor 1`.                                                                                                                                                                                                                              |
| 2  | `setup.sql`                            | Creates database `m9` and the canonical pipeline: `events_kafka` (Kafka engine, `JSONEachRow`, group `ch_consumer`), `events` (durable MergeTree), `events_mv` (MV moves rows from Kafka → events), `events_per_minute` (SummingMergeTree), `events_per_minute_mv` (MV doing minute-bucket aggregation). One Kafka read serves both MVs. |
| 3  | `extras.sql`                           | Adds the **DLQ pipeline**: a second Kafka source `events_kafka_safe` with `kafka_handle_error_mode = 'stream'` (group `ch_consumer_safe`); two MVs split it on `_error == ''` → `events_safe`, `_error != ''` → `events_dlq` (with topic/partition/offset preserved). Also creates `events_unique` (ReplacingMergeTree on `(user_id, event_time)` for **exactly-once** semantics) and `events_unique_mv`. |
| 4  | Produce **valid** messages             | `python3 produce.py --rows $ROWS` (default 100k) → piped into `kafka-console-producer --topic events`. JSON shape matches the source table.                                                                                                                                                                                |
| 5  | Produce **broken** messages            | 50 deliberately malformed JSON lines → `kafka-console-producer --topic events`. These get rejected by the strict consumer (`events_kafka`) but flow through the safe consumer (`events_kafka_safe`) into `events_dlq`.                                                                                                  |
| 6  | Sleep 8 s                              | Lets the Kafka MVs catch up (default `flush_interval_ms = 7500`).                                                                                                                                                                                                                                                          |
| 7  | `queries.sql`                          | Inspects: total rows in `events`, per-event-type breakdown, the SummingMergeTree minute buckets, `system.kafka_consumers` (assignments, offsets), `system.events` Kafka counters.                                                                                                                                          |
| 8  | DLQ + exactly-once verification        | Prints `events_dlq` count (~50, the bad messages), `events_safe` count (~`$ROWS`), `events_unique FINAL` count, and a top-3 of `_error` strings.                                                                                                                                                                          |

Container stack stays up after `./run.sh`. Tear down with `./down.sh`.

## Pipeline shape

```
Kafka topic 'events'
        │   (Kafka engine table — consumer)
        ▼
   m9.events_kafka
        │   (Materialized View — moves rows)
        ▼
   m9.events           ← durable MergeTree (the table you query)
   m9.events_per_minute ← pre-aggregated SummingMergeTree
```

Both MVs read from the same Kafka source — single consumer, two writes.

## What this proves

- Kafka engine is a *consumer*, not a destination.
- The MV is the durability boundary. No MV → consumed messages are lost.
- `system.kafka_consumers` shows assignments and current offsets.
- `system.events` named `Kafka*` track parse errors and rebalances.

## Talking points

- **`kafka_group_name`** is your consumer group; multiple ClickHouse
  instances in the same group share partitions.
- **`kafka_handle_error_mode = 'stream'`** adds `_error` and `_raw_message`
  virtual columns; route bad messages to a DLQ table via a separate MV.
- **Don't `SELECT * FROM events_kafka`** — it consumes! Use only for
  diagnosis.
- **Stop ingestion**: `DETACH TABLE m9.events_mv` (resume via `ATTACH`).

## Extras (curriculum coverage)

`extras.sql` adds three more curriculum topics, exercised by `run.sh`:

- **DLQ pattern** — a second Kafka source `events_kafka_safe` with
  `kafka_handle_error_mode = 'stream'` exposes `_error` /
  `_raw_message` virtual columns. Two MVs split the stream:
  good rows → `events_safe`, bad rows → `events_dlq` (with topic /
  partition / offset for replay).
- **Exactly-once via ReplacingMergeTree** — `events_unique` keyed by
  `(user_id, event_time)` with `ingested_at` as the version. Use `FINAL`
  or `argMax` to read deduped.
- **Bad-message demo** — `run.sh` produces 50 invalid JSON lines after
  the valid batch; you should see ~50 rows in `events_dlq`.

### Replay / offset-reset operations

```bash
# Inspect the consumer group lag (run inside the Kafka container)
docker exec m9-kafka \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
    --group ch_consumer --describe

# Rewind to earliest — re-consumes the entire topic
docker exec m9-kafka \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
    --group ch_consumer --reset-offsets --to-earliest \
    --topic events --execute
```

In ClickHouse you can pause/resume consumption without losing offset:

```sql
DETACH TABLE m9.events_mv;   -- stops the Kafka consumer
ATTACH TABLE m9.events_mv;   -- resumes from last committed offset
```

### Other formats (text-only)

The demo uses `JSONEachRow`. Swap `kafka_format` to `Protobuf`, `Avro`,
`AvroConfluent`, `CSV`, or `TabSeparated` and provide
`format_schema = '<file>:<MessageType>'` for the schema-bound formats.

## Cleanup

`./down.sh` drops the whole stack including volumes. To reset Kafka without
tearing down:

```bash
docker exec -i m9-clickhouse clickhouse-client --query "DROP DATABASE m9"
docker exec m9-kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic events
```
