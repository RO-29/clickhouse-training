#!/usr/bin/env bash
# Module 8 — Disaster recovery drills. Standalone cluster (m8-).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch_node() { local n="$1"; docker exec -i "$n" clickhouse-client --multiquery --query "$2"; }

if ! docker exec m8-s1r1 wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch_node m8-s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (1M rows)"
ch_node m8-s1r1 "$(<"$HERE/data.sql")"
for n in m8-s1r1 m8-s1r2 m8-s2r1 m8-s2r2 m8-s3r1 m8-s3r2; do
    ch_node "$n" "SYSTEM FLUSH DISTRIBUTED dr_distributed" || true
done

baseline=$(ch_node m8-s1r1 "SELECT count() FROM dr_distributed")
echo "  baseline rows (via Distributed on m8-s1r1): $baseline"

echo
echo "============================================================"
echo "DRILL 1 — Replica failure (kill m8-s1r2)."
echo "============================================================"
docker stop m8-s1r2 >/dev/null
echo "  cluster sees one bad replica:"
ch_node m8-s1r1 "SELECT host_name, errors_count FROM system.clusters WHERE cluster='clickhouse_cluster' ORDER BY shard_num, replica_num"
echo "  reads still work via the surviving replica:"
ch_node m8-s1r1 "SELECT count() FROM dr_distributed"
echo "  inserts also work (routed to m8-s1r1, replicated later):"
ch_node m8-s1r1 "INSERT INTO dr_local VALUES (now(), 999999999, 'during_outage_1')"
ch_node m8-s1r1 "INSERT INTO dr_local VALUES (now(), 999999998, 'during_outage_2')"

echo "  bring m8-s1r2 back; SYSTEM SYNC REPLICA reconciles."
docker start m8-s1r2 >/dev/null
sleep 5
ch_node m8-s1r2 "SYSTEM SYNC REPLICA dr_local"
echo "  m8-s1r2 caught up:"
ch_node m8-s1r2 "SELECT count() FROM dr_local WHERE key >= 999999998"

echo
echo "============================================================"
echo "DRILL 2 — Whole shard outage (kill BOTH m8-s2r1 and m8-s2r2)."
echo "============================================================"
docker stop m8-s2r1 m8-s2r2 >/dev/null
echo "  Distributed query with skip_unavailable_shards = 1 returns partial results:"
ch_node m8-s1r1 "SELECT count() FROM dr_distributed SETTINGS skip_unavailable_shards = 1"
echo "  Distributed query without that setting fails:"
ch_node m8-s1r1 "SELECT count() FROM dr_distributed" || echo "    (expected: query failed because shard 2 is gone)"

docker start m8-s2r1 m8-s2r2 >/dev/null
sleep 5
ch_node m8-s2r1 "SYSTEM SYNC REPLICA dr_local" || true
ch_node m8-s2r2 "SYSTEM SYNC REPLICA dr_local" || true
echo "  shard 2 back. count via Distributed on m8-s1r1:"
ch_node m8-s1r1 "SELECT count() FROM dr_distributed"

echo
echo "============================================================"
echo "DRILL 3 — Lose ZooKeeper-1, verify the cluster keeps working."
echo "============================================================"
docker stop m8-zk1 >/dev/null
echo "  ZK ensemble is 2/3 — quorum still holds. Inserts/reads continue:"
ch_node m8-s3r1 "INSERT INTO dr_local VALUES (now(), 1, 'zk1_down')"
ch_node m8-s3r1 "SELECT count() FROM dr_local WHERE payload = 'zk1_down'"
docker start m8-zk1 >/dev/null
sleep 5

echo
echo "============================================================"
echo "DRILL 4 — Wipe replica's data dir; rebuild from peer."
echo "============================================================"
docker stop m8-s1r2 >/dev/null
echo "  wiping m8-s1r2 data volume contents..."
docker run --rm --volumes-from m8-s1r2 alpine \
    sh -c "rm -rf /var/lib/clickhouse/data/* /var/lib/clickhouse/metadata/* /var/lib/clickhouse/store/* 2>/dev/null || true"

docker start m8-s1r2 >/dev/null
sleep 8

ch_node m8-s1r1 "SYSTEM DROP REPLICA 'm8-s1r2' FROM TABLE dr_local" || true
ch_node m8-s1r2 "DROP TABLE IF EXISTS dr_local SYNC" || true

ch_node m8-s1r2 "CREATE TABLE dr_local
(
    ts DateTime, key UInt64, payload String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/01/dr_local', 'm8-s1r2')
PARTITION BY toYYYYMMDD(ts)
ORDER BY (key, ts)"

ch_node m8-s1r2 "SYSTEM SYNC REPLICA dr_local"
echo "  m8-s1r2 rebuilt from peer:"
ch_node m8-s1r2 "SELECT count() FROM dr_local"

cat <<EOF

✓ Module 8 disaster-recovery drills complete.

Stack still running. Tear down with:  ./down.sh
EOF
