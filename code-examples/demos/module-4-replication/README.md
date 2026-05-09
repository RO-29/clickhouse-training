# Module 4 — Replication (standalone)

Self-contained cluster (3 ZK + 6 CH, prefix `m4-`) for hands-on replication
work. Insert into one replica, watch the other catch up; kill it, recover.

## Container map

| Role        | Container | Host HTTP | Host TCP |
|-------------|-----------|-----------|----------|
| Shard 1 R1  | `m4-s1r1` | 8123      | 9000     |
| Shard 1 R2  | `m4-s1r2` | 8124      | 9001     |
| Shard 2 R1  | `m4-s2r1` | 8125      | 9002     |
| Shard 2 R2  | `m4-s2r2` | 8126      | 9003     |
| Shard 3 R1  | `m4-s3r1` | 8127      | 9004     |
| Shard 3 R2  | `m4-s3r2` | 8128      | 9005     |
| ZK 1/2/3    | `m4-zk1/2/3` | (internal) | |

## Run

```bash
./up.sh        # start cluster
./run.sh       # demo + kill-replica drill
./down.sh      # tear down (with volumes)
```

## Execution flow — what `./run.sh` actually does, in order

| #  | Step                                | What happens                                                                                                                                                                                                         |
|----|-------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap                      | If `m4-s1r1` isn't healthy, `up.sh` brings the 9-container stack up (3 ZK + 6 CH). Tears down peer demo modules first.                                                                                              |
| 1  | `setup.sql` (via `m4-s1r1`)         | `ON CLUSTER` creates `sensor_local` (ReplicatedMergeTree partitioned by day, ordered by `(sensor_id, ts)`) and a `sensor_distributed` Distributed wrapper on every node.                                            |
| 2  | `data.sql` (via `m4-s1r1`)          | Inserts 2M rows directly into `sensor_local` on `m4-s1r1` (not via Distributed). This is on purpose: only one replica writes; we want to watch the other one catch up.                                              |
| 3  | `SYSTEM SYNC REPLICA sensor_local`  | Run on `m4-s1r2`. Blocks until `m4-s1r2` has applied every replication-queue entry. After it returns, both replicas hold identical data.                                                                            |
| 4  | `queries.sql` (via `m4-s1r1`)       | Inspects `system.replicas` (queue size, log pointer, absolute delay), `system.replication_queue` (pending merges/fetches), `system.zookeeper` listing of `/clickhouse/tables/01/sensor_local`, and per-replica row counts via `clusterAllReplicas`. |
| 5  | **Failure drill** (in run.sh)       | `docker stop m4-s1r2` → insert 500k more rows on `m4-s1r1` → `docker start m4-s1r2` → wait 5s → `SYSTEM SYNC REPLICA` on `m4-s1r2`. Confirms `m4-s1r2.count() == 2.5M` and queue drained.                            |
| 6  | `extras.sql` (via `m4-s1r1`)        | Sets `insert_quorum = 2`, `insert_quorum_timeout_ms = 5000` and inserts two rows — succeeds because both replicas are alive. Lists ZK quorum metadata. Toggles `select_sequential_consistency` on/off. Inspects `system.replicas` (the list `SYSTEM DROP REPLICA` would target). Prints a Keeper migration note. |

Container stack stays up after `./run.sh`. Tear down with `./down.sh`.

## What this proves

| Step                          | Outcome                                                                 |
|-------------------------------|-------------------------------------------------------------------------|
| Insert into `m4-s1r1` only    | `m4-s1r2` row count matches after `SYSTEM SYNC REPLICA`.               |
| `system.replicas`             | `absolute_delay = 0` once caught up.                                   |
| Stop `m4-s1r2`, insert 500k more | `m4-s1r1.count()` = 2.5M, `m4-s1r2.count()` = 2M (it's stopped).    |
| Start `m4-s1r2`, sync         | `m4-s1r2.count()` = 2.5M; queue drains.                                |

## Talking points

- **`/clickhouse/tables/{shard}/sensor_local`** — the `{shard}` token is
  rendered per node from `configs/macros/macros-sNrM.xml`.
- **`absolute_delay`** is a great SLO signal — alert above some threshold.
- **`SYSTEM RESTART REPLICA`** is the heavy reset for ZK/disk skew.

## Extras (curriculum coverage)

`extras.sql` adds:

- **`insert_quorum`** — `INSERT` blocks until N replicas have committed.
  Combined with `insert_quorum_timeout_ms`, this is the durability/latency
  knob.
- **`select_sequential_consistency`** — reads only consider data the
  quorum has seen. Pairs with `insert_quorum` for linearisable reads.
- **`SYSTEM DROP REPLICA`** — read-only listing here (M8 runs the
  destructive variant).
- **ClickHouse Keeper** — note on swapping ZK for Keeper (Raft-based,
  same client protocol; migrate with `clickhouse-keeper-converter`).
