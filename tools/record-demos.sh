#!/usr/bin/env bash
# Record a vhs GIF for each module's demo run.
# Each module's tape lives at code-examples/demos/module-N-*/diagrams/demo.tape;
# output GIF goes next to it as demo.gif.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMOS="$ROOT/code-examples/demos"

# Ensure clean Docker state to avoid port conflicts during recording
echo "==> tearing down any running demo modules"
for d in "$DEMOS"/module-*/; do
    [ -f "${d}docker-compose.yml" ] || continue
    docker compose -f "${d}docker-compose.yml" down -v >/dev/null 2>&1 || true
done

ONLY="${1:-}"
for d in "$DEMOS"/module-*/; do
    name=$(basename "$d")
    [ -n "$ONLY" ] && [[ "$name" != *"$ONLY"* ]] && continue
    tape="$d/diagrams/demo.tape"
    if [ ! -f "$tape" ]; then
        echo "  skip $name (no tape)"; continue
    fi
    echo "==> recording $name"
    cd "$d"
    vhs "$tape" 2>&1 | grep -v -E '^(Creating|Cleaning)' | tail -5 || true
    cd "$ROOT"

    # Clean up between modules
    docker compose -f "$d/docker-compose.yml" down -v >/dev/null 2>&1 || true
done

echo "==> done. GIFs:"
find "$DEMOS" -name 'demo.gif' -exec ls -lh {} \;
