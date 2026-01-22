# 📡 Module 9: Kafka-Based Real-Time Ingestion

> **Key Goal:** Stream data from Kafka into ClickHouse with guaranteed delivery and performance

## Architecture Overview

```
Kafka Topic Partition
        ↓
  Multiple Brokers
        ↓
    Consumer Group
        ↓
ClickHouse Kafka Engine
        ↓
 MergeTree Storage
        ↓
   Real-Time Analytics
```

---

## 🎯 Kafka Engine Setup

### Basic Kafka Table
```sql
CREATE TABLE kafka_events (
  timestamp DateTime,
  event_id UInt64,
  event_type String,
  user_id UInt64,
  properties String
) ENGINE = Kafka(
  'kafka_brokers:9092',           -- Broker list
  'events_topic',                 -- Topic
  'consumer_group_default',       -- Consumer group
  'JSONEachRow'                   -- Input format
)
SETTINGS
  kafka_num_consumers = 3,
  kafka_thread_pool_size = 8,
  kafka_max_batch_size = 100000;
```

### Multi-Topic Configuration
```sql
CREATE TABLE kafka_logs (
  timestamp DateTime,
  level String,
  message String,
  service String
) ENGINE = Kafka(
  'kafka1:9092,kafka2:9092,kafka3:9092',
  'logs_.*',                      -- Regex pattern for topics
  'log_consumer_group',
  'JSONEachRow'
)
SETTINGS
  kafka_format_string = 'JSON';
```

### Supported Input Formats
| Format | Use Case | Speed | Parsing |
|--------|----------|-------|---------|
| JSONEachRow | Web events | Medium | Flexible |
| CSV | Legacy data | Fast | Strict |
| TabSeparated | Logs | Very Fast | Strict |
| Protobuf | Binary data | Fastest | Compact |
| AvroConfluent | Confluent schema | Medium | Schema registry |

---

## 🔄 Materialized View Pattern (Consumer)

### Event Stream to MergeTree Table
```sql
-- Source: Kafka table (only keeps last offsets)
CREATE TABLE kafka_events_input (
  timestamp DateTime,
  event_id UInt64,
  event_type String,
  user_id UInt64,
  properties JSON
) ENGINE = Kafka(
  'localhost:9092',
  'events',
  'events_consumer',
  'JSONEachRow'
)
SETTINGS kafka_num_consumers = 3;

-- Target: Persistent storage
CREATE TABLE events (
  timestamp DateTime,
  event_id UInt64,
  event_type String,
  user_id UInt64,
  properties JSON
) ENGINE = MergeTree()
ORDER BY (timestamp, event_id)
PARTITION BY toYYYYMM(timestamp);

-- Materialized View: Auto-consume from Kafka
CREATE MATERIALIZED VIEW events_mv TO events
AS SELECT * FROM kafka_events_input;

-- Check consumer lag
SELECT
  kafka_group_id,
  kafka_topic,
  partition,
  current_offset,
  committed_offset,
  (committed_offset - current_offset) as lag
FROM system.kafka_consumers;
```

---

## ⚙️ Configuration & Performance Tuning

### Consumer Configuration
```sql
-- Number of concurrent consumers per broker
SETTINGS kafka_num_consumers = 3;

-- Thread pool for parsing
SETTINGS kafka_thread_pool_size = 8;

-- Batch size for inserts (records)
SETTINGS kafka_max_batch_size = 100000;

-- Poll timeout (milliseconds)
SETTINGS kafka_poll_timeout_ms = 1000;

-- Skip failed messages
SETTINGS kafka_skip_broken_messages = 1;

-- Start from offset
SETTINGS kafka_offset_storage = 'none';  -- Don't track offsets
-- OR
SETTINGS kafka_offset_storage = 'kafka';  -- Use Kafka offset management
```

### Server-Level Configuration (config.xml)
```xml
<kafka>
  <session_timeout_ms>30000</session_timeout_ms>
  <socket_keepalive_buffer_size>0</socket_keepalive_buffer_size>
  <num_consumers>3</num_consumers>
  <max_batch_size>100000</max_batch_size>
  <thread_pool_size>8</thread_pool_size>

  <librdkafka>
    <socket.keepalive.enable>true</socket.keepalive.enable>
    <api.version.request.timeout.ms>10000</api.version.request.timeout.ms>
  </librdkafka>
</kafka>
```

### Performance Optimization
```sql
-- Batch insert for higher throughput
SETTINGS
  kafka_num_consumers = 5,           -- Parallelism
  kafka_max_batch_size = 500000,     -- Larger batches
  kafka_poll_timeout_ms = 5000,      -- Longer polling
  max_threads_for_insert = 4;        -- Insert threads

-- Data compression
CREATE TABLE events (...)
ENGINE = MergeTree()
...
SETTINGS
  compression_codec = 'ZSTD(3)',
  min_bytes_to_compress = 10000;
```

---

## 🛡️ Reliability & Guarantees

### Exactly-Once Semantics
```sql
-- Problem: Duplicate processing during failures
-- Solution: Idempotent inserts with deduplication

CREATE TABLE events_dedup (
  event_id UInt64,
  timestamp DateTime,
  data String
) ENGINE = ReplacingMergeTree()
ORDER BY event_id
SETTINGS
  replicated_deduplication_window_seconds = 3600;

-- Kafka offset commit after successful insert
INSERT INTO events_dedup
SELECT * FROM kafka_events_input
WHERE event_id NOT IN (
  SELECT event_id FROM events_dedup WHERE
    timestamp > now() - INTERVAL 1 HOUR
);
```

### Offset Management
```sql
-- Manual offset reset (if needed)
-- Stop materialized view
ALTER TABLE events_mv DETACH;

-- Reset offsets
SYSTEM RESET KAFKA GROUP default;

-- Restart
ALTER TABLE events_mv ATTACH;
```

### Dead Letter Queue (DLQ) Pattern
```sql
-- Create DLQ table for failed messages
CREATE TABLE events_dlq (
  kafka_offset UInt64,
  kafka_partition Int32,
  kafka_key String,
  data String,
  error String,
  created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (created_at, kafka_partition);

-- Try-catch equivalent (skip broken)
SETTINGS kafka_skip_broken_messages = 1;

-- Manual retry processing
INSERT INTO events
SELECT
  timestamp,
  event_id,
  event_type,
  user_id,
  properties
FROM events_dlq
WHERE event_name IS NOT NULL;
```

---

## 📊 Monitoring & Troubleshooting

### Consumer Lag Monitoring
```sql
-- Real-time lag check
SELECT
  kafka_topic,
  partition,
  (committed_offset - current_offset) as lag,
  (committed_offset - current_offset) / 1000 as lag_duration_estimate
FROM system.kafka_consumers
ORDER BY lag DESC;

-- Alert if lag > 10k messages
SELECT
  if(sum(lag) > 10000, 'CRITICAL', 'OK') as status,
  sum(lag) as total_lag
FROM (
  SELECT (committed_offset - current_offset) as lag
  FROM system.kafka_consumers
);
```

### System Metrics
```sql
-- Check Kafka engine state
SELECT
  name,
  value
FROM system.events
WHERE name LIKE 'kafka%'
ORDER BY name;

-- Connection status
SELECT
  name,
  status
FROM system.parts_columns
WHERE database = 'default' AND table LIKE '%kafka%';
```

### Debugging Failed Messages
```bash
# Enable debug logging
clickhouse-client --send_logs_level=debug \
  --query="SELECT * FROM kafka_events_input LIMIT 1"

# Check Kafka broker connectivity
telnet kafka1 9092
telnet kafka2 9092

# Verify topic exists
kafka-topics.sh --bootstrap-server localhost:9092 --list | grep events
```

---

## 🔀 Multi-Source Ingestion Pattern

### Combining Multiple Kafka Topics
```sql
-- Topic 1: User events
CREATE TABLE kafka_user_events (
  timestamp DateTime,
  user_id UInt64,
  action String
) ENGINE = Kafka('localhost:9092', 'user_events', 'group1', 'JSON');

-- Topic 2: System events
CREATE TABLE kafka_system_events (
  timestamp DateTime,
  service String,
  metric_value Float64
) ENGINE = Kafka('localhost:9092', 'system_events', 'group2', 'JSON');

-- Unified view
CREATE TABLE all_events (
  timestamp DateTime,
  source String,
  data JSON
) ENGINE = MergeTree()
ORDER BY timestamp;

-- Aggregate from multiple sources
CREATE MATERIALIZED VIEW events_union TO all_events
AS
  SELECT timestamp, 'user' as source,
    JSON(user_id, action) as data FROM kafka_user_events
  UNION ALL
  SELECT timestamp, 'system' as source,
    JSON(service, metric_value) as data FROM kafka_system_events;
```

---

## ✅ Best Practices Summary

- ✓ Use ReplacingMergeTree for idempotent inserts
- ✓ Set `kafka_num_consumers` = CPU cores / 2
- ✓ Monitor consumer lag with alerts (threshold: 10k messages)
- ✓ Use materialized views for automatic consumption
- ✓ Partition data by date or time for retention
- ✓ Implement DLQ for failed messages
- ✓ Test producer message format before setup
- ✓ Use ZSTD compression for disk efficiency
- ✓ Enable Kafka offset management for recovery
- ✓ Plan capacity: 1 consumer ≈ 50-100k msg/sec

---

## 🎓 Quick Reference

**Common Commands:**
```bash
# Check consumer lag
clickhouse-client --query="
  SELECT kafka_topic, partition, committed_offset, current_offset
  FROM system.kafka_consumers"

# Monitor insert rate
clickhouse-client --query="
  SELECT database, table, event_type, cnt
  FROM system.events
  WHERE event_type = 'TableInsertValue'
  ORDER BY cnt DESC"

# Test Kafka producer
echo '{"timestamp":"2026-01-22T00:00:00","id":1}' | \
  kafka-console-producer.sh --broker-list localhost:9092 --topic events
```

**Troubleshooting:**
```bash
# Check if topic exists
kafka-topics.sh --bootstrap-server localhost:9092 --list

# Check partition count
kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --topic events

# Verify broker connectivity
nc -zv kafka1 9092
```

---

**Last Updated:** 2026-01-22 | **Module:** 9/10 | **Difficulty:** Intermediate
