#!/usr/bin/env bash
# Module 7 — Backup & Recovery (single + MinIO).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ch() { printf %s "$1" | docker exec -i m7-clickhouse clickhouse-client; }

if ! docker exec m7-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

echo "==> setup.sql"
ch "$(<"$HERE/setup.sql")"

echo "==> queries.sql (FREEZE + BACKUP TO Disk + RESTORE)"
ch "$(<"$HERE/queries.sql")"

echo "==> queries-s3.sql (BACKUP TO S3 against m7-minio + RESTORE)"
ch "$(<"$HERE/queries-s3.sql")"

echo "==> extras.sql (async + incremental backup, RESTORE chain)"
ch "$(<"$HERE/extras.sql")"

cat <<EOF

✓ Module 7 demo complete.

What just happened:
  • FREEZE wrote hardlink snapshots in /var/lib/clickhouse/shadow/.
  • BACKUP TO Disk('backups', ...) → /var/lib/clickhouse/backups/.
  • Drop + RESTORE → row count back to 2,000,000.
  • Same again, but to MinIO via S3 endpoint http://m7-minio:9000/.

MinIO console: http://localhost:9101  (minioadmin / minioadmin)

Inspect the freeze hardlinks:
  docker exec m7-clickhouse ls -la /var/lib/clickhouse/shadow/

Stack still running. Tear down with:  ./down.sh
EOF
