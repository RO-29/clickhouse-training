-- S3 (MinIO) backup demo. The MinIO service is reachable inside the m7-net
-- network at http://m7-minio:9000. Bucket 'clickhouse-backups' is created
-- automatically by the m7-minio-init container.
--
-- Console: http://localhost:9101  (minioadmin / minioadmin)

BACKUP TABLE m7.transactions
TO S3('http://m7-minio:9000/clickhouse-backups/transactions_s3_v1', 'minioadmin', 'minioadmin');

SELECT id, name, status, total_size FROM system.backups
WHERE name LIKE '%transactions_s3_v1%' ORDER BY start_time DESC LIMIT 1;

DROP TABLE m7.transactions;

RESTORE TABLE m7.transactions
FROM S3('http://m7-minio:9000/clickhouse-backups/transactions_s3_v1', 'minioadmin', 'minioadmin');

SELECT count() AS rows_restored_from_s3 FROM m7.transactions;
