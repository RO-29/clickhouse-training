-- Module 9 extras: DLQ pattern + exactly-once via ReplacingMergeTree
-- + offset reset.

-- ============================================================
-- 1. DLQ pattern.  kafka_handle_error_mode = 'stream' adds two virtual
--    columns to the Kafka engine: _error and _raw_message. Bad messages
--    (parse errors) flow through with _error populated; good messages
--    have _error = ''. We route them via two MVs.
-- ============================================================
DROP TABLE IF EXISTS m9.events_kafka_safe;
CREATE TABLE m9.events_kafka_safe
(
    event_time DateTime,
    user_id    UInt64,
    event_type String,
    revenue    Float64,
    payload    String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list           = 'm9-kafka:29092',
    kafka_topic_list            = 'events',
    kafka_group_name            = 'ch_consumer_safe',
    kafka_format                = 'JSONEachRow',
    kafka_num_consumers         = 1,
    kafka_handle_error_mode     = 'stream';

DROP TABLE IF EXISTS m9.events_dlq;
CREATE TABLE m9.events_dlq
(
    received_at DateTime DEFAULT now(),
    error       String,
    raw         String,
    topic       String,
    partition   UInt32,
    offset      UInt64
)
ENGINE = MergeTree
ORDER BY (received_at, topic, partition);

DROP TABLE IF EXISTS m9.events_dlq_mv;
CREATE MATERIALIZED VIEW m9.events_dlq_mv TO m9.events_dlq AS
SELECT now() AS received_at, _error AS error, _raw_message AS raw,
       _topic AS topic, _partition AS partition, _offset AS offset
FROM m9.events_kafka_safe
WHERE _error != '';

DROP TABLE IF EXISTS m9.events_safe;
CREATE TABLE m9.events_safe AS m9.events;

DROP TABLE IF EXISTS m9.events_safe_mv;
CREATE MATERIALIZED VIEW m9.events_safe_mv TO m9.events_safe AS
SELECT event_time, user_id, event_type, revenue, payload
FROM m9.events_kafka_safe
WHERE _error = '';

-- ============================================================
-- 2. Exactly-once via ReplacingMergeTree on a stable dedup key.
--    Even if Kafka redelivers, only the latest row per (user_id, event_time)
--    is kept after merges or via FINAL/argMax.
-- ============================================================
DROP TABLE IF EXISTS m9.events_unique;
CREATE TABLE m9.events_unique
(
    event_time  DateTime,
    user_id     UInt64,
    event_type  LowCardinality(String),
    revenue     Float64,
    payload     String,
    ingested_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(ingested_at)
ORDER BY (user_id, event_time);

DROP TABLE IF EXISTS m9.events_unique_mv;
CREATE MATERIALIZED VIEW m9.events_unique_mv TO m9.events_unique AS
SELECT event_time, user_id, event_type, revenue, payload, now() AS ingested_at
FROM m9.events_kafka;

-- ============================================================
-- 3. Inspect tables — counts will appear as the producer sends data.
-- ============================================================
SELECT 'events (durable)',     count() FROM m9.events;
SELECT 'events_safe (durable)', count() FROM m9.events_safe;
SELECT 'events_unique',        count() FROM m9.events_unique;
SELECT 'events_dlq',           count() FROM m9.events_dlq;

-- ============================================================
-- 4. Operational tools (text-only, run from inside m9-kafka):
--      kafka-consumer-groups --bootstrap-server localhost:9092 \
--          --group ch_consumer --describe
--      kafka-consumer-groups --bootstrap-server localhost:9092 \
--          --group ch_consumer --reset-offsets --to-earliest \
--          --topic events --execute
--    Inside ClickHouse:
--      DETACH TABLE m9.events_mv;     -- stop consumption
--      ATTACH TABLE m9.events_mv;     -- resume from last committed offset
-- ============================================================
SELECT 'See README.md for SYSTEM RESET / consumer-group commands.';
