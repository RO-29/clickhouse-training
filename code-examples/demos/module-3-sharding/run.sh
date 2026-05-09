#!/usr/bin/env bash
# Module 3 — Sharding.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ch_node() { local n="$1"; shift; docker exec -i "$n" clickhouse-client --multiquery --query "$1"; }

if ! docker exec m3-s1r1 wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql (ON CLUSTER DDL via m3-s1r1)"
ch_node m3-s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (5M rows via Distributed on m3-s1r1)"
ch_node m3-s1r1 "$(<"$HERE/data.sql")"

echo "==> SYSTEM FLUSH DISTRIBUTED on every node"
for n in m3-s1r1 m3-s1r2 m3-s2r1 m3-s2r2 m3-s3r1 m3-s3r2; do
    ch_node "$n" "SYSTEM FLUSH DISTRIBUTED hits_distributed" || true
done

echo "==> queries.sql"
ch_node m3-s1r1 "$(<"$HERE/queries.sql")"

echo "==> extras.sql (weighted shards + alternative sharding keys)"
ch_node m3-s1r1 "$(<"$HERE/extras.sql")"

cat <<EOF

✓ Module 3 demo complete.

Stack still running. Tear down with:  ./down.sh
Interactive client:                   docker exec -it m3-s1r1 clickhouse-client
EOF
