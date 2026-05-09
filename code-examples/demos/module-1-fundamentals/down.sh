#!/usr/bin/env bash
# Tear down Module 1 stack and drop volumes.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
docker compose down -v
