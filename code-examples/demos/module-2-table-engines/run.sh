#!/usr/bin/env bash
# Module 2 — Table engines tour.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch() { printf %s "$1" | docker exec -i m2-clickhouse clickhouse-client; }

if ! docker exec m2-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch "$(<"$HERE/setup.sql")"

echo "==> data.sql"
ch "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch "$(<"$HERE/queries.sql")"

echo "==> extras.sql (VersionedCollapsing, Materialized View, Nested)"
ch "$(<"$HERE/extras.sql")"

cat <<EOF

✓ Module 2 demo complete.

Stack still running. Tear down with:  ./down.sh
EOF
