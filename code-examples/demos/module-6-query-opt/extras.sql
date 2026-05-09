-- Module 6 extras: query-optimization tools the core demo skipped.
-- PREWHERE, SAMPLE, more skip indexes, JOIN strategies, Materialized Views.

-- ============================================================
-- 1. PREWHERE — apply a cheap predicate first to prune granules,
--    then read remaining columns. Often automatic; you can force it.
-- ============================================================
SELECT 'PREWHERE auto:';
SELECT count() FROM m6.events_good WHERE country = 'US' AND amount > 100;

SELECT 'PREWHERE explicit:';
SELECT count() FROM m6.events_good PREWHERE country = 'US' WHERE amount > 100;

EXPLAIN SYNTAX SELECT count() FROM m6.events_good WHERE country = 'US' AND amount > 100;

-- ============================================================
-- 2. SAMPLE — fast approximate aggregations on a defined sample.
--    Requires SAMPLE BY in the table. Add it on a copy.
-- ============================================================
DROP TABLE IF EXISTS m6.events_sampled;
CREATE TABLE m6.events_sampled
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
PARTITION BY toYYYYMM(event_time)
ORDER BY (event_time, intHash32(user_id), user_id)
SAMPLE BY intHash32(user_id);

INSERT INTO m6.events_sampled SELECT * FROM m6.events_good;

-- 1/10 sample — order of magnitude faster, ~10× variance.
SELECT 'SAMPLE 0.1:', count(), avg(amount)
FROM m6.events_sampled SAMPLE 0.1;

-- Full scan baseline.
SELECT 'NO SAMPLE:',  count(), avg(amount)
FROM m6.events_sampled;

-- ============================================================
-- 3. More skip-index types: minmax, set, tokenbf_v1.
-- ============================================================
DROP TABLE IF EXISTS m6.events_idx;
CREATE TABLE m6.events_idx
(
    event_time DateTime,
    user_id    UInt64,
    country    LowCardinality(String),
    amount     Float64,
    url        String,

    INDEX idx_amount   amount  TYPE minmax        GRANULARITY 4,
    INDEX idx_country  country TYPE set(100)      GRANULARITY 4,
    INDEX idx_url_tok  url     TYPE tokenbf_v1(8192, 3, 0) GRANULARITY 4
)
ENGINE = MergeTree
ORDER BY (event_time, user_id);

INSERT INTO m6.events_idx SELECT event_time, user_id, country, amount, url FROM m6.events_good;

-- minmax wins for range filters
SELECT 'minmax range:', count() FROM m6.events_idx WHERE amount > 450;

-- set wins for IN with low-cardinality
SELECT 'set IN:',       count() FROM m6.events_idx WHERE country IN ('US','IN');

-- tokenbf_v1 helps for substring search via hasToken()
SELECT 'token search:', count() FROM m6.events_idx WHERE hasToken(url, '42');

EXPLAIN indexes = 1
SELECT count() FROM m6.events_idx WHERE amount > 450;

-- ============================================================
-- 4. JOIN strategies — same query, three flavours.
-- ============================================================
DROP TABLE IF EXISTS m6.users_dim;
CREATE TABLE m6.users_dim
(
    user_id     UInt64,
    cohort      LowCardinality(String),
    signup_date Date
)
ENGINE = MergeTree ORDER BY user_id;

INSERT INTO m6.users_dim
SELECT
    number,
    arrayElement(['alpha','beta','gamma','delta'], 1 + toUInt8(rand(number) % 4)),
    toDate('2025-01-01') + (rand(number+1) % 365)
FROM numbers(500000);

-- ANY JOIN: take the first match, faster.
SELECT 'ANY JOIN:',
    count(), avgIf(amount, cohort = 'alpha') AS alpha_avg
FROM m6.events_good AS e
ANY LEFT JOIN m6.users_dim AS u USING (user_id);

-- ALL JOIN: cartesian on duplicates (default).
SELECT 'ALL JOIN:',
    count(), avgIf(amount, cohort = 'alpha') AS alpha_avg
FROM m6.events_good AS e
ALL LEFT JOIN m6.users_dim AS u USING (user_id);

-- Dictionary lookup — best for tiny dimension tables.
DROP DICTIONARY IF EXISTS m6.users_dict;
CREATE DICTIONARY m6.users_dict
(
    user_id UInt64,
    cohort  String,
    signup_date Date
)
PRIMARY KEY user_id
SOURCE(CLICKHOUSE(host 'localhost' port 9000 db 'm6' table 'users_dim'))
LIFETIME(MIN 60 MAX 300)
LAYOUT(HASHED());

SYSTEM RELOAD DICTIONARY m6.users_dict;
SELECT 'Dictionary lookup:',
    count() AS rows,
    avgIf(amount, dictGetString('m6.users_dict', 'cohort', user_id) = 'alpha') AS alpha_avg
FROM m6.events_good;

-- ============================================================
-- 5. Materialized View — precomputed aggregation maintained on insert.
-- ============================================================
DROP TABLE IF EXISTS m6.country_daily;
CREATE TABLE m6.country_daily
(
    day      Date,
    country  LowCardinality(String),
    events   UInt64,
    revenue  Float64
)
ENGINE = SummingMergeTree
ORDER BY (day, country);

DROP TABLE IF EXISTS m6.country_daily_mv;
CREATE MATERIALIZED VIEW m6.country_daily_mv TO m6.country_daily AS
SELECT
    toDate(event_time) AS day,
    country,
    count()            AS events,
    sum(amount)        AS revenue
FROM m6.events_good
GROUP BY day, country;

-- Backfill the MV from existing data.
INSERT INTO m6.country_daily
SELECT toDate(event_time), country, count(), sum(amount)
FROM m6.events_good GROUP BY toDate(event_time), country;

SELECT day, country, sum(events), round(sum(revenue), 2)
FROM m6.country_daily GROUP BY day, country
ORDER BY day, country LIMIT 8;
