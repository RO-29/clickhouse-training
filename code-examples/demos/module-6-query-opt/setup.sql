-- Module 6: query optimization. Same data, three table layouts.
-- We're going to measure timings on each.

CREATE DATABASE IF NOT EXISTS m6;

-- Layout A: bad ordering (random key first → no useful PK pruning).
DROP TABLE IF EXISTS m6.events_bad;
CREATE TABLE m6.events_bad
(
    event_time DateTime,
    user_id    UInt64,
    country    LowCardinality(String),
    device     LowCardinality(String),
    event_type LowCardinality(String),
    amount     Float64,
    url        String
)
ENGINE = MergeTree
ORDER BY (event_type, country)
PARTITION BY toYYYYMM(event_time);

-- Layout B: time-first. Range queries on event_time are cheap.
DROP TABLE IF EXISTS m6.events_good;
CREATE TABLE m6.events_good
(
    event_time DateTime,
    user_id    UInt64,
    country    LowCardinality(String),
    device     LowCardinality(String),
    event_type LowCardinality(String),
    amount     Float64,
    url        String
)
ENGINE = MergeTree
ORDER BY (event_time, user_id)
PARTITION BY toYYYYMM(event_time);

-- Layout C: same as B + a projection optimised for "by country, by day".
DROP TABLE IF EXISTS m6.events_proj;
CREATE TABLE m6.events_proj
(
    event_time DateTime,
    user_id    UInt64,
    country    LowCardinality(String),
    device     LowCardinality(String),
    event_type LowCardinality(String),
    amount     Float64,
    url        String,
    -- skip index: bloom filter on user_id for point lookups
    INDEX bf_user user_id TYPE bloom_filter() GRANULARITY 4,
    PROJECTION pv_country_day (
        SELECT country, toDate(event_time) AS day,
               count(), sum(amount), avg(amount)
        GROUP BY country, day
    )
)
ENGINE = MergeTree
ORDER BY (event_time, user_id)
PARTITION BY toYYYYMM(event_time);
