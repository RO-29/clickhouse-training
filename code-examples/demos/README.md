# ClickHouse Training — End-to-End Demos (Modules 1–9)

Each module folder is a **self-contained, runnable demo** built on the existing
docker-compose stacks under `code-examples/docker/`. Run them top-to-bottom or
pick the one you care about.

## Layout

```
demos/
├── lib/
│   ├── ch.sh           # query helpers (single + cluster aware)
│   └── gen_data.py     # tiny CSV/TSV generator (no external deps)
├── module-1-fundamentals/
├── module-2-table-engines/
├── module-3-sharding/
├── module-4-replication/
├── module-5-cluster-deploy/
├── module-6-query-opt/
├── module-7-backup/
├── module-8-dr/
└── module-9-kafka/
```

Every module folder has the same shape:

| File          | Purpose                                                          |
|---------------|------------------------------------------------------------------|
| `README.md`   | Walkthrough — what the demo proves, prereqs, step-by-step.       |
| `setup.sql`   | DDL the demo expects (idempotent — `IF NOT EXISTS`).             |
| `data.{sql,py}` | Data load. `.sql` for `numbers()` tricks, `.py` for big batches. |
| `queries.sql` | Demo queries you actually look at the output of.                 |
| `run.sh`      | Orchestration. Runs setup → data → queries with `set -e`.        |

## Which compose file does each module need?

| Module                           | Compose file                          | Why                            |
|----------------------------------|---------------------------------------|--------------------------------|
| 1 Fundamentals                   | `docker-compose-single.yml`           | Single instance is enough.     |
| 2 Table engines                  | `docker-compose-single.yml`           | Engines are a server feature.  |
| 3 Sharding                       | `docker-compose-cluster.yml`          | Need 3 shards × 2 replicas.    |
| 4 Replication                    | `docker-compose-cluster.yml`          | Need ZK + replicas.            |
| 5 Cluster deployment             | `docker-compose-cluster.yml`          | ON CLUSTER DDL.                |
| 6 Query optimization             | `docker-compose-single.yml`           | Easier to reason about timing. |
| 7 Backup & recovery              | `docker-compose-single.yml` + MinIO   | Local + S3 backup.             |
| 8 Disaster recovery              | `docker-compose-cluster.yml`          | Need peers to fail over to.    |
| 9 Kafka ingestion                | `docker-compose-kafka.yml`            | Kafka engine demo.             |

## Quick start

```bash
cd code-examples/docker

# Module 1, 2, 6, 7
docker compose -f docker-compose-single.yml up -d

# Module 3, 4, 5, 8
docker compose -f docker-compose-cluster.yml up -d

# Module 9
docker compose -f docker-compose-kafka.yml up -d
```

Then in another shell:

```bash
cd code-examples/demos/module-1-fundamentals
./run.sh
```

## Helpers

`lib/ch.sh` exposes three functions you can `source`:

```bash
ch_single  "SELECT 1"                          # single-node container
ch_node    s1r1 "SELECT 1"                     # specific cluster node
ch_cluster "SELECT count() FROM cluster_t"     # any cluster node, default s1r1
```

`lib/gen_data.py` writes synthetic event rows to stdout in TSV. Pure stdlib.

```bash
python3 lib/gen_data.py --rows 1000000 --start 2026-01-01 --days 90
```

## Cleanup

```bash
docker compose -f docker-compose-single.yml down -v
docker compose -f docker-compose-cluster.yml down -v
docker compose -f docker-compose-kafka.yml down -v
```

`-v` drops the named volumes so the next run starts clean.
