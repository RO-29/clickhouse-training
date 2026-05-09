#!/usr/bin/env bash
# Module 2 — Table engines tour. Single node.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for clickhouse-single"
ch_wait_single

echo "==> setup.sql"
ch_single "$(<"$HERE/setup.sql")"

echo "==> data.sql"
ch_single "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch_single "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 2 demo complete.

Engines covered:  Replacing · Summing · Aggregating · Collapsing
                  Log · Memory · Buffer
EOF
