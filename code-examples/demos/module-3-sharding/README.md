# Module 3 — Sharding

**Goal:** show how a `Distributed` table fans inserts across 3 shards using
`cityHash64(user_id)` as the sharding key, and how `internal_replication`
interacts with `ReplicatedMergeTree`.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-cluster.yml up -d
# wait until all 6 CH nodes + 3 ZK nodes are healthy
```

## Run

```bash
./run.sh
```

## What this proves

1. **Topology**: `system.clusters` returns 3 shards × 2 replicas.
2. **Distributed insert** — insert via `hits_distributed`; rows physically land
   on `hits_local` on the right shard based on `cityHash64(user_id) % 3`.
3. **Per-shard balance**: `clusterAllReplicas` shows roughly `5M / 3` rows per
   shard.
4. **Replica equivalence**: both replicas of shard 1 store the same byte count.
5. **Query routing**: `WHERE user_id = 42` hits exactly one shard (visible in
   `EXPLAIN`), because the sharding expression is `cityHash64(user_id)`.

## Key knobs to talk through

- **Sharding key**: must be a deterministic function of stable columns. Bad
  choice (`rand()`, `now()`) → uneven distribution.
- **`internal_replication = true` (in cluster XML)** — Distributed writes to
  *one* replica and lets ReplicatedMergeTree replicate the rest. Set to false
  only if your local table is plain MergeTree (rare; not recommended).
- **Weighted shards**: `<weight>2</weight>` on a bigger box would receive 2×
  the share. Useful for heterogeneous fleets.
- **`SYSTEM FLUSH DISTRIBUTED`** — Distributed inserts go through a per-node
  spool. Flush before counting if you want exact numbers immediately.
- **`cluster()` vs `clusterAllReplicas()`**: the former hits one replica per
  shard, the latter hits every replica. Use `clusterAllReplicas` for
  introspection only — *not* aggregates over data.

## Cleanup

```bash
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP TABLE hits_distributed ON CLUSTER clickhouse_cluster SYNC"
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP TABLE hits_local ON CLUSTER clickhouse_cluster SYNC"
```
