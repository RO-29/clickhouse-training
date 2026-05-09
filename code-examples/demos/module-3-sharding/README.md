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

## What this proves

1. **Topology**: `system.clusters` returns 3 shards × 2 replicas.
2. **Distributed insert** — rows physically land on the right shard via
   `cityHash64(user_id) % 3`.
3. **Per-shard balance** — `clusterAllReplicas` shows roughly 5M/3 rows per
   shard.
4. **Replica equivalence**: both replicas of shard 1 store equal byte counts.
5. **Query routing**: `WHERE user_id = 42` hits exactly one shard.

## Cleanup

`./down.sh` drops everything including volumes. To clear data without
tearing down:

```bash
docker exec -i m3-s1r1 clickhouse-client \
  --query "DROP TABLE hits_distributed ON CLUSTER clickhouse_cluster SYNC"
docker exec -i m3-s1r1 clickhouse-client \
  --query "DROP TABLE hits_local ON CLUSTER clickhouse_cluster SYNC"
```
