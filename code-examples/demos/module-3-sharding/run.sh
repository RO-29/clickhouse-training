#!/usr/bin/env bash
# Module 3 — Sharding. Cluster.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for cluster nodes"
ch_wait_cluster

echo "==> setup.sql (ON CLUSTER DDL via s1r1)"
ch_node s1r1 "$(<"$HERE/setup.sql")"

echo "==> data.sql (5M rows via Distributed table on s1r1)"
ch_node s1r1 "$(<"$HERE/data.sql")"

# Distributed inserts buffer briefly; flush them so per-shard counts settle.
echo "==> SYSTEM FLUSH DISTRIBUTED on every node"
for n in s1r1 s1r2 s2r1 s2r2 s3r1 s3r2; do
    ch_node "$n" "SYSTEM FLUSH DISTRIBUTED hits_distributed" || true
done

echo "==> queries.sql"
ch_node s1r1 "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 3 demo complete.

Try interactively:
  docker exec -it clickhouse-s1r1 clickhouse-client
  > SELECT shardNum(), count() FROM hits_distributed GROUP BY shardNum();
  > SELECT * FROM system.distribution_queue;
EOF
