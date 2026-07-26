# Module 8 — Facilitator's guide (how to drive the live session)

> Companion to `README.md`. The README is the reference; this is the
> *script* for running Module 8 as a ~75-minute live training. Section
> numbers below map to README sections.

**The framing line for the whole module:**
> *"DR isn't a ClickHouse feature. It's a set of answers to three questions —
> what can break, how fast must we be back, how much may we lose. ClickHouse
> gives you three independent tools — replication, quorum, backups — and each
> covers a failure class the others can't touch."*

**The sentence that does the most work** (say it early, call back to it twice):
> *"Replication protects you from hardware loss. Backups protect you from
> human and software loss."*

Make it concrete the moment you say it: *"`DROP TABLE` replicates.
Faithfully. In milliseconds. To every replica in every DC."* That one line
justifies why Module 7 and Module 8 are separate modules, and it pre-empts
the most common misconception in the room — that replication *is* the DR
story.

---

## 0. Pre-flight (before the session)

```bash
cd code-examples/demos/module-8-dr
./up.sh        # 9 containers: 3 ZK (m8-zk1..3) + 6 CH (m8-s1r1 … m8-s3r2)
./run.sh       # setup → 1M rows → six destructive drills, in order
```

- `up.sh` tears down peer demo modules (ports collide). Run M3/M4/M5
  *before* this, not alongside.
- HTTP ports `8123–8128`, TCP `9000–9005`. Container map in README §11.
- **Do a full dry run the day before.** Drill 4 wipes a data volume; if
  Docker Desktop is low on disk or the alpine helper image isn't cached,
  you'll find out then and not in front of the room.
- Keep three panes ready: `docker ps` (watch containers drop and return),
  a client on the survivor `docker exec -it m8-s1r1 clickhouse-client`, and
  a client on the victim `docker exec -it m8-s1r2 clickhouse-client`.
- Script is destructive **only** to `default.dr_local` and `m8-` containers.
  Say that out loud — someone always asks.

**Timing budget (~75 min):** §1 framing + ladder 10m · §2 RTO/RPO 8m ·
drills 1–3 15m · **drill 4 (slow, narrated)** 15m · drill 5 10m ·
drill 6 8m · multi-DC 5m · runbook wrap 4m. Drop the multi-DC sketch first
if you're short; drop drill 3 second.

---

## 1. The defense ladder — the spine of the module (README §1) — ~10 min

README §1's seven-failure taxonomy is a great *reference* and a weak
*narrative*. For live delivery, invert it: build the defenses up one layer
at a time, and after each layer ask the room:

> **"What still kills us?"**

Their answer motivates the next rung. Walk the ladder table in README §1:

| Layer | What you add | Failure it kills | What it costs |
|---|---|---|---|
| 0 | single node | — | — |
| 1 | 2nd replica per shard | host / disk loss | 2× storage |
| 2 | `insert_quorum = 2` | *silent* redundancy loss on write | write availability |
| 3 | Keeper quorum across AZs | coordination loss | 3–5 more nodes |
| 4 | backups → S3 | human error, corruption, ransomware | cadence = your RPO |
| 5 | replicas in a 2nd DC | site loss | WAN latency on every write |

Two things to hammer while you climb:

- **Each rung is a purchase, not a best practice.** The right stopping
  point is a business decision (§2), not an engineering one.
- **The ladder is the running order of the demo.** Rungs 1–5 map 1:1 onto
  drills 1, 5, 3, 6 and the multi-DC sketch. Concept, then proof.

Then show the failure-mode flowchart as the *reference view* of the same
material — "this is the version you'll come back to at 3 a.m."

---

## 2. RTO / RPO — make them business numbers (README §2) — ~8 min

Don't define them abstractly. Define them by asking the room two questions:

1. *"If this cluster is down for four hours, who calls you?"*
2. *"If you lose the last fifteen minutes of writes, does anyone notice?"*

Once they've answered for their own systems, the ladder in §1 becomes a
**price list for buying those two numbers down**. That reframe is the whole
point of the section.

Then the honest correction most people need:

> *"A two-replica shard does **not** give you RPO=0. Replication is async.
> A host that dies with parts that never left it takes them with it."*

That sets up drill 5 as the fix, and it's the moment the room realises
layer 1 has a hole in it.

---

## 3. Drills 1–3 — build confidence fast (README §3–§5) — ~15 min

These three are cheap, they all recover cleanly, and their job is to make
the room comfortable with breaking things. Run them briskly.

- **Drill 1 (replica down):** the point is *nothing happens*. Show
  `errors_count` climbing in `system.clusters`, reads unaffected, inserts
  accepted. Then `docker start` + `SYSTEM SYNC REPLICA` and watch
  `absolute_delay` fall to 0.
- **Drill 2 (whole shard down):** the teaching point is that
  `skip_unavailable_shards` is a **per-query policy decision, not a
  setting you turn on**. Line: *"Stale-and-visible beats blank on a
  dashboard. It's malpractice on a financial report."*
- **Drill 3 (lose one ZK node):** the point is what *doesn't* break.
  Quorum is 2 of 3, so writes sail through.

**The correction to make here** — people conflate "cluster is down" with
"data is at risk":

> *"Losing Keeper quorum blocks writes and loses **nothing**. Read-only is a
> safety property, not damage."*

---

## 4. 🔥 Drill 4 — replica disk loss (README §6) — ~15 min

**This is the best moment in the module. Slow all the way down and narrate
every step.** Don't let `run.sh` blow through it — step it by hand.

The principle to name before you touch anything:

> **Keeper owns membership. Disk owns data.**

A wiped replica is those two sources of truth disagreeing. Everything in
the recovery follows from that:

1. The disk is empty, so the node has no parts.
2. Keeper still holds a full replica record — queue entries, log pointer,
   the works — that describes a node which no longer exists.
3. Restarting the node just re-asserts the stale record. **This is the
   mistake to avoid**, and it's worth *doing* live so they see it fail.
4. `SYSTEM DROP REPLICA 'm8-s1r2' FROM TABLE dr_local` from the **peer**
   deletes the membership record. Note the "from a peer" part — a dead
   node can't evict itself.
5. Recreate the table pointing at the same ZK path → it registers as a
   fresh replica → `SYSTEM SYNC REPLICA` → parts stream over `:9009`.

Walk the sequence diagram while the sync runs, and watch the queue drain in
another pane:

```sql
SELECT queue_size, absolute_delay, is_readonly FROM system.replicas
WHERE table = 'dr_local';
```

**Why this matters beyond the drill:** once they hold *membership vs. data*,
half the "stuck replica" incidents in their career explain themselves.
`SYSTEM DROP REPLICA` + recreate is the single highest-value command in the
module.

---

## 5. Drill 5 — `insert_quorum`, the intellectual heart (README §7) — ~10 min

This is where the tradeoff stops being a slide and becomes an error code.

Frame it as the choice they are *already* making by default, whether or not
they know it:

> **"Do you want a failed write, or a silent loss of redundancy?"**

Sequence: set `insert_quorum = 2`, insert with both replicas up (fast),
`docker stop m8-s1r2`, run the identical INSERT, and let the room watch it
hang for the full three seconds before it dies with:

```
Code: 319. Quorum for previous write has not been satisfied yet.
```

Don't rush the three seconds of silence — that pause *is* the lesson.

Then the closing line: *"RPO=0 costs you write availability. That's CAP,
and ClickHouse lets you pick it per table. So pick it per table — quorum on
the ledger, no quorum on the clickstream."*

---

## 6. Drill 6 — restore from backup (README §8) — ~8 min

Callback time: *"Everything so far protected us from hardware. Now we do
the one replication makes **worse**."*

Run `BACKUP`, then `DROP TABLE … ON CLUSTER SYNC` — let the room feel the
drop propagate to all six nodes — then `RESTORE`.

Be upfront about the demo's limitation rather than hiding it: `BACKUP ON
CLUSTER` to a node-local disk needs the path on every node, and these
containers don't share `/tmp`, so the script prints the expected "use S3"
pointer. That limitation is itself the lesson — **cluster backups belong in
object storage** (Module 7).

If you have time, show README §9 (broken parts → `detached/`): the
`ALTER TABLE … DROP DETACHED PART` + `SYSTEM SYNC REPLICA` path is a nice
mini-callback to layer 1 doing the repair.

---

## 7. Multi-DC (README §10) — ~5 min

Whiteboard only — one Docker host can't drill it. Show the topology diagram
and land four points:

1. One replica per DC per shard; **replication is the cross-DC link**.
2. **Keeper quorum must span three sites** (2 DCs + observer), or a single
   DC outage takes quorum with it.
3. `insert_quorum = 2` across a WAN means **every INSERT pays the RTT**.
4. Failover is a **DNS/GLB flip plus drain** — 30–120 s of TTL, not zero.

Line: *"Multi-DC is a planning project, not a configuration."*

---

## 8. Wrap — the runbook is the deliverable (README §13) — ~4 min

Recap by climbing the ladder one more time in 60 seconds, then put §13 on
screen and end on:

> *"Practise this monthly. The runbook you've never run is fiction."*

The takeaway is not the commands. It's that everything they just watched is
only useful because it was rehearsed. Hand them README §12 (operational SQL
cheatsheet) as the "take this to work" artifact.

---

## Questions to pre-load

| Question | Short answer |
|----------|--------------|
| Isn't replication a backup? | No. It replicates your mistakes at wire speed. Replication = hardware loss; backups = human + software loss. |
| Do 2 replicas give me RPO=0? | Not on their own — replication is async. `insert_quorum = 2` is what closes the gap. |
| What breaks when Keeper loses quorum? | Writes and DDL stall; replicated tables go read-only. Nothing is lost, and reads keep serving. |
| Why can't I just restart a wiped replica? | Keeper still holds its old membership record. Evict it from a peer with `SYSTEM DROP REPLICA`, then recreate. |
| Can a dead node drop its own replica record? | No — run `SYSTEM DROP REPLICA` from a surviving peer. |
| Is `skip_unavailable_shards` safe to leave on? | It's a per-query policy. Fine for dashboards, wrong for anything that must be complete. |
| `insert_quorum` on every table? | No. It buys RPO=0 with write availability. Use it where a lost row costs money. |
| How often should we back up? | Your cadence *is* your RPO for the bad-DROP case. Pick the number the business can absorb, then meet it. |
| Why did the cluster backup only half work in the demo? | `BACKUP ON CLUSTER` to a node-local path needs that path on every node. Use S3/GCS — Module 7. |
| How do we know DR works? | You don't, until you've run it. Monthly game day, drills 1–6, timed against your stated RTO. |
