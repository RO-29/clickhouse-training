#!/usr/bin/env bash
# Bring up Module 3-sharding cluster (3 ZK + 6 ClickHouse).
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

echo -n "waiting for cluster nodes"
for n in m3-s1r1 m3-s1r2 m3-s2r1 m3-s2r2 m3-s3r1 m3-s3r2; do
    for _ in $(seq 1 60); do
        if docker exec "$n" wget --spider -q http://localhost:8123/ping 2>/dev/null; then
            echo -n " $n"; break
        fi
        sleep 2
    done
done
echo " ✓"
