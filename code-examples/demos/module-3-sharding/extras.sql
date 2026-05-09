-- Module 3 extras: weighted shards, alternative sharding-key choices.

-- ============================================================
-- 1. Weighted shards.  cluster-node.xml defines a second cluster called
--    'weighted_cluster' with weights 1, 1, 4 — so shard 3 gets ~66% of
--    inserts via cityHash64(...) % 6.
-- ============================================================
DROP TABLE IF EXISTS hits_weighted_distributed ON CLUSTER clickhouse_cluster SYNC;
CREATE TABLE hits_weighted_distributed ON CLUSTER clickhouse_cluster
AS hits_local
ENGINE = Distributed('weighted_cluster', default, hits_local, cityHash64(user_id));

INSERT INTO hits_weighted_distributed
SELECT
    toDateTime('2026-04-01 00:00:00') + INTERVAL (number % 86400) SECOND,
    1 + (rand(number) % 250000),
    arrayElement(['US','IN','DE','BR'], 1 + toUInt8(rand(number+1) % 4)),
    concat('/u/', toString(rand(number+2) % 9999)),
    100 + rand(number+3) % 100000
FROM numbers(600000);

-- Distributed inserts are buffered briefly; flush so the count is exact.
SYSTEM FLUSH DISTRIBUTED hits_weighted_distributed;

SELECT '-- per-shard balance under weights 1,1,4 --';
SELECT shardNum() AS shard, count() AS rows
FROM clusterAllReplicas('weighted_cluster', default, hits_local)
GROUP BY shard ORDER BY shard;

-- ============================================================
-- 2. Alternative sharding keys.
--    rand()        — even split, but kills locality (no single-shard read).
--    intDiv(id, N) — range-style partitioning across shards.
--    xxHash64(k)   — typically lower collision than cityHash64.
-- ============================================================

-- 2a. rand() distributes evenly but no scoping. Avoid for analytical
--     workloads where you'd want WHERE user_id = X to land on one shard.
DROP TABLE IF EXISTS hits_dist_rand ON CLUSTER clickhouse_cluster SYNC;
CREATE TABLE hits_dist_rand ON CLUSTER clickhouse_cluster AS hits_local
ENGINE = Distributed('clickhouse_cluster', default, hits_local, rand());

-- 2b. intDiv() — every 100k user_ids land on the same shard. Range queries
--     on user_id stay shard-local.
DROP TABLE IF EXISTS hits_dist_range ON CLUSTER clickhouse_cluster SYNC;
CREATE TABLE hits_dist_range ON CLUSTER clickhouse_cluster AS hits_local
ENGINE = Distributed('clickhouse_cluster', default, hits_local,
                     intDiv(user_id, 100000));

-- 2c. xxHash64 — drop-in alternative to cityHash64.
DROP TABLE IF EXISTS hits_dist_xxh ON CLUSTER clickhouse_cluster SYNC;
CREATE TABLE hits_dist_xxh ON CLUSTER clickhouse_cluster AS hits_local
ENGINE = Distributed('clickhouse_cluster', default, hits_local,
                     xxHash64(user_id));

-- The four distributed tables all sit on top of the SAME hits_local data;
-- only the routing of new INSERTs differs. So you can EXPLAIN them to see
-- how the planner narrows the shard set.
EXPLAIN SELECT count() FROM hits_dist_range  WHERE user_id BETWEEN 10000 AND 20000;
EXPLAIN SELECT count() FROM hits_dist_xxh    WHERE user_id = 42;
EXPLAIN SELECT count() FROM hits_dist_rand   WHERE user_id = 42;
