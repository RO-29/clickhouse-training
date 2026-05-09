-- ============================================================
-- 1. ALTER TABLE FREEZE: hardlink-snapshot of all parts (instant).
--    Lives in /var/lib/clickhouse/shadow/<N>/.
-- ============================================================
ALTER TABLE m7.transactions FREEZE WITH NAME 'demo_snap';

SELECT * FROM system.backups ORDER BY start_time DESC LIMIT 5;

-- ============================================================
-- 2. BACKUP TO disk (filesystem-style backup).
-- ============================================================
BACKUP TABLE m7.transactions TO Disk('backups', 'transactions_disk_v1.zip');

-- 3. Drop the table, then RESTORE.
SELECT count() AS before_drop FROM m7.transactions;
DROP TABLE m7.transactions;

RESTORE TABLE m7.transactions FROM Disk('backups', 'transactions_disk_v1.zip');
SELECT count() AS after_restore FROM m7.transactions;

-- ============================================================
-- 4. Partition operations: detach / attach / drop a single month.
-- ============================================================
SELECT partition, sum(rows) AS rows
FROM system.parts WHERE database='m7' AND table='transactions' AND active
GROUP BY partition ORDER BY partition;

ALTER TABLE m7.transactions DETACH PARTITION '202601';
SELECT count() AS after_detach FROM m7.transactions;

ALTER TABLE m7.transactions ATTACH PARTITION '202601';
SELECT count() AS after_attach FROM m7.transactions;

-- ============================================================
-- 5. List the freeze snapshot files (run on the host afterward):
--    docker exec clickhouse-single ls /var/lib/clickhouse/shadow/
-- ============================================================
