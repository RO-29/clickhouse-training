#!/usr/bin/env bash
# Module 1 — Fundamentals.  Single node.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/ch.sh
source "$HERE/../lib/ch.sh"

echo "==> waiting for clickhouse-single"
ch_wait_single

echo "==> setup.sql"
ch_single "$(<"$HERE/setup.sql")"

echo "==> data.sql (this generates ~2M rows in 3 inserts)"
ch_single "$(<"$HERE/data.sql")"

echo "==> queries.sql"
ch_single "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 1 demo complete.

Next, try these interactively:
  docker exec -it clickhouse-single clickhouse-client
  > USE m1;
  > SHOW CREATE TABLE events;
  > SELECT * FROM system.parts WHERE table='events' ORDER BY name LIMIT 5;
  > SELECT * FROM system.merges;          # nothing if idle, lots during OPTIMIZE
  > SELECT * FROM system.mutations LIMIT 3;
EOF
