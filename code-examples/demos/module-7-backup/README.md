# Module 7 — Backup & Recovery (standalone)

Self-contained stack: ClickHouse + MinIO (S3) + bucket bootstrap. Demonstrates
all three real-world backup paths.

## What you get

```
docker-compose.yml          # m7-clickhouse + m7-minio + m7-minio-init
configs/clickhouse-config.xml   # backups disk + S3 allow-list
setup.sql · queries.sql · queries-s3.sql
up.sh · run.sh · down.sh
```

## Container map

| Service     | Container       | Host ports         |
|-------------|-----------------|--------------------|
| ClickHouse  | `m7-clickhouse` | 8123, 9000         |
| MinIO       | `m7-minio`      | 9100 (S3), 9101 (console) |
| Bootstrap   | `m7-minio-init` | (one-shot)         |

MinIO console: http://localhost:9101 — `minioadmin / minioadmin`.

## Run

```bash
./up.sh        # CH + MinIO up; bucket 'clickhouse-backups' created
./run.sh       # FREEZE + BACKUP TO Disk + RESTORE, then BACKUP TO S3
./down.sh
```

## What this proves

| Step                                      | Outcome                                                                       |
|-------------------------------------------|-------------------------------------------------------------------------------|
| `ALTER … FREEZE`                          | Hardlinks under `/var/lib/clickhouse/shadow/<N>/`.                            |
| `BACKUP TO Disk('backups', ...)`          | Single zip under `/var/lib/clickhouse/backups/`.                              |
| Drop table + `RESTORE`                    | Row count returns to 2,000,000.                                              |
| `DETACH PARTITION` / `ATTACH PARTITION`   | Per-partition mobility without rewrite.                                       |
| `BACKUP TO S3('http://m7-minio:9000/...')`| Manifest + parts in MinIO bucket; visible at http://localhost:9101.          |
| `RESTORE FROM S3(...)`                    | Round-trip from object storage.                                              |

## Knobs to know

- The `backups` disk and allow-list live in `configs/clickhouse-config.xml`.
  ClickHouse will refuse BACKUP/RESTORE without them.
- **`SETTINGS async = 1`** on `BACKUP` returns immediately; poll
  `system.backups`. Use for big tables.
- **Incremental backup**: `SETTINGS base_backup = ...` references a prior
  backup; only changed parts go to disk.
- **`FREEZE` is per-host.** For coordinated cluster snapshots, use
  `BACKUP … ON CLUSTER`.

## Extras (curriculum coverage)

`extras.sql` adds:

- **Async backup** — `SETTINGS async = 1` returns immediately; status
  visible in `system.backups`. Poll loop included.
- **Incremental backup** — `SETTINGS base_backup = Disk('backups', '<base>')`
  writes only changed parts; the resulting zip is far smaller than the
  full backup.
- **RESTORE chain** — restoring an incremental backup automatically
  walks back to the base.
- **`clickhouse-backup` CLI** (Altinity) — note on the operational tool
  most teams use; wraps BACKUP/RESTORE with S3 upload/download and
  manifest tracking.
- **`BACKUP ON CLUSTER`** — single-line note for the cluster modules.

## Cleanup

`./down.sh` drops volumes including the MinIO bucket. To clear data without
tearing down:

```bash
docker exec -i m7-clickhouse clickhouse-client --query "DROP DATABASE m7"
docker exec m7-clickhouse rm -rf /var/lib/clickhouse/shadow/* /var/lib/clickhouse/backups/*
```
