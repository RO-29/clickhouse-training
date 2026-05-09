#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

docker compose up -d

echo -n "waiting for m9-clickhouse"
for _ in $(seq 1 60); do
    if docker exec m9-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
        echo -n " ✓"; break
    fi
    echo -n "."; sleep 2
done

echo -n "  m9-kafka"
for _ in $(seq 1 60); do
    if docker exec m9-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 >/dev/null 2>&1; then
        echo " ✓"; exit 0
    fi
    echo -n "."; sleep 2
done
echo " ✗"; exit 1
