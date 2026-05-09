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
