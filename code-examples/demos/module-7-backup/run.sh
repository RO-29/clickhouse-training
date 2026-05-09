#!/usr/bin/env bash
# Module 7 — Backup & Recovery. Single node. Two flavours:
#   1. BACKUP TO Disk(...)   — local filesystem
#   2. BACKUP TO S3(...)     — MinIO sidecar
#
# We hot-mount the backups.xml config and (re)start clickhouse-single so the
# 'backups' disk and BACKUP allow-list become active.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/ch.sh"

echo "==> waiting for clickhouse-single"
ch_wait_single

echo "==> mounting backup config + restarting clickhouse-single"
docker cp "$HERE/configs/backups.xml" clickhouse-single:/etc/clickhouse-server/config.d/backups.xml
docker exec clickhouse-single mkdir -p /var/lib/clickhouse/backups
docker restart clickhouse-single >/dev/null
ch_wait_single

echo "==> setup.sql"
ch_single "$(<"$HERE/setup.sql")"

echo "==> queries.sql (FREEZE + BACKUP TO Disk + RESTORE)"
ch_single "$(<"$HERE/queries.sql")"

# === MinIO sidecar for the S3 part ===
echo
echo "==> bringing up MinIO sidecar"
docker compose -f "$HERE/docker-compose.minio.yml" up -d

# Wait until MinIO answers
for _ in $(seq 1 30); do
    docker exec minio curl -sf http://localhost:9000/minio/health/ready && break || true
    sleep 2
done

# Discover the network of clickhouse-single and attach minio to it
NET=$(docker inspect clickhouse-single --format '{{range $k, $_ := .NetworkSettings.Networks}}{{$k}} {{end}}' | awk '{print $1}')
echo "==> attaching minio to network: $NET"
docker network connect "$NET" minio 2>/dev/null || echo "  (already attached)"

# Create bucket
docker run --rm --network "$NET" \
    -e MC_HOST_local=http://minioadmin:minioadmin@minio:9000 \
    minio/mc mb -p local/clickhouse-backups || true

echo "==> queries-s3.sql (BACKUP TO S3 + RESTORE)"
ch_single "$(<"$HERE/queries-s3.sql")"

cat <<EOF

✓ Module 7 demo complete.

What just happened:
  • FREEZE produced an instant snapshot in /var/lib/clickhouse/shadow/.
  • BACKUP TO Disk('backups', ...) wrote a zip to the named disk.
  • Table dropped + RESTORE → row count back to 2,000,000.
  • Same again, but to MinIO via S3 endpoint http://minio:9000/.

MinIO console: http://localhost:9101  (minioadmin / minioadmin)

Inspect the freeze hardlinks:
  docker exec clickhouse-single ls -la /var/lib/clickhouse/shadow/
EOF
