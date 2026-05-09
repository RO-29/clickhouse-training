#!/usr/bin/env bash
# Module 6 — Query optimization. Standalone single node.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch() { docker exec -i m6-clickhouse clickhouse-client --multiquery --query "$1"; }

if ! docker exec m6-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch "$(<"$HERE/setup.sql")"

echo "==> data.sql (60M total inserts; ~30–60s on a laptop)"
time ch "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch "$(<"$HERE/queries.sql")"

echo "==> extras.sql (PREWHERE, SAMPLE, more skip indexes, JOINs, MV)"
ch "$(<"$HERE/extras.sql")"

cat <<EOF

✓ Module 6 demo complete.

Compare read_rows / query_duration_ms across BAD / GOOD / PROJ in Q5 output.

Stack still running. Tear down with:  ./down.sh
EOF
