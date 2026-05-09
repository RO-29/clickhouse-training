SET async_insert = 0;  -- VALUES + --multiquery clashes with async_insert defaults on CH 26.x

-- Module 2 extras: engines + patterns the core demo glossed over.
-- VersionedCollapsing, Materialized Views, Nested type.

-- ============================================================
-- 1. VersionedCollapsingMergeTree
--    Like Collapsing, but with a version column. Out-of-order inserts of
--    sign=+1 / sign=-1 are tolerated — the version determines the order.
-- ============================================================
DROP TABLE IF EXISTS m2.orders_versioned;
CREATE TABLE m2.orders_versioned
(
    order_id  UInt64,
    status    LowCardinality(String),
    total     Float64,
    version   UInt64,
    sign      Int8
)
ENGINE = VersionedCollapsingMergeTree(sign, version)
ORDER BY order_id;

INSERT INTO m2.orders_versioned VALUES
    (1, 'pending', 10.0, 1, +1),
    (1, 'pending', 10.0, 1, -1),    -- cancel v1
    (1, 'paid',    10.0, 2, +1);    -- v2 wins

INSERT INTO m2.orders_versioned VALUES
    (2, 'pending', 25.0, 1, +1),
    (2, 'paid',    25.0, 2, +1),    -- inserted out of order
    (2, 'pending', 25.0, 1, -1);    -- cancellation arrives last

OPTIMIZE TABLE m2.orders_versioned FINAL;
SELECT '-- versioned collapsing, after merge --';
SELECT * FROM m2.orders_versioned ORDER BY order_id;

-- ============================================================
-- 2. Materialized Views — the "computed table" pattern.
--    The MV runs against rows being INSERTED into a source table and
--    writes the result into a target. Not a SELECT-time view.
-- ============================================================
DROP TABLE IF EXISTS m2.events_src;
CREATE TABLE m2.events_src
(
    ts          DateTime,
    user_id     UInt64,
    event_type  LowCardinality(String),
    revenue     Float64
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (event_type, ts);

DROP TABLE IF EXISTS m2.events_per_minute;
CREATE TABLE m2.events_per_minute
(
    bucket     DateTime,
    event_type LowCardinality(String),
    events     UInt64,
    revenue    Float64
)
ENGINE = SummingMergeTree
ORDER BY (bucket, event_type);

DROP TABLE IF EXISTS m2.events_per_minute_mv;
CREATE MATERIALIZED VIEW m2.events_per_minute_mv TO m2.events_per_minute AS
SELECT
    toStartOfMinute(ts) AS bucket,
    event_type,
    count()             AS events,
    sum(revenue)        AS revenue
FROM m2.events_src
GROUP BY bucket, event_type;

INSERT INTO m2.events_src
SELECT
    toDateTime('2026-05-01 00:00:00') + INTERVAL (number % 7200) SECOND,
    1 + rand(number) % 10000,
    arrayElement(['view','click','purchase'], 1 + toUInt8(rand(number+1) % 3)),
    if(rand(number+1)%3 = 2, round(5 + rand(number+2)%19500/100, 2), 0.0)
FROM numbers(200000);

SELECT '-- source rows --';   SELECT count() FROM m2.events_src;
SELECT '-- agg rows --';      SELECT count() FROM m2.events_per_minute;
SELECT bucket, event_type, sum(events) AS events, round(sum(revenue),2) AS revenue
FROM m2.events_per_minute
GROUP BY bucket, event_type
ORDER BY bucket, event_type LIMIT 8;

-- ============================================================
-- 3. Nested type — a "table inside a row" stored as parallel arrays.
-- ============================================================
DROP TABLE IF EXISTS m2.invoices;
CREATE TABLE m2.invoices
(
    invoice_id UInt64,
    customer   String,
    total      Decimal(12, 2),
    line_items Nested(
        sku   String,
        qty   UInt32,
        price Decimal(10, 2)
    )
)
ENGINE = MergeTree ORDER BY invoice_id;

INSERT INTO m2.invoices VALUES
    (1001, 'Alice', 49.97, ['SKU-A','SKU-B','SKU-C'], [1,2,1], [9.99, 14.99, 10.00]),
    (1002, 'Bob',   25.00, ['SKU-A'],                [1],     [25.00]);

-- Nested fields are queried with dot-notation; ARRAY JOIN flattens the rows.
SELECT
    invoice_id,
    customer,
    line_items.sku   AS skus,
    line_items.qty   AS qtys,
    arraySum(arrayMap((q, p) -> q * p, line_items.qty, line_items.price)) AS computed_total
FROM m2.invoices ORDER BY invoice_id;

-- ARRAY JOIN view: one row per line item.
SELECT invoice_id, sku, qty, price
FROM m2.invoices
ARRAY JOIN line_items.sku AS sku, line_items.qty AS qty, line_items.price AS price
ORDER BY invoice_id, sku;
