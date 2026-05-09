-- Module 2: a tour of the engines you'll actually use.
-- One database, one engine per table.

CREATE DATABASE IF NOT EXISTS m2;

-- 1. ReplacingMergeTree: dedup on the sort key, keeping the row with the largest 'version'.
DROP TABLE IF EXISTS m2.users_replacing;
CREATE TABLE m2.users_replacing
(
    user_id UInt64,
    name    String,
    email   String,
    version UInt64,                       -- ts/version column
    deleted UInt8 DEFAULT 0
)
ENGINE = ReplacingMergeTree(version)
ORDER BY user_id;

-- 2. SummingMergeTree: collapses rows with the same sort key, summing numeric columns.
DROP TABLE IF EXISTS m2.metrics_summing;
CREATE TABLE m2.metrics_summing
(
    metric_date Date,
    metric      LowCardinality(String),
    region      LowCardinality(String),
    value       UInt64,
    count       UInt64 DEFAULT 1
)
ENGINE = SummingMergeTree((value, count))
ORDER BY (metric_date, metric, region);

-- 3. AggregatingMergeTree: stores AggregateFunction state, finalize on read.
DROP TABLE IF EXISTS m2.events_agg;
CREATE TABLE m2.events_agg
(
    bucket_date     Date,
    country         LowCardinality(String),
    uniq_users_state AggregateFunction(uniq, UInt32),
    revenue_state    AggregateFunction(sum, Float64),
    p99_state        AggregateFunction(quantileTDigest(0.99), Float32)
)
ENGINE = AggregatingMergeTree
ORDER BY (bucket_date, country);

-- 4. CollapsingMergeTree: the "current state" engine. Sign = 1 inserts, Sign = -1 cancels.
DROP TABLE IF EXISTS m2.orders_collapsing;
CREATE TABLE m2.orders_collapsing
(
    order_id UInt64,
    status   LowCardinality(String),
    total    Float64,
    sign     Int8
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY order_id;

-- 5. Log-family: tiny tables, no parts, no indexes. Don't use for serious data.
DROP TABLE IF EXISTS m2.audit_log;
CREATE TABLE m2.audit_log
(
    ts DateTime DEFAULT now(),
    actor String,
    action String
)
ENGINE = Log;

-- 6. Memory: in-RAM, lost on restart. Useful for ephemeral state and tests.
DROP TABLE IF EXISTS m2.tmp_uploads;
CREATE TABLE m2.tmp_uploads
(
    upload_id UUID,
    payload   String
)
ENGINE = Memory;

-- 7. Buffer: front-end to a real table that absorbs small/frequent inserts.
DROP TABLE IF EXISTS m2.facts_dest;
CREATE TABLE m2.facts_dest
(
    ts DateTime,
    metric LowCardinality(String),
    value Float64
)
ENGINE = MergeTree
ORDER BY (metric, ts);

DROP TABLE IF EXISTS m2.facts_buffer;
CREATE TABLE m2.facts_buffer AS m2.facts_dest
ENGINE = Buffer(m2, facts_dest,
    16,         -- num_layers
    10, 60,     -- min/max time (seconds)
    10000, 1000000,    -- min/max rows
    10000000, 100000000); -- min/max bytes
