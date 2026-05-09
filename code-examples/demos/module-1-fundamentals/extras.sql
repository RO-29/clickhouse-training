-- Module 1 extras: topics from the curriculum that the main demo skipped.
-- TTL, codecs, complex types (Array/Tuple/Map/Nested/Enum), DESCRIBE.

-- ============================================================
-- 1. TTL — automatically drop or move rows based on a date column.
-- ============================================================
DROP TABLE IF EXISTS m1.events_ttl;
CREATE TABLE m1.events_ttl
(
    event_time DateTime,
    user_id    UInt32,
    payload    String
)
ENGINE = MergeTree
ORDER BY (user_id, event_time)
-- Whole-row TTL: rows older than 7 days get deleted at merge time.
-- Column-level: write TTL right after the column type (e.g. payload String TTL ...).
-- Move-to-cold: TTL event_time + INTERVAL 30 DAY TO VOLUME 'cold'.
TTL event_time + INTERVAL 7 DAY DELETE
SETTINGS merge_with_ttl_timeout = 60;

INSERT INTO m1.events_ttl SELECT
    now() - INTERVAL (number % 30) DAY, number, repeat('x', 50)
FROM numbers(1000);

-- Force a merge so TTL runs now (in production, it runs in the background).
OPTIMIZE TABLE m1.events_ttl FINAL;
SELECT count() AS rows_after_ttl,
       min(event_time) AS oldest, max(event_time) AS newest
FROM m1.events_ttl;

-- ============================================================
-- 2. Codecs — Delta, T64, ZSTD on time-series-shaped data.
--    Compare compressed sizes via system.columns.
-- ============================================================
DROP TABLE IF EXISTS m1.codecs_demo;
CREATE TABLE m1.codecs_demo
(
    ts_default DateTime,                                 -- LZ4 default
    ts_delta   DateTime CODEC(Delta(4), LZ4),            -- delta-of-delta then LZ4
    ts_zstd    DateTime CODEC(ZSTD(3)),                  -- ZSTD level 3
    val_t64    UInt64   CODEC(T64, LZ4),                 -- bit-packing for ints
    val_default UInt64                                   -- LZ4 default
)
ENGINE = MergeTree ORDER BY tuple();

INSERT INTO m1.codecs_demo
SELECT
    toDateTime('2026-01-01') + number,
    toDateTime('2026-01-01') + number,
    toDateTime('2026-01-01') + number,
    1000000 + number,
    1000000 + number
FROM numbers(1000000);

OPTIMIZE TABLE m1.codecs_demo FINAL;

SELECT
    name AS column,
    formatReadableSize(data_compressed_bytes)   AS compressed,
    formatReadableSize(data_uncompressed_bytes) AS raw,
    round(data_compressed_bytes / data_uncompressed_bytes, 4) AS ratio
FROM system.columns
WHERE database = 'm1' AND table = 'codecs_demo'
ORDER BY column;

-- ============================================================
-- 3. Complex types: Array, Tuple, Map, Nested, Enum, Nullable.
-- ============================================================
DROP TABLE IF EXISTS m1.complex_types;
CREATE TABLE m1.complex_types
(
    id          UInt64,
    -- Enum: small numeric tag, big readable name. Cheap.
    status      Enum8('new'=1, 'paid'=2, 'shipped'=3, 'cancelled'=4),
    -- Nullable: column can have NULLs. Has a small overhead.
    note        Nullable(String),
    -- Array of strings; uses Array() type.
    tags        Array(String),
    -- Tuple = anonymous struct. Untyped fields by position.
    coords      Tuple(Float64, Float64),
    -- Map: like a Python dict. Keys all one type, values all one type.
    attrs       Map(String, String),
    -- Nested: a "table inside a row". Stored as parallel Arrays.
    items       Nested(sku String, qty UInt32, price Decimal(10,2))
)
ENGINE = MergeTree ORDER BY id;

INSERT INTO m1.complex_types VALUES
    (1, 'paid', 'first-class', ['vip','express'], (52.52, 13.40),
     {'utm':'google','region':'eu'},
     ['SKU-1','SKU-2'], [2, 1], [9.99, 25.00]),
    (2, 'new', NULL, ['standard'], (40.71, -74.00),
     {'utm':'direct'},
     ['SKU-9'], [3], [12.50]);

-- Query a Nested column: it's just two parallel Arrays.
SELECT id, items.sku, items.qty, items.price FROM m1.complex_types ORDER BY id;

-- Array accessors
SELECT id, tags, length(tags) AS n_tags, has(tags, 'vip') AS is_vip
FROM m1.complex_types ORDER BY id;

-- Map accessors
SELECT id, attrs['utm'] AS source, mapKeys(attrs) AS keys FROM m1.complex_types ORDER BY id;

-- Enum: stored as Int8, displayed as string.
SELECT status, count() FROM m1.complex_types GROUP BY status ORDER BY status;

-- ============================================================
-- 4. DESCRIBE TABLE shows the resolved schema, including codecs/TTL.
-- ============================================================
DESCRIBE TABLE m1.codecs_demo;
SHOW CREATE TABLE m1.events_ttl;
