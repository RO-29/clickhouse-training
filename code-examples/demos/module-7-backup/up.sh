#!/usr/bin/env bash
# Bring up Module 7 stack: ClickHouse + MinIO + bucket bootstrap.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

docker compose up -d

echo -n "waiting for m7-clickhouse"
for _ in $(seq 1 60); do
    if docker exec m7-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
        echo -n " ✓"; break
    fi
    echo -n "."; sleep 2
done

echo -n "  m7-minio"
for _ in $(seq 1 30); do
    if docker exec m7-minio curl -sf http://localhost:9000/minio/health/ready >/dev/null 2>&1; then
        echo " ✓"; exit 0
    fi
    echo -n "."; sleep 2
done
echo " ✗"; exit 1
