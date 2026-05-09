-- Verify cluster topology
SELECT cluster, shard_num, replica_num, host_name, port
FROM system.clusters WHERE cluster = 'clickhouse_cluster' ORDER BY shard_num, replica_num;

-- Total rows via distributed table (should be 5M)
SELECT count() AS total FROM hits_distributed;

-- Per-shard row count (use clusterAllReplicas to call every node).
SELECT hostName() AS host, shardNum() AS shard, count() AS rows
FROM clusterAllReplicas('clickhouse_cluster', default, hits_local)
GROUP BY host, shard ORDER BY shard, host;

-- Same view rolled up to one row per shard. Should be ~5M/3 ≈ 1.67M each.
SELECT shardNum() AS shard, count() AS rows
FROM clusterAllReplicas('clickhouse_cluster', default, hits_local)
GROUP BY shard ORDER BY shard;

-- Verify both replicas of one shard hold the same rows.
SELECT hostName() AS host, count() AS rows, sum(bytes) AS bytes
FROM clusterAllReplicas('clickhouse_cluster', default, hits_local)
WHERE shardNum() = 1
GROUP BY host;

-- An aggregation pushed down to shards then merged on the initiator.
SELECT country, count() AS hits, sum(bytes) AS total_bytes
FROM hits_distributed
GROUP BY country ORDER BY hits DESC;

-- Show how a query plan handles a distributed table.
EXPLAIN SELECT count() FROM hits_distributed WHERE user_id = 42;

-- All-events-for-one-user hits a single shard because the sharding key is
-- cityHash64(user_id). Watch the query plan: only one shard scans data.
SELECT user_id, count(), max(event_time) FROM hits_distributed
WHERE user_id = 42 GROUP BY user_id;
