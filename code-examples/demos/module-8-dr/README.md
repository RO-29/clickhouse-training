# Module 8 — Disaster Recovery (standalone)

Self-contained 3×2 cluster (prefix `m8-`) for failure-injection drills. All
chaos is inflicted via `docker stop` / `docker run … rm -rf` so re-running
is safe.

## Container map

| Role        | Container | Host HTTP | Host TCP |
|-------------|-----------|-----------|----------|
| Shard 1 R1  | `m8-s1r1` | 8123      | 9000     |
| Shard 1 R2  | `m8-s1r2` | 8124      | 9001     |
| Shard 2 R1  | `m8-s2r1` | 8125      | 9002     |
| Shard 2 R2  | `m8-s2r2` | 8126      | 9003     |
| Shard 3 R1  | `m8-s3r1` | 8127      | 9004     |
| Shard 3 R2  | `m8-s3r2` | 8128      | 9005     |
| ZK 1/2/3    | `m8-zk1/2/3` | (internal) | |

## Run

```bash
./up.sh
./run.sh         # runs all 4 drills end-to-end
./down.sh
```

> The script is destructive *only to its own table* (`default.dr_local`) and
> `m8-` containers. Nothing else is at risk.

## Drills

1. **Single replica down (`m8-s1r2`)** — reads/writes continue, `SYSTEM SYNC
   REPLICA` reconciles on return.
2. **Whole shard down (`m8-s2r1` + `m8-s2r2`)** — `skip_unavailable_shards = 1`
   returns partial results; without it the query errors.
3. **One ZK node lost (`m8-zk1`)** — quorum 2/3 holds, no impact.
4. **Replica disk loss (`m8-s1r2` data wiped)** — `SYSTEM DROP REPLICA` +
   `CREATE TABLE` + `SYSTEM SYNC REPLICA` rebuilds from peer.

## Talking points

- Backups and replication serve different threats. Replication protects
  against hardware loss; backups protect against bad `DROP TABLE` /
  application bugs.
- ZK is the single coordination point for `ReplicatedMergeTree`; run 3+ ZK
  nodes and monitor `system.zookeeper_log` and `system.replicas`.
- `detached/` under each table dir holds parts CH refused to attach
  (corruption, schema drift). `ALTER … ATTACH PART` brings them back.

## Cleanup

`./down.sh` drops the whole stack including volumes.
