#!/usr/bin/env bash
# Module 8 — Disaster recovery drills.
# Each drill is independent. Comment out drills you don't want.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for cluster nodes"
ch_wait_cluster

echo "==> setup.sql"
ch_node s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (1M rows)"
ch_node s1r1 "$(<"$HERE/data.sql")"
for n in s1r1 s1r2 s2r1 s2r2 s3r1 s3r2; do
    ch_node "$n" "SYSTEM FLUSH DISTRIBUTED dr_distributed" || true
done

baseline=$(ch_node s1r1 "SELECT count() FROM dr_distributed")
echo "  baseline rows (via Distributed on s1r1): $baseline"

echo
echo "============================================================"
echo "DRILL 1 — Replica failure (kill clickhouse-s1r2)."
echo "============================================================"
docker stop clickhouse-s1r2 >/dev/null
echo "  cluster sees one bad replica:"
ch_node s1r1 "SELECT host_name, errors_count FROM system.clusters WHERE cluster='clickhouse_cluster' ORDER BY shard_num, replica_num"
echo "  reads still work via the surviving replica:"
ch_node s1r1 "SELECT count() FROM dr_distributed"
echo "  inserts also work (routed to s1r1, replicated later):"
ch_node s1r1 "INSERT INTO dr_local VALUES (now(), 999999999, 'during_outage_1')"
ch_node s1r1 "INSERT INTO dr_local VALUES (now(), 999999998, 'during_outage_2')"

echo "  bring s1r2 back; SYSTEM SYNC REPLICA reconciles."
docker start clickhouse-s1r2 >/dev/null
sleep 5
ch_node s1r2 "SYSTEM SYNC REPLICA dr_local"
echo "  s1r2 caught up — its row count for the during-outage keys:"
ch_node s1r2 "SELECT count() FROM dr_local WHERE key >= 999999998"

echo
echo "============================================================"
echo "DRILL 2 — Whole shard outage (kill BOTH s2r1 and s2r2)."
echo "============================================================"
docker stop clickhouse-s2r1 clickhouse-s2r2 >/dev/null
echo "  Distributed query with skip_unavailable_shards = 1 returns partial results:"
ch_node s1r1 "SELECT count() FROM dr_distributed SETTINGS skip_unavailable_shards = 1"
echo "  Distributed query without that setting fails:"
ch_node s1r1 "SELECT count() FROM dr_distributed" || echo "    (expected: query failed because shard 2 is gone)"

docker start clickhouse-s2r1 clickhouse-s2r2 >/dev/null
sleep 5
ch_node s2r1 "SYSTEM SYNC REPLICA dr_local" || true
ch_node s2r2 "SYSTEM SYNC REPLICA dr_local" || true
echo "  shard 2 back. count via Distributed on s1r1:"
ch_node s1r1 "SELECT count() FROM dr_distributed"

echo
echo "============================================================"
echo "DRILL 3 — Lose ZooKeeper-1, verify the cluster keeps working."
echo "============================================================"
docker stop zookeeper-1 >/dev/null
echo "  ZK ensemble is 2/3 — quorum still holds. Inserts/reads keep working:"
ch_node s3r1 "INSERT INTO dr_local VALUES (now(), 1, 'zk1_down')"
ch_node s3r1 "SELECT count() FROM dr_local WHERE payload = 'zk1_down'"

docker start zookeeper-1 >/dev/null
sleep 5

echo
echo "============================================================"
echo "DRILL 4 — Forcefully wipe one replica's data dir; rebuild from peer."
echo "  This simulates 'I lost the disk on s1r2'."
echo "============================================================"
docker stop clickhouse-s1r2 >/dev/null
echo "  wiping s1r2 data volume contents..."
docker run --rm --volumes-from clickhouse-s1r2 alpine \
    sh -c "rm -rf /var/lib/clickhouse/data/* /var/lib/clickhouse/metadata/* /var/lib/clickhouse/store/* 2>/dev/null || true"

docker start clickhouse-s1r2 >/dev/null
echo "  give the server a moment, then drop ZK pointer + recreate the table."
sleep 8

# After a wipe, the ReplicatedMergeTree pointer on the replica is gone but ZK
# still holds the old replica id. The textbook recovery is:
#   1. SYSTEM DROP REPLICA on a peer
#   2. CREATE TABLE again (it'll re-attach as an empty replica and pull data)
ch_node s1r1 "SYSTEM DROP REPLICA 'clickhouse-s1r2' FROM TABLE dr_local" || true
ch_node s1r2 "DROP TABLE IF EXISTS dr_local SYNC" || true

# Recreate just on s1r2 (no ON CLUSTER, since the table still exists everywhere else)
ch_node s1r2 "CREATE TABLE dr_local
(
    ts DateTime, key UInt64, payload String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/01/dr_local', 'clickhouse-s1r2')
PARTITION BY toYYYYMMDD(ts)
ORDER BY (key, ts)"

ch_node s1r2 "SYSTEM SYNC REPLICA dr_local"
echo "  s1r2 rebuilt from peer:"
ch_node s1r2 "SELECT count() FROM dr_local"

cat <<EOF

✓ Module 8 disaster-recovery drills complete.

Summary:
  • Drill 1: single replica down → reads/writes continue, sync on return.
  • Drill 2: whole shard down → skip_unavailable_shards keeps reads partial.
  • Drill 3: ZK node down → quorum preserved (2/3), no impact.
  • Drill 4: replica disk loss → SYSTEM DROP REPLICA + CREATE TABLE rebuilds.
EOF
