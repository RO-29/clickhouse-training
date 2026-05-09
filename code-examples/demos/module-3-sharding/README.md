# Module 3 — Sharding (standalone)

Self-contained 3-shard × 2-replica cluster with a 3-node ZooKeeper ensemble.

## What you get

```
docker-compose.yml          # 9 containers — 3 ZK + 6 ClickHouse
configs/cluster-node.xml
configs/macros/macros-s{1-3}r{1-2}.xml
setup.sql · data.sql · queries.sql
up.sh · run.sh · down.sh
```

## Container map

| Role          | Container | Host HTTP | Host TCP |
|---------------|-----------|-----------|----------|
| Shard 1 R1    | `m3-s1r1` | 8123      | 9000     |
| Shard 1 R2    | `m3-s1r2` | 8124      | 9001     |
| Shard 2 R1    | `m3-s2r1` | 8125      | 9002     |
| Shard 2 R2    | `m3-s2r2` | 8126      | 9003     |
| Shard 3 R1    | `m3-s3r1` | 8127      | 9004     |
| Shard 3 R2    | `m3-s3r2` | 8128      | 9005     |
| ZK 1 / 2 / 3  | `m3-zk1/2/3` | (internal only) | |

Cluster name: `clickhouse_cluster`.

## Run

```bash
./up.sh        # 9 containers up; ZK quorum + 6 CH /ping responding
./run.sh       # ON CLUSTER DDL, 5M rows via Distributed, demo queries
./down.sh      # docker compose down -v
```

## Execution flow — what `./run.sh` actually does, in order

This module's stack has **9 containers** (3 ZooKeeper + 6 ClickHouse).
ZK has to form quorum and CH has to register every replica before
work can start.

| #  | Step                                | What happens                                                                                                                                                          |
|----|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap                      | If `m3-s1r1` doesn't respond to `/ping`, `up.sh` runs first. It tears down peer demo modules, brings up the cluster, and waits for every CH node to answer `/ping`. ZK quorum is checked via the `service_healthy` dependency on each CH node. |
| 1  | `setup.sql` (via `m3-s1r1`)         | Three `ON CLUSTER` statements: drop any existing `hits_local` / `hits_distributed`, then `CREATE TABLE hits_local … ReplicatedMergeTree('/clickhouse/tables/{shard}/hits_local', '{replica}')` on every node, then a `Distributed('clickhouse_cluster', default, hits_local, cityHash64(user_id))` wrapper. The `{shard}` and `{replica}` macros are expanded per-node from `configs/macros/macros-sNrM.xml`. |
| 2  | `data.sql` (via `m3-s1r1`)          | One `INSERT INTO hits_distributed SELECT FROM numbers(5_000_000)`. The Distributed table fans rows to the right `hits_local` based on `cityHash64(user_id) % 3`. |
| 3  | `SYSTEM FLUSH DISTRIBUTED` × 6      | Distributed inserts spool briefly on each node before forwarding. The script flushes the spool on every replica so the next counts are exact. |
| 4  | `queries.sql` (via `m3-s1r1`)       | Six queries: cluster topology (`system.clusters`), total rows via Distributed, per-shard breakdown via `clusterAllReplicas`, replica equivalence on shard 1 (same byte count on r1 and r2), per-country aggregation pushed down to shards, an `EXPLAIN`, and a single-shard point lookup (`WHERE user_id = 42`). |
| 5  | `extras.sql` (via `m3-s1r1`)        | Sets up a second cluster definition (`weighted_cluster`, weights 1/1/4) — creates `hits_weighted_distributed`, inserts 600k rows, flushes, prints per-shard balance (shard 3 gets ~66%). Then creates three more Distributed tables on top of the same `hits_local` data with alternative sharding keys: `rand()`, `intDiv(user_id, 100000)`, `xxHash64(user_id)`. EXPLAINs each so you can see how the planner narrows the shard set. |

Container stays up after `./run.sh`. Tear down with `./down.sh`.

## What this proves

1. **Topology**: `system.clusters` returns 3 shards × 2 replicas.
2. **Distributed insert** — rows physically land on the right shard via
   `cityHash64(user_id) % 3`.
3. **Per-shard balance** — `clusterAllReplicas` shows roughly 5M/3 rows per
   shard.
4. **Replica equivalence**: both replicas of shard 1 store equal byte counts.
5. **Query routing**: `WHERE user_id = 42` hits exactly one shard.

## Extras (curriculum coverage)

`extras.sql` adds:

- **Weighted shards** — a second cluster definition `weighted_cluster`
  with weights `1, 1, 4` over the same hosts. New inserts go ~66% to
  shard 3; visible via `clusterAllReplicas` count.
- **Alternative sharding keys** — `rand()` (even but no locality),
  `intDiv(user_id, 100000)` (range-style, good for range scans), and
  `xxHash64(user_id)` (drop-in for `cityHash64`). `EXPLAIN` shows how
  each affects shard pruning.

## Cleanup

`./down.sh` drops everything including volumes. To clear data without
tearing down:

```bash
docker exec -i m3-s1r1 clickhouse-client \
  --query "DROP TABLE hits_distributed ON CLUSTER clickhouse_cluster SYNC"
docker exec -i m3-s1r1 clickhouse-client \
  --query "DROP TABLE hits_local ON CLUSTER clickhouse_cluster SYNC"
```
