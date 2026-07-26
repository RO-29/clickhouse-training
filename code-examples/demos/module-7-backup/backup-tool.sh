#!/usr/bin/env bash
# ============================================================================
# clickhouse-backup (Altinity) — full + incremental against MinIO.
#
# Config: configs/clickhouse-backup.yml
# The tool runs in its own container (m7-backup-tool) that shares the
# m7_data volume with ClickHouse, because it works by FREEZEing tables and
# reading the resulting hardlinks out of /var/lib/clickhouse/shadow/.
#
# Usage:  ./backup-tool.sh
# ============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cb()  { docker exec m7-backup-tool clickhouse-backup "$@" 2>&1 | grep -vE " (INF|WRN) " || true; }
cbv() { docker exec m7-backup-tool clickhouse-backup "$@" 2>&1; }   # verbose
ch()  { docker exec m7-clickhouse clickhouse-client -q "$1"; }

if ! docker ps --filter name=m7-backup-tool --filter status=running -q | grep -q .; then
    echo "m7-backup-tool is not running — start the stack first:  ./up.sh"
    exit 1
fi

FULL="full-$(date +%Y%m%d-%H%M%S)"
INC="inc-$(date +%Y%m%d-%H%M%S)"

echo "==> 0. What the tool can see"
# Sizes come from system.tables; 'full' is the backup type it would take.
cb tables

echo
echo "==> 1. Full backup + upload in one step (create_remote)"
# create_remote = create (local FREEZE) + upload (to s3.path in the bucket).
# Use plain `create` then `upload` if you want the two phases separate —
# e.g. to snapshot fast during a quiet window and upload later.
cbv create_remote --tables='m7.transactions' "$FULL" \
    | grep -E "operation=upload|upload_size" | tail -2

echo
echo "==> 2. New data arrives (a fresh March partition)"
ch "INSERT INTO m7.transactions
    SELECT number + 3000000,
           toDateTime('2026-03-10 00:00:00') + INTERVAL (number % 86400) SECOND,
           1 + (rand(number) % 50000),
           toDecimal64(rand(number+1) % 100000 / 100.0, 2),
           arrayElement(['USD','EUR','INR','JPY'],   1 + toUInt8(rand(number+2) % 4)),
           arrayElement(['ok','pending','reversed'], 1 + toUInt8(rand(number+3) % 3))
    FROM numbers(150000)"
ch "SELECT partition, sum(rows) AS rows FROM system.parts
    WHERE database='m7' AND table='transactions' AND active
    GROUP BY partition ORDER BY partition FORMAT PrettyCompact"

echo
echo "==> 3. Incremental (--diff-from-remote)"
# --diff-from-remote names the REMOTE backup to diff against. The tool
# compares part lists and uploads only parts the base does not already have.
# (--diff-from is the local-only equivalent.)
# This requires general.upload_by_part: true — it is the default, and
# turning it off silently makes every backup a full one.
cbv create_remote --diff-from-remote="$FULL" --tables='m7.transactions' "$INC" \
    | grep -E "operation=upload|upload_size" | tail -2

echo
echo "==> 4. list remote — note the 'required' column"
# The '+full-...' entry is the dependency link. Deleting that base orphans
# this incremental, exactly as with native base_backup.
cb list remote

echo
echo "==> 5. Simulate real disaster recovery"
# Delete the LOCAL copies so the restore genuinely has to download.
for b in "$INC" "$FULL"; do cb delete local "$b" >/dev/null 2>&1 || true; done
echo "    local backups deleted:"
cb list local
echo "    (nothing listed above = local store is empty)"

# DROP TABLE ... SYNC, not a plain DROP. See note at the bottom of this file.
ch "DROP TABLE m7.transactions SYNC"
echo "    table dropped (SYNC)"

echo
echo "==> 6. restore_remote from the INCREMENTAL"
# Downloads the incremental AND the diff parts it needs from the base,
# recreates the schema, then attaches the parts.
cbv restore_remote --tables='m7.transactions' "$INC" \
    | grep -E "downloadDiffParts|download_size|operation=restore," | tail -3

echo
echo "==> 7. Verify"
ch "SELECT count() AS rows_restored FROM m7.transactions"
ch "SELECT partition, sum(rows) AS rows FROM system.parts
    WHERE database='m7' AND table='transactions' AND active
    GROUP BY partition ORDER BY partition FORMAT PrettyCompact"

cat <<'EOF'

────────────────────────────────────────────────────────────────────────────
What to take away

  Compare the three sizes printed above:

    step 1  upload_size    full backup — the whole table
    step 3  upload_size    incremental — only the new part, ~1/15th the size
    step 6  download_size  restore — LARGER than the incremental

  That third number is the lesson. The restore had to pull the base's parts
  too: `downloadDiffParts ... diff_parts=N` in the step 6 log is exactly
  that. An incremental is not independently restorable — same hard chain
  dependency as native base_backup, just with better tooling around it.

  Backup cost scales with what CHANGED. Restore cost scales with the
  whole dataset. Plan your RTO against the second number, not the first.

Useful follow-ups:
  docker exec m7-backup-tool clickhouse-backup list remote
  docker exec m7-backup-tool clickhouse-backup print-config
  docker exec m7-backup-tool clickhouse-backup restore_remote --schema <name>
  docker exec m7-backup-tool clickhouse-backup delete remote <name>

  # Restore into a different table so you can diff against the live one
  # instead of overwriting it:
  docker exec m7-backup-tool clickhouse-backup restore_remote \
      --tables='m7.transactions' \
      --restore-table-mapping='transactions:transactions_verify' <name>

────────────────────────────────────────────────────────────────────────────
GOTCHA — always DROP ... SYNC before a tool restore

A plain DROP TABLE on an Atomic database (the default) does not free the
data directory immediately; it parks it for
database_atomic_delay_before_drop_table_sec (default 480s) so UNDROP TABLE
can work. clickhouse-backup recreates the table with its ORIGINAL UUID, so
the restore collides with the parked directory:

  Code: 57. Directory for table data store/ae2/ae215ea4-.../ already exists

Native RESTORE does not hit this — it assigns a fresh UUID. Only the tool
preserves UUIDs. Fixes, in order of preference:
  1. DROP TABLE ... SYNC          (what this script does)
  2. Wait out the 480s window
  3. --restore-table-mapping to a different table name
Recovering from the collision after the fact means clearing
/var/lib/clickhouse/metadata_dropped/ and the store/ dir by hand — avoid.
────────────────────────────────────────────────────────────────────────────
EOF
