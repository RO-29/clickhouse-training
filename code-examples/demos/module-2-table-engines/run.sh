#!/usr/bin/env bash
# Module 2 — Table engines tour.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch() { docker exec -i m2-clickhouse clickhouse-client --multiquery --query "$1"; }

if ! docker exec m2-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch "$(<"$HERE/setup.sql")"

echo "==> data.sql"
ch "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 2 demo complete.

Stack still running. Tear down with:  ./down.sh
EOF
