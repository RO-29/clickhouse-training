-- Module 8: disaster recovery drills.
-- Same shape as module 4, but we'll keep it small and run multiple failures.

DROP TABLE IF EXISTS dr_local        ON CLUSTER clickhouse_cluster SYNC;
DROP TABLE IF EXISTS dr_distributed  ON CLUSTER clickhouse_cluster SYNC;

CREATE TABLE dr_local ON CLUSTER clickhouse_cluster
(
    ts        DateTime,
    key       UInt64,
    payload   String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/dr_local', '{replica}')
PARTITION BY toYYYYMMDD(ts)
ORDER BY (key, ts);

CREATE TABLE dr_distributed ON CLUSTER clickhouse_cluster AS dr_local
ENGINE = Distributed('clickhouse_cluster', default, dr_local, cityHash64(key));
