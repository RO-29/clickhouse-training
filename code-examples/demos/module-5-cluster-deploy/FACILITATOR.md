# Module 5 — Facilitator's guide (how to drive the live session)

> Companion to `README.md`. The README is the reference; this is the
> *script* for running Module 5 as a ~60-minute live training. Section
> numbers below map to README sections.

**The framing line for the whole module:**
> *"A ClickHouse cluster isn't one service — it's N independent processes
> that agree on a `<remote_servers>` map and a Keeper ensemble. There's no
> primary. We drive all of them as one thing."*

---

## 0. Pre-flight (before the session)

```bash
cd code-examples/demos/module-5-cluster-deploy
./up.sh        # 9 containers: 3 ZK/Keeper + 6 CH (m5-s1r1 … m5-s3r2)
./run.sh       # setup → data → queries → extras + Prometheus smoke test
```

- `up.sh` tears down peer demo modules (ports collide), so run M3/M4
  *before* this, not alongside.
- HTTP ports `8123–8128`, TCP `9000–9005`.
- Keep two panes ready: `docker ps`, and a client
  `docker exec -it m5-s1r1 clickhouse-client`.
- If a node refuses cross-node queries, it's the `default-user.xml` ACL
  (the upstream image locks `default` to loopback; the demo widens it).

**Timing budget (~60 min hands-on):** §1 8m · §2 12m · §3 8m · §4 10m ·
§5 5m · §6 4m · §7 15m · wrap 5m. Drop §6 first if you're short.

---

## 1. The "cluster as one thing" mental model (README §1) — ~8 min

Show the architecture diagram. Hammer the coordination-boundaries table:
**replication queue + ON CLUSTER DDL live in Keeper; the shard map is
static XML; users can be either.** Everything else hangs off this spine.

---

## 2. `ON CLUSTER` DDL — the headline demo (README §2) — ~12 min

- Run the `CREATE TABLE … ON CLUSTER` from `setup.sql`. Before/after, show
  the audit trail:
  ```sql
  SELECT entry, host_name, status, exception_text, query_create_time
  FROM system.distributed_ddl_queue ORDER BY query_create_time DESC LIMIT 10;
  ```
- **The "aha":** one statement → **6 rows** (one per host). Walk the
  sequence diagram: initiator writes a task to Keeper; every node watches,
  executes locally, and acks.
- **Provoke a failure (high-impact):** `docker pause m5-s2r2`, run an
  `ON CLUSTER` DDL, show it hang on `distributed_ddl_task_timeout`, then
  `exception_text` naming the dead host. `docker unpause m5-s2r2`, rerun.
  This is the most memorable moment in the module.

---

## 3. Cluster-aware table functions (README §3) — ~8 min

Run the three from `queries.sql` and explain *when each*:

- `cluster()` → **one replica per shard** — one-shot fan-out aggregation.
- `clusterAllReplicas()` → **every** replica — equivalence checks only,
  **never** aggregation (you'd double-count). Show per-replica row counts.
- `remote('m5-s2r1:9000', …)` → pin one host for diagnosis.

Point: *"You don't create a Distributed table for every diagnostic — these
are your ad-hoc tools."*

---

## 4. Users / profiles / quotas / roles (README §4) — ~10 min

- Show `users.xml` (XML = bootstrap), then run `extras.sql`:
  `CREATE ROLE reader/writer ON CLUSTER`, grants. Note roles fan out via the
  **same** ON CLUSTER machinery.
- Inspect `system.users`, `system.roles`, `system.role_grants`.
- Line: *"XML profiles/quotas are RBAC v0; roles + grants are the modern way."*

---

## 5. Prometheus endpoint (README §5) — ~5 min

```bash
docker exec m5-s1r1 wget -qO- http://localhost:9363/metrics | head
```
*"Monitoring is one config block. Every tool on earth speaks this format.
Grafana dashboard 14192 is tuned to it."*

---

## 6. TLS (README §6) — ~4 min

Whiteboard topic (demo ships no certs). Show the `<openSSL>` block; mention
`mkcert` for 60-second dev certs, mTLS for inter-server traffic in prod.

---

## 7. 🔥 Hot / warm / cold storage tiers (README §7) — ~15 min

**Not in the docker demo** (single disk on a laptop) — drive it from the
README and the tier/cache diagram. The arc:

1. **Model:** CH moves *parts*, not rows, down an ordered list of volumes
   (disk → volume → policy → TTL). A move is a file copy — cheap.
2. **Walk the diagram:** the write path ages data hot → warm → cold →
   DELETE; the read path is served by caches.
3. **The *why* of each parameter** (use the table): `move_factor` (keep hot
   headroom or inserts stall), `prefer_not_to_merge` on cold (merges = S3
   egress + cost for nothing), zero-copy replication (or pay N× S3), per-tier
   codecs (LZ4 hot, ZSTD cold).
4. **Caches = what makes cold usable:** `mark_cache_size` is the
   highest-leverage knob (a mark miss on cold is a *blocking S3 GET*); the
   filesystem-cache disk gives cold reads local-NVMe latency;
   `primary_index_cache_size` caps the PK-index RAM that grows with part count.
5. **RAM / CPU limits** (the specific ask): resident PK index per part, mark
   cache sizing (10–20 % of RAM), OS page cache only helps local tiers,
   decompression CPU dominates cold reads, don't starve the background
   move/merge pools.

**The one-sentence trap to leave them with:**
> *"Tiering trades fast NVMe for cheap S3, and you pay it back in RAM (more
> parts = more resident PK index) and CPU (every cold read decompresses from
> scratch). Budget both, or the cost win becomes a latency loss."*

---

## 8. Wrap (README §11–12) — ~5 min

Recap via the 7 talking points (they map 1:1 to the sections). End on the
operational SQL cheatsheet (§9) as the "take this to work" artifact.

---

## Questions to pre-load

| Question | Short answer |
|----------|--------------|
| Is there a leader / primary node? | No. Any healthy replica can initiate ON CLUSTER DDL; all share the same view. |
| What if Keeper is down? | Replication + ON CLUSTER DDL stall; existing data stays readable. |
| How is tiering different from Postgres partitions? | Parts are physical immutable files; a tier move is a file copy, not a re-partition. |
| Does cold data still replicate? | Yes — each replica keeps its own copy unless you enable zero-copy replication on the S3 tier. |
| Why not just `clusterAllReplicas()` for everything? | It hits every replica — fine for equivalence checks, but it double-counts on aggregations. |
