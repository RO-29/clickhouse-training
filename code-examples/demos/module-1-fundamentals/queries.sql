-- Module 1 demo queries. Read top-down — each one tells you something the next
-- builds on.

-- 1. row count
SELECT count() AS rows FROM m1.events;

-- 2. parts on disk: one row per active part. After 3 inserts you'll typically
--    see 3+ active parts before background merges collapse them.
SELECT
    partition,
    name,
    rows,
    formatReadableSize(bytes_on_disk) AS size,
    marks,
    level,
    active
FROM system.parts
WHERE database = 'm1' AND table = 'events'
ORDER BY active DESC, name;

-- 3. partitions and their sizes
SELECT
    partition,
    sum(rows)                                AS rows,
    formatReadableSize(sum(bytes_on_disk))   AS size,
    count()                                  AS parts
FROM system.parts
WHERE database = 'm1' AND table = 'events' AND active
GROUP BY partition
ORDER BY partition;

-- 4. MergeTree primary key vs sorting key. ORDER BY (event_time, user_id) means
--    both are the primary key here.
SELECT name, primary_key, sorting_key, partition_key
FROM system.tables WHERE database = 'm1' AND name = 'events';

-- 5. force a merge so you can see parts collapse
OPTIMIZE TABLE m1.events FINAL;

-- 6. recheck parts after merge — fewer active parts, larger rows count per part
SELECT count() AS active_parts, sum(rows) AS rows
FROM system.parts WHERE database='m1' AND table='events' AND active;

-- 7. a typical analytical query — uses primary key prefix (event_time)
SELECT
    toDate(event_time) AS day,
    count()            AS events,
    countIf(event_type = 'purchase') AS purchases,
    sum(revenue)       AS revenue
FROM m1.events
WHERE event_time BETWEEN '2026-02-01' AND '2026-02-28 23:59:59'
GROUP BY day
ORDER BY day;

-- 8. how many granules / rows actually got read? Use FORMAT JSON for stats,
--    or look at system.query_log. The log table is created lazily on the
--    first periodic flush (~7s); force it now so the SELECT can find rows.
SYSTEM FLUSH LOGS;
SELECT
    query_duration_ms,
    read_rows,
    read_bytes,
    result_rows
FROM system.query_log
WHERE event_time > now() - 60 AND type = 'QueryFinish' AND query LIKE '%purchase%'
ORDER BY event_time DESC LIMIT 3;
