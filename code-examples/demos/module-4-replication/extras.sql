SET async_insert = 0;  -- VALUES + --multiquery clashes with async_insert defaults on CH 26.x

-- Module 4 extras: replication consistency settings and DROP REPLICA.

-- ============================================================
-- 1. insert_quorum — block the INSERT until N replicas have applied it.
--    Combine with insert_quorum_timeout (default 600000ms).
-- ============================================================
SET insert_quorum         = 2;          -- both replicas of a shard must ack
SET insert_quorum_timeout = 5000;       -- otherwise fail in 5s

INSERT INTO sensor_local VALUES
    (now(), 1, 'us', 1.23),
    (now(), 1, 'eu', 4.56);

SELECT '-- insert_quorum=2 succeeded with both replicas alive --';
SELECT count() FROM sensor_local;

-- Show the recorded quorum metadata in ZK.
SELECT name FROM system.zookeeper
WHERE path = '/clickhouse/tables/01/sensor_local'
ORDER BY name;

-- ============================================================
-- 2. select_sequential_consistency — read only "what the quorum has seen".
--    Combine with insert_quorum to get linearisable reads.
-- ============================================================
SET select_sequential_consistency = 1;
SELECT count() AS rows_via_seq_consistent FROM sensor_local;
SET select_sequential_consistency = 0;        -- restore default

-- ============================================================
-- 3. SYSTEM DROP REPLICA — clean up a dead replica's pointer in ZK.
--    (Read-only here; the actual destructive call is exercised in M8.)
--    The list shows what `SYSTEM DROP REPLICA` would target.
-- ============================================================
SELECT
    database,
    table,
    replica_name,
    is_readonly,
    is_session_expired,
    queue_size,
    absolute_delay
FROM system.replicas
WHERE table = 'sensor_local'
ORDER BY replica_name;

-- ============================================================
-- 4. ClickHouse Keeper note (no DDL here, just doc).
--    Keeper is a Raft-based, drop-in ZK replacement, single binary,
--    same client protocol. To migrate from ZK to Keeper: stop writes,
--    snapshot ZK, import via clickhouse-keeper-converter, swap configs.
--    No table changes required — replication paths stay the same.
-- ============================================================
SELECT 'Tip: replace zookeeper-* with clickhouse-keeper for self-hosted Raft.';
