-- ============================================================
-- ReplacingMergeTree: same key with different versions
-- ============================================================
-- Naive read: sees ALL inserted rows (no merge yet).
SELECT user_id, name, email, version FROM m2.users_replacing ORDER BY user_id, version;

-- 'FINAL' returns the deduped view as if a merge happened. Slower; don't ship
-- this in hot paths.
SELECT user_id, name, email, version FROM m2.users_replacing FINAL ORDER BY user_id;

-- The "production" pattern: argMax in the query.
SELECT
    user_id,
    argMax(name,    version) AS name,
    argMax(email,   version) AS email,
    max(version)             AS version
FROM m2.users_replacing
GROUP BY user_id ORDER BY user_id;

OPTIMIZE TABLE m2.users_replacing FINAL;
SELECT '-- after OPTIMIZE FINAL --';
SELECT * FROM m2.users_replacing ORDER BY user_id;

-- ============================================================
-- SummingMergeTree
-- ============================================================
-- Before merge there can be many rows per (date, metric, region); query them
-- with sum() to get the truth regardless.
SELECT count() AS rows_before_optimize FROM m2.metrics_summing;
OPTIMIZE TABLE m2.metrics_summing FINAL;
SELECT count() AS rows_after_optimize  FROM m2.metrics_summing;

SELECT metric, region, sum(value) AS total_value, sum(count) AS total_count
FROM m2.metrics_summing GROUP BY metric, region ORDER BY metric, region;

-- ============================================================
-- AggregatingMergeTree: must finalize states with -Merge functions.
-- ============================================================
SELECT
    bucket_date,
    country,
    uniqMerge(uniq_users_state) AS uniq_users,
    sumMerge(revenue_state)     AS revenue,
    quantileTDigestMerge(0.99)(p99_state) AS p99
FROM m2.events_agg
GROUP BY bucket_date, country
ORDER BY bucket_date, country LIMIT 10;

-- ============================================================
-- CollapsingMergeTree: order 101 should resolve to "paid" after collapse.
-- ============================================================
SELECT * FROM m2.orders_collapsing ORDER BY order_id, sign;

OPTIMIZE TABLE m2.orders_collapsing FINAL;
SELECT '-- after collapse --';
SELECT * FROM m2.orders_collapsing ORDER BY order_id;

-- The "do it in the query" pattern (works without OPTIMIZE):
SELECT order_id, argMax(status, sign) AS status, sum(total * sign) AS total
FROM m2.orders_collapsing GROUP BY order_id ORDER BY order_id;

-- ============================================================
-- Log + Memory: just confirm they hold rows.
-- ============================================================
SELECT count() AS audit_rows  FROM m2.audit_log;
SELECT count() AS memory_rows FROM m2.tmp_uploads;

-- ============================================================
-- Buffer: rows are in RAM until thresholds or FLUSH.
-- ============================================================
SELECT count() AS buffer_rows  FROM m2.facts_buffer;
SELECT count() AS dest_rows    FROM m2.facts_dest;
SYSTEM FLUSH DISTRIBUTED m2.facts_buffer; -- harmless if not distributed
OPTIMIZE TABLE m2.facts_buffer;
SELECT count() AS buffer_after FROM m2.facts_buffer;
SELECT count() AS dest_after   FROM m2.facts_dest;
