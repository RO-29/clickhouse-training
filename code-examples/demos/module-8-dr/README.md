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

## Execution flow — what `./run.sh` actually does, in order

This module is mostly chaos drills inside `run.sh` itself, not a static
SQL file. Every drill is independent; if one fails, the next still runs.

| #  | Step                              | What happens                                                                                                                                                                                                                                              |
|----|-----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0  | self-bootstrap                    | `up.sh` brings up the 3-shard × 2-replica cluster with 3-node ZK ensemble (9 containers).                                                                                                                                                                |
| 1  | `setup.sql` (via `m8-s1r1`)       | `ON CLUSTER` creates `dr_local` (ReplicatedMergeTree) and `dr_distributed` on every node.                                                                                                                                                                 |
| 2  | `data.sql` (via `m8-s1r1`)        | Inserts 1M rows via the Distributed table.                                                                                                                                                                                                                 |
| 3  | `SYSTEM FLUSH DISTRIBUTED` × 6    | Flush spool on every node. Print `baseline rows` count.                                                                                                                                                                                                    |
| 4  | **Drill 1 — Replica failure**     | `docker stop m8-s1r2`. Print `system.clusters.errors_count`. Read via Distributed (still works via `m8-s1r1`). Insert two rows via `m8-s1r1` while `m8-s1r2` is down. `docker start m8-s1r2`, `SYSTEM SYNC REPLICA`, verify `m8-s1r2` has the new rows.    |
| 5  | **Drill 2 — Whole shard outage**  | `docker stop m8-s2r1 m8-s2r2`. Read with `SETTINGS skip_unavailable_shards = 1` (returns partial). Read without it (errors). Restart shard 2 nodes, `SYSTEM SYNC REPLICA`, verify count restored.                                                          |
| 6  | **Drill 3 — Lose one ZK node**    | `docker stop m8-zk1`. Insert a row (works — ZK quorum 2/3 still holds). Restart ZK 1.                                                                                                                                                                       |
| 7  | **Drill 4 — Replica disk loss**   | `docker stop m8-s1r2`, wipe its data volume (`/var/lib/clickhouse/{data,metadata,store}`) using a throwaway alpine container. Restart it. From `m8-s1r1`: `SYSTEM DROP REPLICA 'm8-s1r2' FROM TABLE dr_local`. From `m8-s1r2`: drop the local table, recreate it pointing at the same ZK path, `SYSTEM SYNC REPLICA` — table rebuilds from peer. |
| 8  | **Drill 5 — `insert_quorum`**     | `docker stop m8-s1r2`. Try `INSERT … SETTINGS insert_quorum = 2, insert_quorum_timeout_ms = 3000` — must time out (1/2 replicas alive). Restart, sync, retry — succeeds.                                                                                  |
| 9  | **Drill 6 — Restore-from-backup** | `BACKUP TABLE dr_local ON CLUSTER … TO File('/tmp/dr_local_backup_$$')`. `DROP TABLE … ON CLUSTER`. `RESTORE TABLE … ON CLUSTER FROM File(…)`. Note: cluster nodes don't share `/tmp` in this compose, so the restore step shows the expected "use S3" pointer. |

Cluster stays up after `./run.sh`. Tear down with `./down.sh`.

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

## Extras (curriculum coverage)

The script also runs two more drills:

- **Drill 5 — `insert_quorum` durability gate.** With `insert_quorum = 2`
  and only one replica of shard 1 alive, the INSERT correctly *times out
  and fails*. Brings the replica back, retries — succeeds. This is the
  RPO=0 knob.
- **Drill 6 — Restore-from-backup recovery path.** `BACKUP TABLE …
  ON CLUSTER` snapshots to a per-node `File()` location, drops the table
  cluster-wide, then `RESTORE` rebuilds it. The cluster compose's
  containers don't share `/tmp`, so the cluster-wide restore step shows
  the expected "use S3" pointer (Module 7 does the S3 round-trip).

### Multi-datacenter architecture (not exercised, sketch only)

A typical CH multi-DC layout:

- 1× CH cluster per DC, ZK quorum spans DCs (3 nodes minimum, 5 better,
  with at least one ZK observer in a third site for tie-break).
- Cross-DC replication via `ReplicatedMergeTree`'s ZK paths — a `<shard>`
  with one `<replica>` per DC.
- Application traffic via DNS or a load balancer, fail-over flips the
  CNAME to the surviving DC. RPO≈0 if you also use `insert_quorum`,
  RPO≈seconds otherwise.

## Cleanup

`./down.sh` drops the whole stack including volumes.
