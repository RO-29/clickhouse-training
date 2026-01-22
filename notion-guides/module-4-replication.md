# 🔄 Module 4: Replication & High Availability

## Replication Fundamentals

> **Replication** maintains identical data copies across multiple servers. If one fails, others continue serving queries.

### Replication Flow

```
Client Write Request
        ↓
    Primary Replica
        ↓
    Write to Disk
        ↓
    ZooKeeper Coordination
        ↓
    Async Replicas
    ├─ Replica 1 (apply)
    ├─ Replica 2 (apply)
    └─ Replica 3 (apply)
        ↓
    Acknowledgment to Client
```

---

## Architecture Components

### 1. ZooKeeper (Mandatory for Replication)

| Component | Role |
|-----------|------|
| **Metadata Store** | Tracks replica state, mutations |
| **Consensus** | Ensures consistency |
| **Failover** | Automatic replica switchover |
| **Queue Management** | Tracks pending operations |

### 2. Replica States

```
Ready
  ↓
Catching Up → Ready (if behind)
  ↓
Dead (no heartbeat)
  ↓
Lost (data corruption)
```

---

## Setup: ReplicatedMergeTree

### Configuration

#### config.xml - ZooKeeper Settings
```xml
<clickhouse>
    <zookeeper>
        <node>
            <host>zk1.example.com</host>
            <port>2181</port>
        </node>
        <node>
            <host>zk2.example.com</host>
            <port>2181</port>
        </node>
        <node>
            <host>zk3.example.com</host>
            <port>2181</port>
        </node>
    </zookeeper>
</clickhouse>
```

### Create Replicated Table

#### Shard 1, Replica 1
```sql
CREATE TABLE events ON CLUSTER my_cluster (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event String,
    value Float64
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/events',  -- ZK path
    'replica-1'                             -- replica name
)
ORDER BY (timestamp, user_id)
PARTITION BY toYYYYMM(timestamp);
```

#### Shard 1, Replica 2
```sql
CREATE TABLE events ON CLUSTER my_cluster (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event String,
    value Float64
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/events',  -- Same ZK path!
    'replica-2'                             -- Different name
)
ORDER BY (timestamp, user_id)
PARTITION BY toYYYYMM(timestamp);
```

---

## Replication Patterns

### Pattern 1: Write to Any Replica (Active-Active)

```sql
-- Any replica can accept writes
INSERT INTO events VALUES (...);

-- Automatic sync to other replicas via ZooKeeper
```

**When to Use:** Applications without routing
**Trade-off:** Slight latency for cross-shard commits

### Pattern 2: Write to Primary Only (Active-Passive)

```sql
-- Application routes writes to primary
INSERT INTO replicated_events VALUES (...)
  SETTINGS insert_quorum = 2;  -- Wait for majority

-- Reads from any replica
SELECT * FROM replicated_events WHERE ...;
```

**When to Use:** Strict consistency requirement
**Trade-off:** All writes go to one node

### Pattern 3: Kafka as Source (Distributed Writes)

```sql
CREATE TABLE kafka_events ENGINE = Kafka(...)
SETTINGS kafka_format = 'JSONEachRow';

CREATE MATERIALIZED VIEW sync_to_ch
ENGINE = ReplicatedMergeTree(...)
AS SELECT * FROM kafka_events;
```

**When to Use:** External message queue already used
**Benefit:** Decoupled from database writes

---

## Replication Settings

### Critical Settings

```sql
-- Ensure consistency
INSERT INTO table VALUES (...)
SETTINGS
    insert_quorum = 2,              -- Wait for N replicas
    insert_quorum_timeout_ms = 5000, -- Timeout
    select_sequential_consistency = 1; -- Strict reads

-- For large inserts
SETTINGS
    distributed_directory_monitor_batch_inserts = 1,
    max_insert_threads = 4;
```

### Advanced Replication Settings

| Setting | Default | Purpose |
|---------|---------|---------|
| `replicated_can_become_leader` | 1 | Can become primary |
| `replicated_deduplication_window_seconds` | 604800 | Dedupe window (7 days) |
| `replicated_deduplication_window_size_mb` | 5000 | Dedupe by size |
| `max_replica_delay_for_distributed_queries` | 300 | Max replica lag (sec) |

---

## Monitoring Replication

### Check Replica Status
```sql
SELECT
    database,
    table,
    replica_path,
    replica_name,
    is_leader,
    absolute_delay,
    relative_delay
FROM system.replicas;
```

### Monitor Replication Queue
```sql
SELECT
    database,
    table,
    replica_name,
    position,
    operation,
    source_replica
FROM system.replication_queue
ORDER BY database, table;
```

### View Replica Lag
```sql
SELECT
    database,
    table,
    replica_name,
    absolute_delay,
    formatReadable(absolute_delay) as delay_pretty
FROM system.replicas
WHERE absolute_delay > 0;
```

### Queue Processing Rate
```sql
SELECT
    database,
    table,
    sum(1) as queue_length,
    max(position) as max_position
FROM system.replication_queue
GROUP BY database, table;
```

---

## Failover Scenarios

### Scenario 1: Replica Goes Down

```
State: 3 replicas (A, B, C)
Event: Replica C dies
├─ ZooKeeper detects (heartbeat timeout ~30s)
├─ Marks C as "Dead"
├─ A & B continue accepting writes
└─ When C recovers
    └─ Auto-syncs from queue
```

**Recovery:** Auto-replay, no manual intervention needed

### Scenario 2: Primary Fails

```
Before: A (primary), B, C (secondary)
Event: A loses connection
├─ ZooKeeper marks A "lost"
├─ B or C becomes primary (quorum needed)
├─ Clients redirect to new primary
└─ Old A rejoins as secondary
```

**How to Test:**
```bash
# Simulate failure
kill -9 clickhouse-server

# Monitor recovery
watch 'clickhouse-client -q "SELECT replica_name, absolute_delay FROM system.replicas"'
```

### Scenario 3: ZooKeeper Outage

```
If ZooKeeper down:
├─ Replicas continue serving queries ✓
├─ Replication PAUSES ✗
├─ Mutations FAIL ✗
└─ Data diverges until ZK back up
```

**Mitigation:** 3-node ZooKeeper cluster (fault-tolerant up to 1 failure)

---

## Handling Replication Issues

### Reset Replica (Dangerous!)
```sql
-- Clear replication state, resync from scratch
ALTER TABLE table_name CLEAR COLUMN column_name;
TRUNCATE TABLE table_name;
```

### Force Replica Resync
```bash
# On replica node, remove metadata
rm -rf /var/lib/clickhouse/data/database/table/replicas

# ClickHouse will auto-resync from other replicas
systemctl restart clickhouse-server
```

### Manually Force Sync
```sql
-- Execute on replica to force sync
SYSTEM SYNC REPLICA table_name;
```

---

## Best Practices ✅

| Practice | Reason |
|----------|--------|
| **3-node ZK cluster** | Fault tolerance (tolerate 1 failure) |
| **Max 2 replicas/shard** | Diminishing returns beyond 2 |
| **Set insert_quorum=2** | Prevents write divergence |
| **Monitor lag regularly** | Detect replication issues early |
| **Use DNS for replica discovery** | Simplifies scaling |
| **Async replication OK for analytics** | Write can succeed before replicas sync |
| **Document replica topology** | Keep disaster recovery playbook |
| **Test failover quarterly** | Ensure procedures work |

---

## Comparison: Replication Strategies

| Strategy | Consistency | Latency | Complexity | When |
|----------|-------------|---------|-----------|------|
| **Async (default)** | Eventually | Low | Low | Analytics |
| **Quorum writes** | Strong | Medium | Medium | Financial data |
| **Synchronous** | Strong | High | High | Critical ops |

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Replica stuck "catching up" | Network lag | Check network; increase timeout |
| ZK connection refused | ZK down/misconfigured | Verify config, restart ZK |
| "Not leader" on insert | Not primary replica | Route to leader |
| Replication lag growing | Slow replica | Check disk I/O, memory |
| Mutation failing | Queue issue | `SYSTEM FLUSH DISTRIBUTED` |

---

## Quick Commands

```sql
-- List all replicas
SHOW TABLES;

-- Check replica status
SELECT * FROM system.replicas;

-- Monitor queue depth
SELECT COUNT(*) FROM system.replication_queue;

-- Force leader election (dangerous)
SELECT CHALLENGE() FROM system.clusters;

-- Restart replication
SYSTEM DROP REPLICA 'replica-1' FROM TABLE table_name;
-- Then recreate the table

-- View replication metrics
SELECT * FROM system.metrics WHERE metric LIKE '%Replication%';
```

---

## Next Steps

✓ Set up 2+ replicas per shard
✓ Configure ZooKeeper cluster
✓ Test failover procedures
→ **Module 5: Full Cluster Deployment**

---

*Last Updated: Jan 2026*
