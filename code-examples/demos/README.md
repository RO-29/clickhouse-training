# ClickHouse Training — End-to-End Demos (Modules 1–9)

Each module is a **self-contained, runnable demo** with its own
`docker-compose.yml`, configs, init scripts, and lifecycle scripts. No
cross-module imports, no shared root infrastructure.

## Layout

```
demos/
├── module-1-fundamentals/      single   · MergeTree, parts, partitions
├── module-2-table-engines/     single   · Replacing/Summing/Aggregating/Collapsing/Log/Memory/Buffer
├── module-3-sharding/          cluster  · Distributed, sharding key, internal_replication
├── module-4-replication/       cluster  · ReplicatedMergeTree + ZK + kill-replica drill
├── module-5-cluster-deploy/    cluster  · ON CLUSTER DDL, distributed_ddl_queue, cluster()/remote()
├── module-6-query-opt/         single   · 60M rows: PK/projections/skip-indexes, measured timings
├── module-7-backup/            single + MinIO · FREEZE, BACKUP TO Disk, BACKUP TO S3, RESTORE
├── module-8-dr/                cluster  · 4 disaster drills incl. replica disk-loss recovery
└── module-9-kafka/             kafka    · Kafka engine + 2 MVs + Python producer
```

Every module folder has the same shape:

```
module-N-foo/
├── README.md           # walkthrough + what it proves
├── docker-compose.yml  # full stack for THIS module (containers prefixed mN-)
├── configs/            # XML configs the compose mounts
├── setup.sql           # demo DDL
├── data.{sql,py}       # demo data load
├── queries.sql         # demo queries
├── up.sh               # docker compose up + wait for health
├── run.sh              # the actual demo (calls up.sh if needed)
└── down.sh             # docker compose down -v
```

## Standard lifecycle

```bash
cd module-1-fundamentals/

./up.sh        # bring stack up, wait until healthy
./run.sh       # run the demo (idempotent — re-runnable)
./down.sh      # tear down + drop volumes
```

`./run.sh` self-bootstraps: if the stack isn't already up it calls `up.sh`
first.

## Container naming

To keep modules from colliding, all containers and volumes are prefixed by
module:

| Module | Prefix | Container example       | Notes                                |
|--------|--------|-------------------------|--------------------------------------|
| 1      | `m1-`  | `m1-clickhouse`         | Single node                          |
| 2      | `m2-`  | `m2-clickhouse`         | Single node                          |
| 3      | `m3-`  | `m3-s1r1`, `m3-zk1`     | 3×2 cluster + 3-node ZK              |
| 4      | `m4-`  | `m4-s1r1`, `m4-zk1`     | 3×2 cluster                          |
| 5      | `m5-`  | `m5-s1r1`, `m5-zk1`     | 3×2 cluster                          |
| 6      | `m6-`  | `m6-clickhouse`         | Single node, 6G RAM                  |
| 7      | `m7-`  | `m7-clickhouse`, `m7-minio` | Single node + MinIO              |
| 8      | `m8-`  | `m8-s1r1`, `m8-zk1`     | 3×2 cluster                          |
| 9      | `m9-`  | `m9-clickhouse`, `m9-kafka` | CH + Kafka + ZK + UI             |

> **Run one module at a time.** Several modules expose host port `8123`. Tear
> down (`./down.sh`) before starting the next module.

## Standard host ports

| Module       | HTTP                | TCP                   | Other                    |
|--------------|---------------------|-----------------------|--------------------------|
| 1, 2, 6      | `8123`              | `9000`                | —                        |
| 3, 4, 5, 8   | `8123-8128`         | `9000-9005`           | (each replica = +1 port) |
| 7            | `8123`, `9100/9101` | `9000`                | MinIO API/console        |
| 9            | `8123`, `8080`      | `9000`, `9092`        | Kafka UI on `8080`       |

## What each module demonstrates

| Module | Core ideas                                                                                  |
|--------|---------------------------------------------------------------------------------------------|
| 1      | MergeTree, partitions, parts, OPTIMIZE, system.parts/system.tables.                          |
| 2      | The right engine for SCD, counters, agg states, current-state, Log, Memory, Buffer.          |
| 3      | Distributed table, sharding key, weighted shards, `internal_replication`.                    |
| 4      | ReplicatedMergeTree, ZK paths, replication queue, lag, replica recovery.                     |
| 5      | ON CLUSTER DDL fanout, `distributed_ddl_queue`, cluster()/remote()/clusterAllReplicas().     |
| 6      | PK/sorting key, projections, skip-indexes, EXPLAIN, materialized views — with timings.        |
| 7      | FREEZE, BACKUP/RESTORE to local disk and to S3 (MinIO), partition detach/attach.              |
| 8      | DR drills: replica down, shard down, ZK loss, replica disk loss → rebuild from peer.          |
| 9      | Kafka engine + Materialized Views, multi-MV pipelines, consumer offsets, error handling.      |

## Prerequisites

- Docker (Compose v2 — `docker compose ...`, two words).
- Python 3 only for module 9's producer.
- 6–8 GB free RAM for the cluster modules.

That's it. Everything else is in the module folders.
