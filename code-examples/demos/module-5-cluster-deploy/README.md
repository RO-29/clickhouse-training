# Module 5 — Cluster Deployment (standalone)

Self-contained 3×2 cluster (prefix `m5-`) for `ON CLUSTER` DDL,
`distributed_ddl_queue` audit, and `cluster()` / `remote()` /
`clusterAllReplicas()` table functions.

## Container map

| Role        | Container | Host HTTP | Host TCP |
|-------------|-----------|-----------|----------|
| Shard 1 R1  | `m5-s1r1` | 8123      | 9000     |
| Shard 1 R2  | `m5-s1r2` | 8124      | 9001     |
| Shard 2 R1  | `m5-s2r1` | 8125      | 9002     |
| Shard 2 R2  | `m5-s2r2` | 8126      | 9003     |
| Shard 3 R1  | `m5-s3r1` | 8127      | 9004     |
| Shard 3 R2  | `m5-s3r2` | 8128      | 9005     |
| ZK 1/2/3    | `m5-zk1/2/3` | (internal) | |

## Run

```bash
./up.sh
./run.sh
./down.sh
```

## What this proves

- One `CREATE TABLE … ON CLUSTER` materialises on every replica (visible in
  `system.distributed_ddl_queue`).
- `cluster('clickhouse_cluster', db, tbl)` queries every shard without a
  Distributed table.
- `clusterAllReplicas(...)` hits every replica — diagnostics only.
- `remote('m5-s2r1:9000', db, tbl)` is a one-shot point query.

## Knobs to know

- **`distributed_ddl_task_timeout`** — how long the initiator waits for every
  node to ack.
- **`distributed_product_mode`** — controls how `IN`/`JOIN` between two
  Distributed tables expand. `'global'` rewrites to GLOBAL IN/JOIN.
- **`prefer_localhost_replica`** — keep the query on the same host when
  possible (default 1).

## Extras (curriculum coverage)

`configs/users.xml` ships three users — `admin`, `analyst`, `app`
(all with password `admin`, sha256-hashed) — plus profiles `default`,
`heavy`, `readonly` and quota `analyst_quota`. `extras.sql` then layers
SQL-managed roles/grants on top:

- `reader` role with `SELECT` on `analytics.*` → granted to `analyst`.
- `writer` role with `INSERT` on `analytics.page_views_*` → granted to
  `app`.
- Inspection via `system.users`, `system.roles`, `system.role_grants`,
  `system.grants`, `system.quotas_usage`.
- **Prometheus endpoint** — `configs/prometheus.xml` enables `/metrics`
  on port `9363`. `run.sh` verifies it inside `m5-s1r1`.
- **TLS (port 9440)** — sketch only (no certs in repo). Use `mkcert` or
  `step-ca` to generate, then add the `<openSSL>` block.

## Cleanup

`./down.sh` drops everything. To clear data without tearing down:

```bash
docker exec -i m5-s1r1 clickhouse-client \
  --query "DROP DATABASE analytics ON CLUSTER clickhouse_cluster SYNC"
```
