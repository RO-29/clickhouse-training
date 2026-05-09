# Module 9 — Kafka Ingestion

**Goal:** stand up the canonical CH-from-Kafka pipeline:

```
Kafka topic 'events'
        │   (Kafka engine table — consumer)
        ▼
   m9.events_kafka
        │   (Materialized View — moves rows)
        ▼
   m9.events           ←  durable MergeTree (the table you query)
   m9.events_per_minute←  pre-aggregated SummingMergeTree
```

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-kafka.yml up -d
```

## Run

```bash
./run.sh
ROWS=500000 ./run.sh   # send more
```

## What this proves

- **Kafka engine** is a *consumer*, not a destination — every read drains
  messages.
- **The MV is the durability boundary.** Drop the MV and the consumer keeps
  draining and *throwing the data away*. Always keep an MV pointing at a
  durable table.
- **Multiple MVs, one consumer**: both `events` and `events_per_minute` are
  written from a single read of the topic.
- **`system.kafka_consumers`** shows assignments and current offsets.
- **`system.events` named `Kafka*`** track parse errors, rebalances, etc.

## Talking points

- **Group name (`kafka_group_name`)** — your consumer group in Kafka-land.
  Multiple ClickHouse instances reading the same topic with the same group
  share the partitions. Different groups read independently.
- **`kafka_max_block_size`** — rows per block emitted to the MV. Bigger =
  fewer parts, but higher latency.
- **`kafka_handle_error_mode = 'stream'`** — adds `_error` and `_raw_message`
  virtual columns; you can route bad messages to a DLQ table via a separate
  MV.
- **Avoid `SELECT * FROM events_kafka`** — it consumes messages! Use it only
  for diagnosis.
- **Stop ingestion**: `DETACH TABLE m9.events_mv` (resumes via `ATTACH`).

## Cleanup

```bash
docker exec -i clickhouse-kafka clickhouse-client --query "DROP DATABASE m9"
docker exec kafka-broker kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic events
```
