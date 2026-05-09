-- Module 9: Kafka ingestion.
-- The kafka container is reachable inside the docker network as kafka:29092.

CREATE DATABASE IF NOT EXISTS m9;

-- 1. The Kafka source table. Reading from this consumes messages.
DROP TABLE IF EXISTS m9.events_kafka;
CREATE TABLE m9.events_kafka
(
    event_time DateTime,
    user_id    UInt64,
    event_type String,
    revenue    Float64,
    payload    String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list   = 'kafka:29092',
    kafka_topic_list    = 'events',
    kafka_group_name    = 'ch_consumer',
    kafka_format        = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_max_block_size = 1048576;

-- 2. The durable destination.
DROP TABLE IF EXISTS m9.events;
CREATE TABLE m9.events
(
    event_time DateTime,
    user_id    UInt64,
    event_type LowCardinality(String),
    revenue    Float64,
    payload    String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (event_type, event_time);

-- 3. The Materialized View glues source → destination. As long as this MV
--    exists, ClickHouse keeps consuming from Kafka and inserting rows.
DROP TABLE IF EXISTS m9.events_mv;
CREATE MATERIALIZED VIEW m9.events_mv TO m9.events AS
SELECT event_time, user_id, event_type, revenue, payload
FROM m9.events_kafka;

-- 4. A second MV that does pre-aggregation on the way in.
DROP TABLE IF EXISTS m9.events_per_minute;
CREATE TABLE m9.events_per_minute
(
    minute     DateTime,
    event_type LowCardinality(String),
    events     UInt64,
    revenue    Float64
)
ENGINE = SummingMergeTree
ORDER BY (minute, event_type);

DROP TABLE IF EXISTS m9.events_per_minute_mv;
CREATE MATERIALIZED VIEW m9.events_per_minute_mv TO m9.events_per_minute AS
SELECT
    toStartOfMinute(event_time) AS minute,
    event_type,
    count()       AS events,
    sum(revenue)  AS revenue
FROM m9.events_kafka
GROUP BY minute, event_type;
