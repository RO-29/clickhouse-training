-- Module 3: sharding. Cluster name in cluster-node.xml is `clickhouse_cluster`,
-- topology is 3 shards × 2 replicas.
--
-- We create:
--   * a local ReplicatedMergeTree on every node      (the shard storage)
--   * a Distributed table on every node              (the fan-out)
-- ON CLUSTER does both in one statement.

DROP TABLE IF EXISTS hits_local      ON CLUSTER clickhouse_cluster SYNC;
DROP TABLE IF EXISTS hits_distributed ON CLUSTER clickhouse_cluster SYNC;

CREATE TABLE hits_local ON CLUSTER clickhouse_cluster
(
    event_time DateTime,
    user_id    UInt64,
    country    LowCardinality(String),
    url        String,
    bytes      UInt32
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/hits_local', '{replica}')
PARTITION BY toYYYYMM(event_time)
ORDER BY (user_id, event_time);

-- Sharding key: cityHash64(user_id) → all events for one user land on one shard.
-- internal_replication = true because the local table is *already* replicated.
CREATE TABLE hits_distributed ON CLUSTER clickhouse_cluster
AS hits_local
ENGINE = Distributed('clickhouse_cluster', default, hits_local, cityHash64(user_id));
