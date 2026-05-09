-- Module 1: Fundamentals
-- Purpose: build a single MergeTree table large enough to actually see
-- parts/merges/granules in system tables.

CREATE DATABASE IF NOT EXISTS m1;

DROP TABLE IF EXISTS m1.events;

CREATE TABLE m1.events
(
    event_time  DateTime,
    user_id     UInt32,
    country     LowCardinality(String),
    device      LowCardinality(String),
    event_type  LowCardinality(String),
    revenue     Float64,
    session_id  UUID,
    url         String
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_time)
ORDER BY (event_time, user_id)
SETTINGS index_granularity = 8192;
