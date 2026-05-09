#!/usr/bin/env bash
# Module 1 — Fundamentals.  ./up.sh first (or this script will call it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ch() { docker exec -i m1-clickhouse clickhouse-client --multiquery --query "$1"; }

# Self-bootstrap: bring stack up if it's not already.
if ! docker exec m1-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch "$(<"$HERE/setup.sql")"

echo "==> data.sql (~2M rows in 3 inserts)"
ch "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 1 demo complete.

Stack still running. Tear down with:  ./down.sh
Interactive client:                   docker exec -it m1-clickhouse clickhouse-client
EOF
