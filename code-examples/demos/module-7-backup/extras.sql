-- Module 7 extras: incremental + async backup, plus PITR/clickhouse-backup
-- pointers (text-only).

-- ============================================================
-- 1. Async backup — returns immediately; poll system.backups.
-- ============================================================
BACKUP TABLE m7.transactions
TO Disk('backups', 'transactions_async_v1.zip')
SETTINGS async = 1;

-- The previous statement returns an id immediately. Wait for the row to
-- show up as BACKUP_CREATED.
SELECT id, name, status, total_size FROM system.backups
WHERE name LIKE '%transactions_async_v1%' ORDER BY start_time DESC LIMIT 1;

-- Tiny poll loop: in production you'd do this from your scheduler.
SELECT
    sleepEachRow(0.5),
    (SELECT status FROM system.backups
     WHERE name LIKE '%transactions_async_v1%' ORDER BY start_time DESC LIMIT 1)
FROM numbers(20)
WHERE (SELECT status FROM system.backups
       WHERE name LIKE '%transactions_async_v1%' ORDER BY start_time DESC LIMIT 1) != 'BACKUP_CREATED';

SELECT 'Async backup status:',
       (SELECT status FROM system.backups
        WHERE name LIKE '%transactions_async_v1%' ORDER BY start_time DESC LIMIT 1);

-- ============================================================
-- 2. Incremental backup — base_backup references a prior full backup.
--    Only changed parts are written.
-- ============================================================
INSERT INTO m7.transactions
SELECT
    2000000 + number,
    now() - INTERVAL (number % 86400) SECOND,
    1 + (rand(number) % 50000),
    toDecimal64(rand(number+1) % 100000 / 100.0, 2),
    'USD', 'ok'
FROM numbers(50000);

BACKUP TABLE m7.transactions
TO Disk('backups', 'transactions_inc_v2.zip')
SETTINGS base_backup = Disk('backups', 'transactions_disk_v1.zip');

SELECT id, name, status,
       formatReadableSize(total_size) AS total,
       formatReadableSize(uncompressed_size) AS uncompressed,
       num_files
FROM system.backups
WHERE name LIKE '%transactions_inc_v2%' ORDER BY start_time DESC LIMIT 1;

-- The incremental backup is much smaller than the full one because only
-- the new parts are written.
SELECT
    name,
    formatReadableSize(total_size) AS size,
    num_files
FROM system.backups
WHERE name LIKE '%transactions_disk_v1%' OR name LIKE '%transactions_inc_v2%'
ORDER BY start_time DESC LIMIT 5;

-- ============================================================
-- 3. RESTORE chain — to recover, point at the incremental and CH walks
--    back to the base automatically.
-- ============================================================
DROP TABLE m7.transactions;

RESTORE TABLE m7.transactions FROM Disk('backups', 'transactions_inc_v2.zip');

SELECT count() AS rows_after_inc_restore FROM m7.transactions;

-- ============================================================
-- 4. clickhouse-backup CLI (text-only).
--    Operationally this is the tool most teams use:
--      clickhouse-backup create   nightly-2026-05-09
--      clickhouse-backup upload   nightly-2026-05-09           # to S3
--      clickhouse-backup download nightly-2026-05-09
--      clickhouse-backup restore  nightly-2026-05-09
--    It wraps BACKUP/RESTORE plus a remote-storage manifest.
--    Repo: https://github.com/Altinity/clickhouse-backup
-- ============================================================

-- ============================================================
-- 5. BACKUP ON CLUSTER — for multi-host coordinated backups (cluster
--    modules 3/4/5/8). On this single-node demo, the syntax is just:
--      BACKUP TABLE x ON CLUSTER my_cluster TO Disk(...);
-- ============================================================
