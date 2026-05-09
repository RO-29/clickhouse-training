-- Module 4: replication. We use a single shard worth of replicas (s1r1, s1r2)
-- and watch ZooKeeper paths, queue, and lag during insert + recovery.

DROP TABLE IF EXISTS sensor_local ON CLUSTER clickhouse_cluster SYNC;

CREATE TABLE sensor_local ON CLUSTER clickhouse_cluster
(
    ts        DateTime,
    sensor_id UInt32,
    region    LowCardinality(String),
    value     Float32
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/sensor_local',
    '{replica}'
)
PARTITION BY toYYYYMMDD(ts)
ORDER BY (sensor_id, ts);

DROP TABLE IF EXISTS sensor_distributed ON CLUSTER clickhouse_cluster SYNC;
CREATE TABLE sensor_distributed ON CLUSTER clickhouse_cluster AS sensor_local
ENGINE = Distributed('clickhouse_cluster', default, sensor_local, cityHash64(sensor_id));
