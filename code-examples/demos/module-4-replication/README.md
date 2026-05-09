# Module 4 — Replication

**Goal:** make ZooKeeper-coordinated replication tangible. Insert into one
replica, watch the other catch up; kill it, recover it.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-cluster.yml up -d
```

## Run

```bash
./run.sh
```

## What this proves

| Step                          | Outcome                                                                 |
|-------------------------------|-------------------------------------------------------------------------|
| Insert into `s1r1` only       | `s1r2` row count matches after `SYSTEM SYNC REPLICA`.                  |
| `system.replicas`             | `absolute_delay = 0` once caught up. `is_leader` indicates merge owner. |
| `system.zookeeper`            | Live view of the `/clickhouse/tables/01/sensor_local` znodes.           |
| Stop `s1r2`, insert 500k more | `s1r1.count()` = 2.5M, `s1r2.count()` = 2M (it's stopped).              |
| Start `s1r2`, sync            | `s1r2.count()` = 2.5M; queue drains.                                    |

## Talking points

- **Path templates** — `/clickhouse/tables/{shard}/sensor_local` is rendered
  per node using its `macros.xml`. `{replica}` is the replica identity.
- **Inserts replicate via parts**, not row-by-row WAL — the new replica fetches
  parts from a peer via the interserver port (9009).
- **`absolute_delay`** — seconds between *most recent insertion's commit time*
  and *what this replica has applied*. Useful as a SLO signal.
- **`SYSTEM SYNC REPLICA`** waits until the queue is drained. Use in tests.
- **`SYSTEM RESTART REPLICA`** is the heavy-handed fix when ZK and disk are
  out of sync — it tears down the in-process state and re-reads from ZK.

## Cleanup

```bash
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP TABLE sensor_distributed ON CLUSTER clickhouse_cluster SYNC"
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP TABLE sensor_local ON CLUSTER clickhouse_cluster SYNC"
```
