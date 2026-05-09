-- Module 5: cluster deployment patterns.
-- 1. ON CLUSTER DDL
-- 2. distributed_ddl_queue (the audit trail of cluster DDL)
-- 3. remote() / cluster() / clusterAllReplicas() table functions

CREATE DATABASE IF NOT EXISTS analytics ON CLUSTER clickhouse_cluster;

DROP TABLE IF EXISTS analytics.page_views_local      ON CLUSTER clickhouse_cluster SYNC;
DROP TABLE IF EXISTS analytics.page_views_distributed ON CLUSTER clickhouse_cluster SYNC;

CREATE TABLE analytics.page_views_local ON CLUSTER clickhouse_cluster
(
    ts          DateTime,
    user_id     UInt64,
    page        LowCardinality(String),
    referrer    LowCardinality(String),
    duration_ms UInt32
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/page_views_local',
    '{replica}'
)
PARTITION BY toYYYYMM(ts)
ORDER BY (page, user_id, ts);

CREATE TABLE analytics.page_views_distributed ON CLUSTER clickhouse_cluster
AS analytics.page_views_local
ENGINE = Distributed('clickhouse_cluster', analytics, page_views_local, cityHash64(user_id));
