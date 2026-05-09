# Module 7 — Backup & Recovery

> **Audience:** anyone whose job depends on the data not vanishing.
> **Prerequisites:** Modules 1–4. **Time:** ~60 min reading + 30 min hands-on.

By the end you will be able to:

- Choose between FREEZE, BACKUP, and `clickhouse-backup` for a workload.
- Set up a backups disk (local) and an S3-backed backup (MinIO here).
- Build incremental backup chains.
- Run async backups and poll their status.
- Restore from a chain into a clean database.
- Plan a backup schedule and restore drill cadence.

---

## 1. The backup options at a glance

```mermaid
flowchart TB
    Need[Need a backup?]
    Need --> Q1{What for?}
    Q1 -- "instant local snapshot before risky DDL" --> FZ["ALTER TABLE FREEZE"]
    Q1 -- "managed backup file (zip)" --> BU["BACKUP TO Disk('backups','name.zip')"]
    Q1 -- "to object storage (S3 / GCS)" --> S3["BACKUP TO S3('endpoint', key, secret)"]
    Q1 -- "scheduled prod backups, S3 sync, retention" --> CB["clickhouse-backup CLI"]

    FZ -->|fast, hardlinked| Use1[Same host only<br/>recoverable by ATTACH PART]
    BU -->|portable| Use2[Single zip; readable across hosts]
    S3 -->|durable + cheap| Use3[Object-store backed; same SQL syntax]
    CB -->|policy + retention| Use4[Wraps BACKUP/RESTORE + S3 lifecycle]

    classDef use fill:#1a4480,stroke:#fff,color:#fff
    class FZ,BU,S3,CB,Use1,Use2,Use3,Use4 use
```

| Mechanism                           | Time       | Portable | Cluster-aware | Best for                                        |
|-------------------------------------|------------|----------|---------------|-------------------------------------------------|
| `ALTER TABLE … FREEZE`              | instant    | no       | no            | "I'm about to do something risky, snap it now."  |
| `BACKUP … TO Disk('backups', ...)`  | seconds    | yes      | with `ON CLUSTER` | scheduled local backups; nightly cron.       |
| `BACKUP … TO S3(...)`               | seconds-minutes | yes | with `ON CLUSTER` | production durable backups.                  |
| `clickhouse-backup` (Altinity CLI)  | depends    | yes      | yes           | full ops layer: retention, S3 lifecycle, scheduling. |

---

## 2. FREEZE — hardlinked instant snapshots

```sql
ALTER TABLE m7.transactions FREEZE WITH NAME 'demo_snap';
```

What it actually does:

```
/var/lib/clickhouse/data/m7/transactions/
├── 202601_1_1_0/
│   ├── columns.txt
│   ├── ... (data)
└── ...

/var/lib/clickhouse/shadow/demo_snap/
└── data/m7/transactions/
    ├── 202601_1_1_0/   ← hardlinks to the same inodes
    └── ...
```

- **Hardlinks**, not copies. Constant time, zero extra disk while the
  source parts still exist.
- Once a part is merged away, the hardlink in `shadow/` is the *only*
  remaining reference — at which point the inode survives until you
  delete the shadow dir.
- Recovery: copy the hardlinks somewhere safe, then re-import via
  `ALTER TABLE … ATTACH PART`.

> **FREEZE is local-only.** It doesn't help against host loss. Use it
> for "I'm about to do something I might regret" — not as your DR plan.

---

## 3. The `BACKUP` / `RESTORE` SQL

This is the modern, portable way. Targets a registered "backup
destination": a local disk, an S3 bucket, or an HTTP endpoint.

### Configure a destination

The destination must be in the server config:

```xml
<storage_configuration>
    <disks>
        <backups>
            <type>local</type>
            <path>/var/lib/clickhouse/backups/</path>
        </backups>
    </disks>
</storage_configuration>

<backups>
    <allowed_disk>backups</allowed_disk>
    <allowed_path>/var/lib/clickhouse/backups/</allowed_path>
</backups>
```

Without `<backups><allowed_disk>` ClickHouse refuses any BACKUP /
RESTORE command. This is a safety net.

### Full backup → restore

```sql
BACKUP TABLE m7.transactions TO Disk('backups', 'transactions_disk_v1.zip');

-- Verify what got written
SELECT id, name, status, total_size, num_files
FROM system.backups WHERE name LIKE '%transactions_disk_v1%';

-- Drop and restore
DROP TABLE m7.transactions;
RESTORE TABLE m7.transactions FROM Disk('backups', 'transactions_disk_v1.zip');
SELECT count() FROM m7.transactions;
```

### Async backup

For tables larger than your HTTP timeout:

```sql
BACKUP TABLE m7.transactions
TO Disk('backups', 'transactions_async.zip')
SETTINGS async = 1;

-- Poll
SELECT status FROM system.backups
WHERE name LIKE '%transactions_async%' ORDER BY start_time DESC LIMIT 1;
-- Wait until it's BACKUP_CREATED.
```

### Incremental backup

Reference the previous full as `base_backup`. Only changed parts are
written.

```sql
-- Full
BACKUP TABLE t TO Disk('backups', 't_full.zip');

-- New rows...
INSERT INTO t SELECT ...;

-- Incremental
BACKUP TABLE t
TO Disk('backups', 't_inc_v2.zip')
SETTINGS base_backup = Disk('backups', 't_full.zip');

-- Restore: just point at the most recent incremental;
-- CH walks the chain back to the base automatically.
RESTORE TABLE t FROM Disk('backups', 't_inc_v2.zip');
```

### Backup specific partitions

```sql
BACKUP TABLE t
PARTITIONS '202601', '202602'
TO Disk('backups', 't_jan_feb.zip');
```

Useful for "back up just the changed month".

### `BACKUP ON CLUSTER`

For a Replicated table on a cluster, `BACKUP ON CLUSTER` coordinates
across replicas so the snapshot is consistent:

```sql
BACKUP TABLE analytics.page_views_local
ON CLUSTER clickhouse_cluster
TO Disk('backups', 'page_views.zip');
```

Each replica writes to its local `Disk('backups', ...)` — so for cluster
backups you typically point at S3 instead, where every replica writes to
the same bucket.

---

## 4. S3 backups (the production path)

```sql
BACKUP TABLE m7.transactions
TO S3(
    'http://m7-minio:9000/clickhouse-backups/transactions_s3_v1',
    'minioadmin',
    'minioadmin'
);
```

Argument layout: `S3('<endpoint>/<bucket>/<key-prefix>', '<access_key>',
'<secret_key>')`. The endpoint can be AWS S3, MinIO, GCS S3-compat, R2, etc.

What MinIO actually receives:

```
clickhouse-backups/
└── transactions_s3_v1/
    ├── .backup           ← manifest (JSON-ish)
    ├── data/
    │   └── m7/transactions/
    │       └── <part_name>/
    │           ├── columns.txt
    │           ├── checksums.txt
    │           └── ... .bin / .mrk2
    └── metadata/
        └── m7/
            └── transactions.sql
```

The format is *part-level*. That means:
- Incremental backups across S3 share parts (no double-copy).
- A reasonably-equipped human can extract data by hand if needed.

### Restoring from S3

```sql
RESTORE TABLE m7.transactions
FROM S3(
    'http://m7-minio:9000/clickhouse-backups/transactions_s3_v1',
    'minioadmin',
    'minioadmin'
);
```

---

## 5. `clickhouse-backup` — the operations layer

The Altinity tool wraps BACKUP/RESTORE plus operational concerns:

```bash
clickhouse-backup create   nightly-2026-05-09
clickhouse-backup upload   nightly-2026-05-09       # to remote storage
clickhouse-backup download nightly-2026-05-09
clickhouse-backup restore  nightly-2026-05-09

# Maintenance
clickhouse-backup list                              # local + remote
clickhouse-backup delete   local nightly-2026-04-01
clickhouse-backup delete   remote nightly-2026-04-01
```

What it adds beyond raw SQL:

- A YAML config (`clickhouse-backup.yml`) per environment.
- Retention rules (keep N daily, M weekly, K monthly).
- Pre/post hooks (notify on success, run integrity checks).
- Schema-only restore (`--schema`).
- Differential semantics on top of CH's incremental.

Repo: <https://github.com/Altinity/clickhouse-backup>.

---

## 6. Partition operations — the cheap surrogate

For tables you partition by date:

```sql
-- Snapshot a partition (still hardlinks under shadow/)
ALTER TABLE t FREEZE PARTITION '202601';

-- Detach a partition (moves to detached/, queries don't see it)
ALTER TABLE t DETACH PARTITION '202601';

-- Re-attach when ready
ALTER TABLE t ATTACH PARTITION '202601';

-- Drop irrevocably (use with caution; ATTACH FROM detached still possible briefly)
ALTER TABLE t DROP PARTITION '202601';

-- Move a partition between two same-schema tables
ALTER TABLE t_archive ATTACH PARTITION '202601' FROM t;
```

`ATTACH PARTITION FROM` is the single most useful trick for "promote a
staging table into the live table" — fully atomic, no rewrites.

---

## 7. The hands-on demo

### What you get

```
docker-compose.yml          m7-clickhouse + m7-minio + m7-minio-init
configs/clickhouse-config.xml      includes <backups> + <storage_configuration>
setup.sql · queries.sql · queries-s3.sql · extras.sql
up.sh · run.sh · down.sh
```

### Container map

| Service     | Container       | Host ports         |
|-------------|-----------------|--------------------|
| ClickHouse  | `m7-clickhouse` | 8123, 9000         |
| MinIO       | `m7-minio`      | 9100 (S3), 9101 (console) |
| Bootstrap   | `m7-minio-init` | (one-shot)         |

MinIO console: <http://localhost:9101>, login `minioadmin` / `minioadmin`.

### Execution flow — what runs, in order

| #  | Step                                            | What happens                                                                                                                                                                              |
|----|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap                                  | `up.sh` brings up CH + MinIO + the bucket bootstrap (`m7-minio-init` creates `clickhouse-backups`). Both share `m7-net`, so CH can reach `http://m7-minio:9000`.                          |
| 1  | `setup.sql`                                     | Creates database `m7`, table `m7.transactions` (MergeTree partitioned by month, ordered by `(account_id, txn_time, txn_id)`), inserts 2M synthetic rows.                                  |
| 2  | `queries.sql` — local-disk backup path          | `ALTER TABLE … FREEZE WITH NAME 'demo_snap'` (instant hardlinks under `/var/lib/clickhouse/shadow/`), `BACKUP TABLE … TO Disk('backups', 'transactions_disk_v1.zip')`, `DROP TABLE`, `RESTORE TABLE … FROM Disk(…)`, then per-partition `DETACH PARTITION '202601'` + `ATTACH PARTITION '202601'`. |
| 3  | `queries-s3.sql` — S3 backup path               | `BACKUP TABLE … TO S3('http://m7-minio:9000/clickhouse-backups/transactions_s3_v1', 'minioadmin', 'minioadmin')`, look up the backup row in `system.backups`, `DROP TABLE`, `RESTORE … FROM S3(…)`. Verify row count returns to 2M. |
| 4  | `extras.sql` — async + incremental              | `BACKUP TABLE … SETTINGS async = 1` (returns immediately), poll loop on `system.backups.status` until `BACKUP_CREATED`. Insert 50k more rows, then `BACKUP … SETTINGS base_backup = Disk('backups', 'transactions_disk_v1.zip')` — the resulting incremental zip is much smaller. `DROP TABLE`, `RESTORE FROM Disk('backups', 'transactions_inc_v2.zip')` — CH walks the chain to the base. Prints notes on `clickhouse-backup` CLI and `BACKUP ON CLUSTER`. |

### What you should observe

| Step                              | Outcome                                                                                  |
|-----------------------------------|------------------------------------------------------------------------------------------|
| `FREEZE`                          | `/var/lib/clickhouse/shadow/demo_snap/` exists with hardlinks; same inodes as live data. |
| `BACKUP TO Disk`                  | Zip file under `/var/lib/clickhouse/backups/`; `system.backups.status = 'BACKUP_CREATED'`. |
| `DROP` + `RESTORE`                | Row count returns to 2,000,000.                                                           |
| Partition detach/attach           | Row count drops then returns; no data rewrite.                                            |
| `BACKUP TO S3`                    | Visible in MinIO console at <http://localhost:9101>; nested under `clickhouse-backups/transactions_s3_v1/`. |
| Async backup                      | Returns immediately; status flips through `CREATING_BACKUP` → `BACKUP_CREATED`.           |
| Incremental                       | `total_size` of `transactions_inc_v2.zip` ≪ `transactions_disk_v1.zip`.                  |

---

## 8. A reasonable production schedule

| Cadence  | What                                          | Where                              |
|----------|-----------------------------------------------|------------------------------------|
| Daily    | Full `BACKUP ON CLUSTER` to S3                | `s3://backups/clickhouse/<env>/<date>/full` |
| Hourly   | Incremental against the day's full            | `s3://.../<date>/inc-NN`            |
| Weekly   | Restore drill into a sandbox cluster          | scratch S3 path; verify counts      |
| 30 days  | Lifecycle to Glacier / Coldline               | bucket lifecycle rule               |

> **A backup you have never restored is not a backup.** Run a restore
> drill at least monthly. Module 8's drill 6 exercises this end-to-end.

---

## 9. Operational SQL cheatsheet

```sql
-- "What backups exist?"
SELECT id, name, status, formatReadableSize(total_size) AS size,
       num_files, start_time, end_time
FROM system.backups ORDER BY start_time DESC LIMIT 20;

-- "What's running right now?"
SELECT id, name, status, num_files, processed_files
FROM system.backups WHERE status IN ('CREATING_BACKUP','RESTORING') ;

-- "Which freezes are still on disk?"
-- (no system table; check the shadow/ dir)
-- docker exec m7-clickhouse ls /var/lib/clickhouse/shadow/

-- "Drop a stuck async backup"
SYSTEM SHUTDOWN BACKUP <backup_id>;       -- newer CH; varies by version
```

---

## 10. Settings worth knowing

| Setting                              | Effect                                                                |
|--------------------------------------|-----------------------------------------------------------------------|
| `async = 1` on BACKUP                | Returns immediately; poll `system.backups`.                           |
| `base_backup = Disk('...', 'name')`  | Make this an incremental against the named base.                      |
| `compression_method = 'zstd'`        | Compress the backup file (default depends on destination).            |
| `password = '...'`                   | Encrypt the backup (file destination only).                           |
| `s3_max_connections`                 | Concurrency for S3 backup/restore I/O.                                |
| `allow_drop_detached`                | Allow `DROP DETACHED PART` (safety knob; off by default).             |

---

## 11. Common pitfalls

| Symptom                                                                      | Cause                                                                       | Fix                                                                                              |
|------------------------------------------------------------------------------|-----------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| `Code: 605. The maximum size of file system disk is allowed for backups...`  | Backup destination not in `<allowed_disk>` / `<allowed_path>`.              | Add it to `<backups>` in config.                                                                 |
| `BACKUP TO Disk(...)` works but takes forever                                | Tons of small parts (single-row INSERTs from upstream).                     | Optimise / batch upstream. Backup time scales with part count.                                   |
| `RESTORE` fails with "Backup data not found"                                 | Pointed at the wrong base or chain broken.                                  | Verify `system.backups` knows the chain; restore from the highest layer.                         |
| FREEZE makes disk usage spike when old parts merge                           | Hardlinks still reference old part files; merges can't reclaim.             | Clear `shadow/` directories you no longer need.                                                  |
| S3 backup with self-signed MinIO fails on TLS                                | The S3 endpoint URL uses `https://` and the cert isn't trusted.             | Use `http://` for MinIO, or mount the CA into CH and trust it.                                   |
| `BACKUP ON CLUSTER` fails on one node                                        | That node can't reach the destination.                                      | Verify per-node connectivity (e.g. all hosts can resolve the S3 endpoint).                       |

---

## 12. Talking points for the live session

1. **Three layers, three uses.** FREEZE for "oh wait, hold on";
   BACKUP/RESTORE for routine; `clickhouse-backup` for ops scale.
2. **Backups are part-level.** Show MinIO contents; the directory tree
   matches the live data layout.
3. **Incrementals are nearly free** if your data is mostly append.
4. **Restore drills are the test.** Without monthly drills you don't
   have backups, you have hopes.
5. **Partition operations** (DETACH / ATTACH) are the secret weapon for
   archive workflows.
6. **`ON CLUSTER`** for replicated tables — coordinated snapshot.

---

## 13. Going deeper

- **Module 8** — DR drills, including end-to-end backup-restore over
  a cluster.
- ClickHouse docs: <https://clickhouse.com/docs/en/operations/backup>
- `clickhouse-backup`: <https://github.com/Altinity/clickhouse-backup>
