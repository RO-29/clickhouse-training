# Module 5 — Cluster Deployment

**Goal:** drive the cluster as a single thing — DDL fanout, audit trail,
ad-hoc queries with `remote()` / `cluster()` / `clusterAllReplicas()`.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-cluster.yml up -d
```

## Run

```bash
./run.sh
```

## What this proves

- One `CREATE TABLE … ON CLUSTER` creates the table on every replica
  (visible in `system.distributed_ddl_queue`).
- `cluster('clickhouse_cluster', db, tbl)` is a one-shot way to query *every
  shard* without creating a Distributed table.
- `clusterAllReplicas(...)` hits *every replica* — only safe for diagnostics.
- `remote(host:port, db, tbl)` is "go ask this specific node," handy for
  cross-cluster sanity checks.

## Knobs you should know

- **`distributed_ddl_task_timeout`** (default 180s) — how long the initiator
  waits for every node to ack. Bump for big clusters; reduce for tight CI.
- **`distributed_ddl_entry_format_version`** — leave at default; relevant only
  if mixing CH versions during upgrades.
- **`distributed_product_mode`** — controls how `IN`/`JOIN` between two
  Distributed tables expand. `'allow'` is fine for small clusters; `'global'`
  rewrites to GLOBAL IN/JOIN so the right side is broadcast.
- **`prefer_localhost_replica`** — query starts on the same host wherever
  possible. Default `1`. Turn off if you're load-testing the network path.

## Cleanup

```bash
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP DATABASE analytics ON CLUSTER clickhouse_cluster SYNC"
```
