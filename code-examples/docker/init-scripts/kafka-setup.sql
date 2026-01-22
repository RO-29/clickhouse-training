-- Kafka Integration Setup for Module 9
-- Purpose: Create Kafka table engines and materialized views

CREATE DATABASE IF NOT EXISTS kafka_demo;

-- Raw events table that reads from Kafka
CREATE TABLE IF NOT EXISTS kafka_demo.raw_events_kafka (
    event_id String,
    event_timestamp DateTime,
    user_id UInt64,
    event_type String,
    event_properties String,
    _timestamp DateTime
) ENGINE = Kafka()
SETTINGS kafka_broker_list = 'kafka:29092',
          kafka_topic_list = 'events-topic',
          kafka_group_id = 'clickhouse-group',
          kafka_format = 'JSONEachRow',
          kafka_skip_broken_messages = 1,
          kafka_commit_on_select = 1,
          kafka_num_consumers = 2;

-- Final events table with MergeTree engine
CREATE TABLE IF NOT EXISTS kafka_demo.events (
    event_id String,
    event_timestamp DateTime,
    user_id UInt64,
    event_type String,
    event_properties String,
    _timestamp DateTime
) ENGINE = MergeTree()
ORDER BY (event_timestamp, user_id)
PARTITION BY toYYYYMM(event_timestamp);

-- Materialized view to consume from Kafka and insert into events table
CREATE MATERIALIZED VIEW IF NOT EXISTS kafka_demo.events_view TO kafka_demo.events
AS SELECT
    event_id,
    event_timestamp,
    user_id,
    event_type,
    event_properties,
    now() as _timestamp
FROM kafka_demo.raw_events_kafka;

-- Order events stream
CREATE TABLE IF NOT EXISTS kafka_demo.orders_kafka (
    order_id String,
    order_timestamp DateTime,
    user_id UInt64,
    product_id UInt64,
    quantity Int32,
    price Float64,
    total_amount Float64
) ENGINE = Kafka()
SETTINGS kafka_broker_list = 'kafka:29092',
          kafka_topic_list = 'orders-topic',
          kafka_group_id = 'clickhouse-orders-group',
          kafka_format = 'JSONEachRow',
          kafka_skip_broken_messages = 1,
          kafka_commit_on_select = 1;

-- Orders destination table
CREATE TABLE IF NOT EXISTS kafka_demo.orders (
    order_id String,
    order_date Date,
    order_timestamp DateTime,
    user_id UInt64,
    product_id UInt64,
    quantity Int32,
    price Float64,
    total_amount Float64,
    processed_at DateTime
) ENGINE = MergeTree()
ORDER BY (order_date, user_id)
PARTITION BY toYYYYMM(order_date);

-- Materialized view for orders
CREATE MATERIALIZED VIEW IF NOT EXISTS kafka_demo.orders_view TO kafka_demo.orders
AS SELECT
    order_id,
    toDate(order_timestamp) as order_date,
    order_timestamp,
    user_id,
    product_id,
    quantity,
    price,
    total_amount,
    now() as processed_at
FROM kafka_demo.orders_kafka;

-- Aggregated metrics table
CREATE TABLE IF NOT EXISTS kafka_demo.hourly_metrics (
    metric_hour DateTime,
    event_type String,
    user_id UInt64,
    event_count UInt64,
    total_value Float64
) ENGINE = SummingMergeTree()
ORDER BY (metric_hour, event_type, user_id)
PARTITION BY toYYYYMM(metric_hour);

-- Real-time aggregation view
CREATE MATERIALIZED VIEW IF NOT EXISTS kafka_demo.metrics_view TO kafka_demo.hourly_metrics
AS SELECT
    toStartOfHour(event_timestamp) as metric_hour,
    event_type,
    user_id,
    count() as event_count,
    sum(toFloat64OrZero(event_properties['value'])) as total_value
FROM kafka_demo.events
GROUP BY metric_hour, event_type, user_id;

-- Dead letter queue for failed messages
CREATE TABLE IF NOT EXISTS kafka_demo.failed_messages (
    error_time DateTime,
    error_message String,
    message_body String,
    topic String
) ENGINE = MergeTree()
ORDER BY error_time
PARTITION BY toYYYYMM(error_time);

-- Session tracking table
CREATE TABLE IF NOT EXISTS kafka_demo.user_sessions (
    session_id String,
    user_id UInt64,
    session_start DateTime,
    session_end DateTime,
    events_count UInt32,
    session_duration UInt32
) ENGINE = MergeTree()
ORDER BY (user_id, session_start)
PARTITION BY toYYYYMM(session_start);

-- Log successful setup
SELECT 'Kafka integration setup completed successfully' AS status;
