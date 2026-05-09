#!/usr/bin/env bash
# Module 4 — Replication. Standalone cluster (m4-).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch_node() { local n="$1"; docker exec -i "$n" clickhouse-client --multiquery --query "$2"; }

if ! docker exec m4-s1r1 wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch_node m4-s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (insert 2M rows into m4-s1r1's sensor_local)"
ch_node m4-s1r1 "$(<"$HERE/data.sql")"

echo "==> SYSTEM SYNC REPLICA on m4-s1r2"
ch_node m4-s1r2 "SYSTEM SYNC REPLICA sensor_local" || true

echo "==> queries.sql"
ch_node m4-s1r1 "$(<"$HERE/queries.sql")"

# Failure drill: kill m4-s1r2, insert more, restart, verify catch-up.
echo
echo "==> DRILL: stop m4-s1r2, insert 500k more rows on m4-s1r1, restart"
docker stop m4-s1r2 >/dev/null

ch_node m4-s1r1 "INSERT INTO sensor_local SELECT toDateTime('2026-05-02 00:00:00') + INTERVAL (number % 86400) SECOND, 1 + rand(number)%5000, arrayElement(['us','eu','ap'], 1 + toUInt8(rand(number+1)%3)), rand(number+2)/4294967295.0*100 FROM numbers(500000)"

echo "  rows on m4-s1r1 (before restart):"
ch_node m4-s1r1 "SELECT count() FROM sensor_local"

echo "==> docker start m4-s1r2"
docker start m4-s1r2 >/dev/null
sleep 5
ch_node m4-s1r2 "SYSTEM SYNC REPLICA sensor_local"

echo "  rows on m4-s1r2 (after sync):"
ch_node m4-s1r2 "SELECT count() FROM sensor_local"

echo "  replication state:"
ch_node m4-s1r1 "SELECT replica_name, queue_size, absolute_delay FROM system.replicas WHERE table='sensor_local'"

cat <<EOF

✓ Module 4 demo complete. m4-s1r2 caught up after restart.

Stack still running. Tear down with:  ./down.sh
EOF
