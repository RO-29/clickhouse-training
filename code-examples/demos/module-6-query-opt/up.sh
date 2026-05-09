#!/usr/bin/env bash
# Bring up Module 6-query-opt stack. Tears down any other demo
# module first to avoid host-port collisions.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS="$(cd "$HERE/.." && pwd)"
SELF="$(basename "$HERE")"

echo "==> stopping any other demo modules (port-conflict check)"
for d in "$DEMOS"/module-*/; do
    name="$(basename "${d%/}")"
    [ "$name" = "$SELF" ] && continue
    [ -f "${d}docker-compose.yml" ] || continue
    if docker compose -f "${d}docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
        echo "    -> down $name"
        docker compose -f "${d}docker-compose.yml" down -v >/dev/null 2>&1 || true
    fi
done

cd "$HERE"
docker compose up -d

echo -n "waiting for m6-clickhouse"
for _ in $(seq 1 60); do
    if docker exec m6-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
        echo " ✓"; exit 0
    fi
    echo -n "."; sleep 2
done
echo " ✗"; exit 1
