-- 1. ON CLUSTER DDL audit trail. Every CREATE/DROP we ran has a row.
SELECT entry, host_name, port, status, exception_text, query_create_time
FROM system.distributed_ddl_queue
ORDER BY query_create_time DESC LIMIT 10;

-- 2. cluster() table function: read from EVERY shard's local table
SELECT page, count() AS hits
FROM cluster('clickhouse_cluster', analytics, page_views_local)
GROUP BY page ORDER BY hits DESC;

-- 3. clusterAllReplicas() — like cluster() but hits both replicas of every shard.
--    Useful for replica-equivalence checks; NOT for aggregating data
--    (you'd double-count).
SELECT hostName() AS host, shardNum() AS shard, count() AS rows
FROM clusterAllReplicas('clickhouse_cluster', analytics, page_views_local)
GROUP BY host, shard ORDER BY shard, host;

-- 4. remote() — ad-hoc one-off; we point at a specific node.
SELECT count() FROM remote('clickhouse-s2r1:9000', analytics, page_views_local);

-- 5. Distributed query plan
EXPLAIN SELECT page, count() FROM analytics.page_views_distributed
WHERE ts >= '2026-04-15' GROUP BY page;

-- 6. Show that the cluster topology is what we think
SELECT cluster, shard_num, replica_num, host_name, errors_count
FROM system.clusters WHERE cluster = 'clickhouse_cluster' ORDER BY shard_num, replica_num;
