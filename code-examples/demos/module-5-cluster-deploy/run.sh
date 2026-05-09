#!/usr/bin/env bash
# Module 5 — Cluster deployment.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for cluster nodes"
ch_wait_cluster

echo "==> setup.sql"
ch_node s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (3M rows via Distributed)"
ch_node s1r1 "$(<"$HERE/data.sql")"

for n in s1r1 s1r2 s2r1 s2r2 s3r1 s3r2; do
    ch_node "$n" "SYSTEM FLUSH DISTRIBUTED analytics.page_views_distributed" || true
done

echo "==> queries.sql"
ch_node s1r1 "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 5 demo complete.

Demonstrated:
  • ON CLUSTER DDL — single statement creates objects on every node.
  • system.distributed_ddl_queue — audit trail of every ON CLUSTER op.
  • cluster() / clusterAllReplicas() / remote() table functions.
  • Distributed query EXPLAIN.
EOF
