#!/usr/bin/env bash
# Module 6 — Query optimization. Single node, 20M rows × 3 layouts.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for clickhouse-single"
ch_wait_single

echo "==> setup.sql"
ch_single "$(<"$HERE/setup.sql")"

echo "==> data.sql (60M total inserts, ~30s)"
time ch_single "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch_single "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 6 demo complete.

Compare read_rows / query_duration_ms across BAD / GOOD / PROJ in the
output of Q5. Time-first PK + projection should be 10–100× faster on the
country aggregation; bloom-filter skip index helps on user_id lookups.
EOF
