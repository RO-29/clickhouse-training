-- ====================================================================
-- All queries return the same answer; what changes is what gets read.
-- Look at: query_duration_ms, read_rows, read_bytes in system.query_log.
-- ====================================================================

-- Q1: time range — which layout reads fewest rows?
SELECT 'BAD',  count() FROM m6.events_bad  WHERE event_time BETWEEN '2026-02-01' AND '2026-02-07';
SELECT 'GOOD', count() FROM m6.events_good WHERE event_time BETWEEN '2026-02-01' AND '2026-02-07';
SELECT 'PROJ', count() FROM m6.events_proj WHERE event_time BETWEEN '2026-02-01' AND '2026-02-07';

-- Q2: country aggregation — projection should crush this.
SELECT 'BAD',  country, count() FROM m6.events_bad
WHERE event_time BETWEEN '2026-02-01' AND '2026-02-28' GROUP BY country ORDER BY country;

SELECT 'GOOD', country, count() FROM m6.events_good
WHERE event_time BETWEEN '2026-02-01' AND '2026-02-28' GROUP BY country ORDER BY country;

SELECT 'PROJ', country, count() FROM m6.events_proj
WHERE event_time BETWEEN '2026-02-01' AND '2026-02-28' GROUP BY country ORDER BY country
SETTINGS optimize_use_projections = 1;

-- Q3: point lookup by user_id — bloom filter skip-index on PROJ should help.
SELECT 'BAD',  count() FROM m6.events_bad  WHERE user_id = 12345;
SELECT 'GOOD', count() FROM m6.events_good WHERE user_id = 12345;
SELECT 'PROJ', count() FROM m6.events_proj WHERE user_id = 12345;

-- Q4: see what each plan does
EXPLAIN indexes = 1
SELECT count() FROM m6.events_proj WHERE user_id = 12345;

EXPLAIN PROJECTION = 1
SELECT country, count() FROM m6.events_proj
WHERE event_time BETWEEN '2026-02-01' AND '2026-02-28' GROUP BY country
SETTINGS optimize_use_projections = 1;

-- Q5: get the actual measurements out of the log.
-- query_log is created lazily; flush so the SELECT finds the rows we just wrote.
SYSTEM FLUSH LOGS;
SELECT
    substring(query, 1, 80)   AS q,
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) AS read_bytes,
    formatReadableSize(memory_usage) AS mem
FROM system.query_log
WHERE event_time > now() - 600
  AND type = 'QueryFinish'
  AND query LIKE '%m6.%'
ORDER BY event_time DESC LIMIT 30;
