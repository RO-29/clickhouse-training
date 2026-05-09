# Module 7 — Backup & Recovery

**Goal:** demonstrate the three legitimate backup paths in ClickHouse:

1. `ALTER TABLE … FREEZE` — instant hard-link snapshot.
2. `BACKUP … TO Disk(...)` — backup to a named disk on the host.
3. `BACKUP … TO S3(...)` — backup to S3 (MinIO here).

…and the corresponding `RESTORE` flow for each.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-single.yml up -d
```

The script will start MinIO and connect it to the same docker network as
`clickhouse-single`.

## Run

```bash
./run.sh
```

`run.sh` mounts `configs/backups.xml` into the running container and
restarts it once. After that, BACKUP/RESTORE work for the rest of the
session.

## What this proves

| Step                                | Outcome                                                                       |
|-------------------------------------|-------------------------------------------------------------------------------|
| `ALTER … FREEZE`                    | Hard links under `/var/lib/clickhouse/shadow/<N>/` — same inodes, no copy.   |
| `BACKUP TO Disk('backups', ...)`    | Single zip under `/var/lib/clickhouse/backups/`.                              |
| Drop table + `RESTORE`              | Row count returns to 2,000,000.                                              |
| `DETACH PARTITION`                  | Rows for that month vanish from queries; files moved to `detached/`.         |
| `ATTACH PARTITION`                  | Rows reappear; no merge, no rewrite.                                         |
| `BACKUP TO S3(...)`                 | Manifest + parts written to MinIO bucket; visible at http://localhost:9101.  |
| `RESTORE FROM S3(...)`              | Round-trip from object storage.                                              |

## Knobs to know

- **`backups.xml`** — required. ClickHouse refuses BACKUP/RESTORE to disks
  not in `<allowed_disk>` / `<allowed_path>`.
- **`SETTINGS async = 1`** on `BACKUP` returns immediately and you poll
  `system.backups`. Use for big tables where you don't want to hold the HTTP
  request open.
- **Incremental backup** — `SETTINGS base_backup = ...` references a prior
  backup; only changed parts go to disk.
- **`FREEZE` is per-table**, not per-database; freezes are local to one host.
  For coordinated cluster-wide snapshots, use `BACKUP … ON CLUSTER`.

## Cleanup

```bash
docker exec -i clickhouse-single clickhouse-client --query "DROP DATABASE m7"
docker exec clickhouse-single rm -rf /var/lib/clickhouse/shadow/* /var/lib/clickhouse/backups/*
docker compose -f docker-compose.minio.yml down -v
```
