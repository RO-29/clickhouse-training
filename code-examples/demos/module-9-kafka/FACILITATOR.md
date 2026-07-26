# Module 9 — Facilitator's guide (how to drive the live session)

> Companion to `README.md`. The README is the reference; this is the
> *script* for running Module 9 as a ~70-minute live training. Section
> numbers below map to README sections.

**The framing line for the whole module:**
> *"The Kafka engine is a **consumer**, not a table. It's a cursor over a
> topic, and reading it moves the cursor. Every surprising thing about Kafka
> in ClickHouse falls out of that one fact."*

**The sentence that does the most work** (say it early, call back to it three
times):
> *"`events_kafka` is not where your data is. It's a straw. The materialized
> view is the only thing catching what comes through it."*

The module is really an argument against three misconceptions, in order:
**it's a table** (§1), **the MV is just a view** (§3), and **Kafka gives you
exactly-once** (§6). Each one gets demolished by a live demo. Structure the
session around knocking them down rather than around the feature list.

---

## 0. Pre-flight (before the session)

```bash
cd code-examples/demos/module-9-kafka
./up.sh        # 4 containers: m9-clickhouse, m9-kafka, m9-zk, m9-kafka-ui
./run.sh       # topic → setup → extras → 100k good + 50 broken msgs → queries
```

- `up.sh` tears down peer demo modules (ports collide). Run this one alone.
- Ports: CH `8123`/`9000`, Kafka `9092` (host) / `29092` (in-network),
  **Kafka UI on `8080`**.
- **Open the Kafka UI in a browser tab before you start.** It's the single
  best visual aid in the module — topic, 3 partitions, both consumer groups,
  and lag, all live. Put it on screen next to the SQL client.
- Two panes: `docker exec -it m9-clickhouse clickhouse-client` and a shell
  for `docker exec m9-kafka kafka-consumer-groups …`.
- `produce.py` is pure stdlib — no pip install needed. `ROWS=500000 ./run.sh`
  if you want visible lag to talk over.

**Expect this, and don't mistake it for a broken demo:** `run.sh` sends 50
malformed messages into the *same* topic both consumers read. The strict
consumer (`events_kafka`, default error mode) chokes on the blocks that
contain them, so `events` / `events_unique` can finish **short of** `ROWS`
or stall outright, while `events_safe` reaches the full count and
`events_dlq` holds ~50. That gap between the two numbers is not a bug —
**it is the strongest argument in the module for the DLQ pattern**, so put
both counts on screen side by side and let the room notice.

**Timing budget (~70 min):** §1 12m · §2 8m · §3 10m · §4 8m · §5 12m ·
§6 10m · §7 5m · wrap 5m. Drop §7 (formats) first if you're short; §4 second
(its failure semantics get re-covered by §5 and §6 anyway).

---

## 1. "It's a consumer, not a table" (README §1) — ~12 min

Show the pipeline diagram, then **prove the claim before you explain it**:

```sql
SELECT * FROM m9.events_kafka LIMIT 5;   -- returns rows
SELECT * FROM m9.events_kafka LIMIT 5;   -- different rows. The first 5 are gone.
```

*"Those first five rows are not somewhere else. They are gone. You just ate
them off the topic and printed them to a terminal."*

This is the single most useful 90 seconds in the module — nearly everyone in
the room has a mental model of a table, and this breaks it on contact. Then
land the three rules:

1. **Never `SELECT` from a Kafka table** except `LIMIT 1` for diagnosis.
2. **The MV is the durability boundary.** (You'll prove this in §3.)
3. **One source can feed N MVs** — one read of the topic, many writes.

---

## 2. The source table's settings (README §2) — ~8 min

Don't read the whole table out loud. Group the settings by the question they
answer, and cover four:

- **Who am I?** — `kafka_group_name`. **Treat it like a database name.**
  It's persistent state living in Kafka, not in ClickHouse. Change it and
  you either replay from the beginning or skip to the end.
- **How fast?** — `kafka_num_consumers`, `kafka_max_block_size`,
  `flush_interval_ms` / `flush_on_rows` in the server `<kafka>` block.
- **What shape?** — `kafka_format` (§7).
- **What about bad data?** — `kafka_skip_broken_messages` vs.
  `kafka_handle_error_mode` (§5, the headline).

**The trap worth naming here** (it's a callback to Module 2):

> *"A too-small `kafka_max_block_size` and a busy topic gives you millions of
> tiny parts, and then your problem isn't Kafka — it's merges. The batching
> knobs are a parts-management decision wearing a streaming costume."*

---

## 3. 🔥 The MV is the durability boundary (README §3) — ~10 min

The headline demo of the first half. Do it live:

```sql
SELECT count() FROM m9.events;      -- note the number
DROP TABLE m9.events_mv;            -- the "harmless" drop
```

Now produce more messages from the other pane:

```bash
python3 produce.py --rows 1000 | docker exec -i m9-kafka \
    kafka-console-producer --bootstrap-server localhost:9092 --topic events
```

Wait ~8 s, then:

```sql
SELECT count() FROM m9.events;   -- unchanged
```

Then show in the Kafka UI (or via `kafka-consumer-groups --describe`) that
`ch_consumer`'s **offsets still advanced**. The messages were consumed and
dropped on the floor.

> *"Nothing errored. Nothing alerted. Kafka is happy — it got its commits.
> You lost a thousand rows and the only evidence is a number that didn't
> change."*

Recreate the MV from `setup.sql` and note that the lost window does **not**
come back without an offset reset. Then the constructive half — the second
MV (`events_per_minute_mv`) fanning out from the same source: one read, two
writes, and the pre-aggregation is free.

---

## 4. End-to-end flow and failure semantics (README §4) — ~8 min

Walk the sequence diagram once, slowly, and land the key structural fact:

> **The block is the unit of work, the unit of failure, and the unit of
> offset commit.**

Everything downstream follows from it — one bad message poisons a block of
good ones (§5), and a crash mid-block means the offsets were never committed
so the whole block is redelivered (§6). Say explicitly: *"the duplicates in
§6 and the poison pill in §5 are the same fact seen from two angles."*

---

## 5. 🔥 DLQ — `kafka_handle_error_mode = 'stream'` (README §5) — ~12 min

The headline demo of the second half, and the one they'll actually take to
work.

Put the two counts on screen together — this is the payoff for the pre-flight
note above:

```sql
SELECT 'events (strict)' AS pipeline, count() FROM m9.events
UNION ALL
SELECT 'events_safe (stream mode)', count() FROM m9.events_safe
UNION ALL
SELECT 'events_dlq', count() FROM m9.events_dlq;
```

Same topic, same messages, two consumer groups, **two very different
outcomes**. Then show what the DLQ actually caught:

```sql
SELECT error, raw, topic, partition, offset FROM m9.events_dlq LIMIT 5;
```

Points to land:

- The default mode fails the **whole block** — good messages die with the bad
  one. At 1M rows per block that's a rough trade.
- `'stream'` mode doesn't skip anything; it **moves the decision into SQL**.
  `WHERE _error = ''` and `WHERE _error != ''` are two MVs over one source.
- The DLQ row keeps `_topic` / `_partition` / `_offset`, so you can go back
  to the exact message, fix the producer, and replay.
- `kafka_skip_broken_messages = N` is the cheap version: it discards bad
  messages and tells you nothing. **Fine for a prototype, never for
  production** — you can't fix a producer you can't see.

Line to close on: *"Every streaming pipeline eventually meets a message it
can't parse. You get to choose whether that's an outage or a row in a table."*

---

## 6. Exactly-once is a property of the *destination* (README §6) — ~10 min

State the correction bluntly, because most rooms have it backwards:

> *"Kafka gives you at-least-once. ClickHouse doesn't add a transaction on
> top. You don't get exactly-once from the source — you build it in the
> destination by making redelivery **harmless**."*

Show `events_unique` (`ReplacingMergeTree(ingested_at)` ordered by
`(user_id, event_time)`) and the count with and without `FINAL`. Then the
part people get wrong in production:

- **The dedup key must be stable across retries.** A redelivered message must
  produce the *same* key, which means it comes from the producer's natural
  key — never `now()`, never a random ID generated on ingest.
- **`ORDER BY` is the dedup key.** Dedup happens within a partition, at merge
  time — so it's eventual, and `FINAL` is what makes it immediate-but-slower.
- The three-row table in README §6 is the decision aid: plain MergeTree
  (fastest, duplicates possible), ReplacingMergeTree (dedup on read/merge),
  AggregatingMergeTree with idempotent aggregates (duplicates absorbed).

If you want a memorable demo: replay the topic and watch the counts.

```bash
docker exec m9-kafka kafka-consumer-groups --bootstrap-server localhost:9092 \
    --group ch_consumer --reset-offsets --to-earliest --topic events --execute
```

(Kafka refuses to reset a group that still has an active consumer, and
`ch_consumer` stays active while *any* of its three MVs is attached — so
`DETACH` all of `events_mv`, `events_per_minute_mv` and `events_unique_mv`,
reset, then `ATTACH` all three. Detaching only one won't do it.) After
the replay, `events` has roughly doubled and `events_unique FINAL` has not.
**That side-by-side is the whole section in one screen.**

---

## 7. Formats (README §7) — ~5 min

Fast pass, decision-oriented — this is the section to cut if you're behind.

- `JSONEachRow` — the default answer. Flexible, self-describing, and you pay
  for it in parse CPU.
- `CSV` / `TabSeparated` — faster, no nesting, brittle to column changes.
- `Protobuf` / `Avro` / `AvroConfluent` — **the production answer at volume**.
  Compact, typed, and the schema is enforced at the edge instead of
  discovered in your DLQ.

Mention that schema-bound formats need the schema mounted under
`/var/lib/clickhouse/format_schemas/` and that `AvroConfluent` speaks the
Schema Registry magic-byte protocol. Line: *"JSON is how you start. A schema
registry is how you stop having a DLQ problem."*

---

## 8. Wrap — operational ergonomics (README §8, §10–§11) — ~5 min

The "take this to work" close. Three tools, 30 seconds each:

```sql
-- Who's assigned to what, and where are we?
SELECT database, table, consumer_id, assignments.topic,
       assignments.partition_id, assignments.current_offset
FROM system.kafka_consumers ARRAY JOIN assignments WHERE database = 'm9';

-- Pause and resume without losing your place
DETACH TABLE m9.events_mv;
ATTACH TABLE m9.events_mv;
```

```bash
docker exec m9-kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 --group ch_consumer --describe
```

**The correction to make here:** *"Lag is a Kafka number, not a ClickHouse
number. `system.kafka_consumers` tells you where your consumer is;
only the broker knows how far behind that is."*

End on the §11 tuning-by-goal table — throughput, latency, bad-message
tolerance, and no-loss are **four different configurations**, and nobody gets
all four.

**The one-sentence trap to leave them with:**
> *"The Kafka engine will happily consume your entire topic into a table
> nobody is writing to, commit the offsets, and report perfect health.
> Monitor the destination row count, not the consumer."*

---

## Questions to pre-load

| Question | Short answer |
|----------|--------------|
| Can I just query the Kafka table? | Only `LIMIT 1` for diagnosis. A SELECT consumes and discards — the rows don't go to your MergeTree. |
| What happens if I drop the MV? | Consumption continues, offsets keep committing, rows go nowhere. Silent data loss with no error. |
| Two MVs on one Kafka table — does it read the topic twice? | No. One read, one block, both MVs fire from it. |
| How do I scale ingest? | `kafka_num_consumers`↑ (bounded by partitions), then more CH nodes in the *same* consumer group. |
| Can two ClickHouse clusters read the same topic? | Yes — different `kafka_group_name` per cluster, independent offsets. Same group = they split the partitions. |
| Does ClickHouse give exactly-once? | No. Kafka is at-least-once; you make redelivery harmless with `ReplacingMergeTree` on a producer-stable key. |
| Why is `events` short of the row count but `events_safe` isn't? | The strict consumer's blocks contain the 50 malformed messages and keep failing. That's §5's whole point. |
| `kafka_skip_broken_messages` or DLQ? | Skip for prototypes — it discards silently. DLQ for production — you can't fix a producer you can't see. |
| How do I replay? | Stop the consumer (`DETACH` the MVs), `kafka-consumer-groups --reset-offsets`, `ATTACH`. Expect duplicates unless you dedupe. |
| How do I pause ingest for maintenance? | `DETACH TABLE <mv>`. Offsets stay put; `ATTACH` resumes from the last commit. |
| Where do I see lag? | `kafka-consumer-groups --describe` on the broker, or the Kafka UI. `system.kafka_consumers` gives position, not lag. |
