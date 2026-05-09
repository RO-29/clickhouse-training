-- Replication metadata
SELECT database, table, replica_name, replica_path, is_leader,
       can_become_leader, absolute_delay, queue_size, log_pointer
FROM system.replicas
WHERE database = 'default' AND table = 'sensor_local'
ORDER BY replica_name;

-- Replication log entries (per-replica)
SELECT type, source_replica, parts_to_merge, new_part_name,
       create_time, last_attempt_time, last_exception
FROM system.replication_queue
WHERE database = 'default' AND table = 'sensor_local'
ORDER BY create_time
LIMIT 10;

-- ZooKeeper paths the table writes through
SELECT name, value, ctime, mtime FROM system.zookeeper
WHERE path = '/clickhouse/tables/01/sensor_local'
LIMIT 20;

-- Per-replica row count, byte count - should be identical between r1 and r2.
SELECT hostName() AS host, count() AS rows, sum(value) AS sum_value
FROM clusterAllReplicas('clickhouse_cluster', default, sensor_local)
WHERE shardNum() = 1
GROUP BY host;
