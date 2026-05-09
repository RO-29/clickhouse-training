#!/usr/bin/env bash
# Tear down EVERY demo module's compose stack (volumes + networks).
# Running this from any module's folder leaves Docker in a clean state.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS="$(cd "$HERE/.." && pwd)"

echo "==> tearing down all demo modules"
for d in "$DEMOS"/module-*/; do
    name="$(basename "${d%/}")"
    [ -f "${d}docker-compose.yml" ] || continue
    if docker compose -f "${d}docker-compose.yml" ps -aq 2>/dev/null | grep -q .; then
        echo "    -> down $name"
        docker compose -f "${d}docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true
    fi
done

# Catch any stray m{1..9}- containers / volumes / networks that escaped
# (e.g. created manually). docker compose down only knows what its own
# project file declares.
echo "==> sweeping orphan m{1..9}- resources"
stray=$(docker ps -aq --filter 'name=^m[1-9]-' 2>/dev/null || true)
[ -n "$stray" ] && docker rm -f $stray >/dev/null 2>&1 || true
stray_vols=$(docker volume ls -q | grep -E '^m[1-9]_' || true)
[ -n "$stray_vols" ] && docker volume rm $stray_vols >/dev/null 2>&1 || true
stray_nets=$(docker network ls --format '{{.Name}}' | grep -E '^module-[1-9].*_m[1-9]-net$|^m[1-9]-net$' || true)
[ -n "$stray_nets" ] && docker network rm $stray_nets >/dev/null 2>&1 || true

echo "✓ all demo stacks torn down"
