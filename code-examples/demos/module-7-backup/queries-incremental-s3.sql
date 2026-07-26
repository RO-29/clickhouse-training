-- ============================================================================
-- Incremental backup to S3/MinIO with SETTINGS base_backup.
--
-- The point of this file: prove that an incremental writes ONLY the new parts,
-- that a restore walks the chain back to the base by itself, and that the
-- chain is a hard dependency — losing the base loses everything after it.
--
-- Numbers in the comments are what this produces when run via ./run.sh, i.e.
-- after extras.sql has already added a 50k-row 202607 partition. Running this
-- file on its own against a fresh setup.sql gives the same shape, smaller
-- counts (51/47 and 63/10 instead of 62/55 and 74/9).
-- ============================================================================

-- ============================================================
-- 1. The BASE (a normal full backup — nothing special about it).
-- ============================================================
BACKUP TABLE m7.transactions
TO S3('http://m7-minio:9000/clickhouse-backups/txn_inc_base', 'minioadmin', 'minioadmin');

-- ============================================================
-- 2. New data lands. A fresh month = a fresh part; the January
--    parts on disk are not touched.
-- ============================================================
INSERT INTO m7.transactions
SELECT
    number + 2000000,
    toDateTime('2026-02-15 00:00:00') + INTERVAL (number % 86400) SECOND,
    1 + (rand(number) % 50000),
    toDecimal64(rand(number+1) % 100000 / 100.0, 2),
    arrayElement(['USD','EUR','INR','JPY'],   1 + toUInt8(rand(number+2) % 4)),
    arrayElement(['ok','pending','reversed'], 1 + toUInt8(rand(number+3) % 3))
FROM numbers(200000);

SELECT partition, count() AS parts, sum(rows) AS rows,
       formatReadableSize(sum(bytes_on_disk)) AS size
FROM system.parts
WHERE database='m7' AND table='transactions' AND active
GROUP BY partition ORDER BY partition;
--   202601 | 2 parts | 2,000,000 | 26.98 MiB   <- already in the base
--   202602 | 1 part  |   200,000 |  2.83 MiB   <- new, will be the increment
--   202607 | 1 part  |    50,000 | 723.55 KiB  <- already in the base (from extras.sql)

-- ============================================================
-- 3. The INCREMENTAL. Same syntax as a full backup plus one setting.
--    base_backup must spell out the FULL destination — endpoint,
--    credentials and all. It is not a name lookup.
-- ============================================================
BACKUP TABLE m7.transactions
TO S3('http://m7-minio:9000/clickhouse-backups/txn_inc_v2', 'minioadmin', 'minioadmin')
SETTINGS base_backup = S3('http://m7-minio:9000/clickhouse-backups/txn_inc_base', 'minioadmin', 'minioadmin');

-- ============================================================
-- 4. Read the result. The column pair that matters is
--    num_files vs num_entries:
--      num_files   = files the backup logically CONTAINS (whole dataset)
--      num_entries = files this backup actually STORED
--    ...and total_size vs compressed_size, same idea in bytes.
-- ============================================================
SELECT
    extract(name, 'clickhouse-backups/([a-z0-9_]+)') AS backup,
    if(base_backup_name = '', '—',
       extract(base_backup_name, 'clickhouse-backups/([a-z0-9_]+)')) AS base,
    status,
    num_files,
    num_entries,
    formatReadableSize(total_size)      AS logical_size,
    formatReadableSize(compressed_size) AS actually_written
FROM system.backups
WHERE name LIKE '%txn_inc%'
ORDER BY start_time;
--   backup       | base         | num_files | num_entries | logical  | written
--   txn_inc_base | —            |        62 |          55 | 27.69MiB | 27.70MiB
--   txn_inc_v2   | txn_inc_base |        74 |           9 | 30.52MiB |  2.84MiB
--
-- 74 files visible, 9 written. That is the whole story.

-- ============================================================
-- 5. RESTORE. Point at the INCREMENTAL, not the base. ClickHouse reads
--    its .backup manifest, sees base_backup_name, and fetches the
--    missing parts from the base automatically.
-- ============================================================
DROP TABLE m7.transactions;

RESTORE TABLE m7.transactions
FROM S3('http://m7-minio:9000/clickhouse-backups/txn_inc_v2', 'minioadmin', 'minioadmin');

SELECT count() AS rows_restored FROM m7.transactions;   -- 2,250,000

SELECT partition, sum(rows) AS rows
FROM system.parts
WHERE database='m7' AND table='transactions' AND active
GROUP BY partition ORDER BY partition;
--   202601 | 2,000,000   <- came from the BASE
--   202602 |   200,000   <- came from the INCREMENTAL
--   202607 |    50,000   <- came from the BASE

-- ============================================================
-- 6. What is physically in the bucket. Run on the host:
--
--   docker run --rm --network module-7-backup_m7-net --entrypoint sh \
--     minio/mc:latest -c "mc alias set local http://m7-minio:9000 \
--     minioadmin minioadmin >/dev/null && \
--     mc du local/clickhouse-backups/txn_inc_base && \
--     mc du local/clickhouse-backups/txn_inc_v2 && \
--     mc ls local/clickhouse-backups/txn_inc_v2/data/m7/transactions/"
--
--   28MiB   56 objects   clickhouse-backups/txn_inc_base
--   2.8MiB  10 objects   clickhouse-backups/txn_inc_v2
--   202602_4_4_0/        <- the incremental holds ONE part directory
--
-- (the base holds 202601_1_1_0, 202601_2_2_0 and 202607_3_3_0)
--
-- Dedup is at PART granularity, not row or file granularity. This is why
-- partitioned append-only tables incremental beautifully, and why a table
-- that rewrites parts (heavy merges, mutations, a re-INSERTed partition)
-- can produce an "incremental" nearly as large as a full.
-- ============================================================

-- ============================================================
-- 7. The chain is a HARD dependency. Deleting a base orphans every
--    incremental built on it:
--
--     Code: 599. DB::Exception: Backup S3('.../txn_inc_base', ...)
--                not found. (BACKUP_NOT_FOUND)
--
-- There is no partial recovery and no warning at delete time — the bucket
-- lets you remove the base happily. Any retention policy MUST expire a base
-- and its dependants together, or start a new full before expiring the old.
-- This is the single most common way teams discover their backups are
-- worthless, and it is the strongest argument for the retention handling in
-- clickhouse-backup (see backup-tool.sh) over a hand-rolled cron job.
-- ============================================================
