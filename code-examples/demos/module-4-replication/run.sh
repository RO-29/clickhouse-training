#!/usr/bin/env bash
# Module 4 — Replication. Cluster.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for cluster nodes"
ch_wait_cluster

echo "==> setup.sql"
ch_node s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (insert 2M rows into s1r1's sensor_local)"
ch_node s1r1 "$(<"$HERE/data.sql")"

# Let replication catch up.
echo "==> SYSTEM SYNC REPLICA on s1r2"
ch_node s1r2 "SYSTEM SYNC REPLICA sensor_local" || true

echo "==> queries.sql"
ch_node s1r1 "$(<"$HERE/queries.sql")"

# === Failure drill: kill s1r2, insert more, restart, watch it catch up. ===
echo
echo "==> DRILL: stop s1r2, insert 500k more rows on s1r1, restart s1r2"
docker stop clickhouse-s1r2 >/dev/null

ch_node s1r1 "INSERT INTO sensor_local SELECT toDateTime('2026-05-02 00:00:00') + INTERVAL (number % 86400) SECOND, 1 + rand(number)%5000, arrayElement(['us','eu','ap'], 1 + toUInt8(rand(number+1)%3)), rand(number+2)/4294967295.0*100 FROM numbers(500000)"

echo "  rows on s1r1 (before restart):"
ch_node s1r1 "SELECT count() FROM sensor_local"

echo "==> docker start clickhouse-s1r2"
docker start clickhouse-s1r2 >/dev/null

# Give it a moment to come back, then sync.
sleep 5
ch_node s1r2 "SYSTEM SYNC REPLICA sensor_local"

echo "  rows on s1r2 (after sync):"
ch_node s1r2 "SELECT count() FROM sensor_local"

echo "  replication state across replicas:"
ch_node s1r1 "SELECT replica_name, queue_size, absolute_delay FROM system.replicas WHERE table='sensor_local'"

cat <<EOF

✓ Module 4 demo complete. s1r2 caught up after restart.
EOF
