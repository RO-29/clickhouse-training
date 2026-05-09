-- S3 (MinIO) backup demo. Requires MinIO sidecar attached to the same docker
-- network as clickhouse-single (run.sh handles this).
--
-- Endpoint:  http://minio:9000
-- Bucket:    clickhouse-backups
-- Creds:     minioadmin / minioadmin

-- BACKUP TO S3
BACKUP TABLE m7.transactions
TO S3('http://minio:9000/clickhouse-backups/transactions_s3_v1', 'minioadmin', 'minioadmin');

-- Verify the manifest landed in MinIO (visible via console at http://localhost:9101)
SELECT id, name, status, total_size FROM system.backups
WHERE name LIKE '%transactions_s3_v1%' ORDER BY start_time DESC LIMIT 1;

-- Drop and restore from S3
DROP TABLE m7.transactions;
RESTORE TABLE m7.transactions
FROM S3('http://minio:9000/clickhouse-backups/transactions_s3_v1', 'minioadmin', 'minioadmin');

SELECT count() AS rows_restored_from_s3 FROM m7.transactions;
