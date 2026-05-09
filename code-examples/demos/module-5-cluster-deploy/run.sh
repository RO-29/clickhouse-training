#!/usr/bin/env bash
# Module 5 — Cluster deployment patterns. Standalone cluster (m5-).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch_node() { local n="$1"; docker exec -i "$n" clickhouse-client --multiquery --query "$2"; }

if ! docker exec m5-s1r1 wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch_node m5-s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (3M rows via Distributed)"
ch_node m5-s1r1 "$(<"$HERE/data.sql")"

for n in m5-s1r1 m5-s1r2 m5-s2r1 m5-s2r2 m5-s3r1 m5-s3r2; do
    ch_node "$n" "SYSTEM FLUSH DISTRIBUTED analytics.page_views_distributed" || true
done

echo "==> queries.sql"
ch_node m5-s1r1 "$(<"$HERE/queries.sql")"

echo "==> extras.sql (roles, grants, quotas, Prometheus endpoint)"
ch_node m5-s1r1 "$(<"$HERE/extras.sql")"

echo "==> Prometheus endpoint smoke test (from inside m5-s1r1)"
docker exec m5-s1r1 wget -qO- http://localhost:9363/metrics 2>/dev/null \
    | head -5 || echo "  (endpoint not reachable — check 02-prometheus.xml mount)"

cat <<EOF

✓ Module 5 demo complete.

Stack still running. Tear down with:  ./down.sh
EOF
