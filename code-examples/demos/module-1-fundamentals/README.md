# Module 1 — Fundamentals

**Goal:** see a real MergeTree table, its parts, partitions, and how merges
work. Two million synthetic rows is enough to make `system.parts` interesting
without slowing anyone down.

## Prereqs

Single-node stack running:

```bash
cd code-examples/docker
docker compose -f docker-compose-single.yml up -d
```

## Run

```bash
./run.sh
```

## What this proves

| Step                         | What you should see                                                                |
|------------------------------|------------------------------------------------------------------------------------|
| 3 sequential `INSERT`s       | 3 active parts in `system.parts` initially.                                       |
| Partition by `toYYYYMM`      | Parts grouped under `202601`, `202602`, `202603`.                                 |
| `OPTIMIZE TABLE … FINAL`     | Active part count drops; `bytes_on_disk` per part rises.                          |
| `system.tables`              | `primary_key` and `sorting_key` are both `event_time, user_id`.                   |
| `system.query_log`           | Date-range query reads <<< 2M rows because the PK is `event_time` first.          |

## Talking points to walk through live

1. **Why partition by month, not day?** Partitions are physical directories;
   too many = slow merges and metadata bloat. Days are fine for huge tables,
   months are usually right for tutorials.
2. **Sorting key vs primary key.** `ORDER BY` defines on-disk sort. `PRIMARY
   KEY` (when set) is a sparse index and *must be a prefix of ORDER BY*. We
   skipped `PRIMARY KEY` so ClickHouse used the whole sort key.
3. **`index_granularity = 8192`** = 1 mark per 8192 rows. The PK has one
   entry per mark, not per row. That's why PKs in ClickHouse are tiny.
4. **What `OPTIMIZE FINAL` is for.** Merges *do* happen automatically; this
   forces it for the demo. Don't routinely run it in production.

## Cleanup

```bash
docker exec -i clickhouse-single clickhouse-client --query "DROP DATABASE m1"
```
