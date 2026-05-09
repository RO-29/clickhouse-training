#!/usr/bin/env bash
# Bring up Module 3 cluster (3 ZK + 6 ClickHouse nodes).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
