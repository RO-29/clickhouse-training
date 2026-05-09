# Module 8 — Disaster Recovery

**Goal:** practice four real-world failure scenarios and the recovery
procedure for each. All inflicted via `docker stop` so you can re-run safely.

## Prereqs

```bash
docker compose -f code-examples/docker/docker-compose-cluster.yml up -d
```

## Run

```bash
./run.sh
```

> The script is destructive *to the demo's own table* — it stops containers
> and even wipes a replica's data dir. It only touches the `default.dr_local`
> table; nothing else is at risk.

## Drills

### Drill 1 — Single replica down (`s1r2`)

- Reads continue against `s1r1`.
- Writes go to `s1r1`; replication queue holds for `s1r2`.
- On restart, `SYSTEM SYNC REPLICA` drains the queue and the replica catches up.

### Drill 2 — Whole shard down (`s2r1` + `s2r2`)

- `skip_unavailable_shards = 1` — query returns partial results.
- Without it — the query errors. Treat this as a deliberate choice.

### Drill 3 — One ZK node lost (`zookeeper-1`)

- Quorum of 2/3 still holds; the cluster keeps inserting and replicating.
- Lose 2/3 ZK nodes and you'd lose write availability for ReplicatedMergeTree.

### Drill 4 — Replica disk loss (`s1r2` data wiped)

The recovery procedure:

1. `SYSTEM DROP REPLICA '<host>' FROM TABLE <t>` — clear the dead replica
   pointer in ZooKeeper from a peer.
2. Drop and re-`CREATE TABLE` on the wiped node, with the same ZK path.
3. `SYSTEM SYNC REPLICA` — it pulls every part from peers.

This is the scariest-looking but most important drill. Practice it.

## Things to call out

- **`SYSTEM RESTART REPLICA`** is a softer reset than what we did in drill 4 —
  use it when in-process state is wedged but data is intact.
- **`detached/`** under each table dir holds parts ClickHouse refused to
  attach (corruption, version drift). `ALTER … ATTACH PART` brings them back
  manually.
- **Backups + replication are not the same thing.** Replication protects you
  from hardware loss; backups protect you from a bad `DROP TABLE`.
- **ZK is the single point of coordination** for ReplicatedMergeTree. Run
  3–5 nodes; monitor `system.zookeeper_log` and `system.replicas`.

## Cleanup

```bash
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP TABLE dr_distributed ON CLUSTER clickhouse_cluster SYNC"
docker exec -i clickhouse-s1r1 clickhouse-client \
  --query "DROP TABLE dr_local ON CLUSTER clickhouse_cluster SYNC"
```
