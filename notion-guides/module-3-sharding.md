# 🌍 Module 3: Sharding Strategy & Distribution

## What is Sharding?

> **Sharding** horizontally partitions data across multiple servers. Each shard holds subset of data, enabling massive scale.

### Why Shard?

```
Single Node (100TB)          vs    Sharded Cluster (3x 40TB each)
├─ Query: 100s                      ├─ Query: 30s (3 parallel)
├─ Storage: Limited                 ├─ Storage: Unlimited
└─ No Fault Tolerance               └─ High Availability
```

---

## Distributed Table Architecture

### Full Distributed Query Flow

```
┌─────────────────────────────────────────────────┐
│         Client Application                      │
│   (Python, Go, Java, Web App, etc.)            │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼ Query: SELECT COUNT(*) FROM events WHERE user_id = 12345
┌─────────────────────────────────────────────────┐
│      Distributed Table (Virtual Layer)          │
│   - Calculate shard: cityHash64(12345) % 3     │
│   - Route query to appropriate shard(s)        │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼ Query routed to Shard 2
┌──────────────────────────────────────────────────────┐
│                    Shards Layer                      │
├──────────────────┬─────────────┬────────────────────┤
│   Shard 1        │   Shard 2   │   Shard 3          │
│  (user_id % 3=0) │(user_id%3=1)│  (user_id % 3=2)   │
│ ┌──────────────┐ │┌──────────┐ │ ┌──────────────┐  │
│ │ Local Table  │ ││Local Table│ │ │ Local Table  │  │
│ │ events_local │ ││events_local│ │ │ events_local │  │
│ │              │ ││           │ │ │              │  │
│ │ Data:        │ ││Data:      │ │ │ Data:        │  │
│ │ user 1,4,7...│ ││user 2,5,8 │ │ │ user 3,6,9.. │  │
│ └──────────────┘ │└──────────┘ │ └──────────────┘  │
└──────────────────┴─────────────┴────────────────────┘
                   │
                   ▼ Results collected
┌─────────────────────────────────────────────────┐
│         Query Coordinator / Aggregator          │
│   - Merges results from all queried shards     │
│   - Performs final GROUP BY / ORDER BY         │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼ Final result
┌─────────────────────────────────────────────────┐
│              Client Receives Result             │
└─────────────────────────────────────────────────┘
```

### Cluster with Replication

```
3 Shards × 2 Replicas = 6 Total Nodes

Shard 1 (33% of data):
  ┌─────────────────┐
  │ Node 1 (Rep A)  │ ← Primary
  │ events_local    │
  │ user_id % 3 = 0 │
  └─────────────────┘
          ↕ Sync
  ┌─────────────────┐
  │ Node 2 (Rep B)  │ ← Backup
  │ events_local    │
  │ user_id % 3 = 0 │
  └─────────────────┘

Shard 2 (33% of data):
  ┌─────────────────┐
  │ Node 3 (Rep A)  │
  │ events_local    │
  │ user_id % 3 = 1 │
  └─────────────────┘
          ↕ Sync
  ┌─────────────────┐
  │ Node 4 (Rep B)  │
  │ events_local    │
  │ user_id % 3 = 1 │
  └─────────────────┘

Shard 3 (33% of data):
  ┌─────────────────┐
  │ Node 5 (Rep A)  │
  │ events_local    │
  │ user_id % 3 = 2 │
  └─────────────────┘
          ↕ Sync
  ┌─────────────────┐
  │ Node 6 (Rep B)  │
  │ events_local    │
  │ user_id % 3 = 2 │
  └─────────────────┘

ZooKeeper:
  ┌─────────────────────────┐
  │  Coordination Layer     │
  │  - Leader election      │
  │  - Replication metadata │
  │  - Cluster state        │
  └─────────────────────────┘
```

## Sharding Architecture

```
┌─────────────────────────────────────────────────┐
│            Client / Application                  │
├─────────────────────────────────────────────────┤
│      Distributed Query Router                    │
│  (Calculate sharding key → route query)          │
├─────────────────────────────────────────────────┤
│  Shard 1     │  Shard 2     │  Shard 3         │
│  ┌─────────┐ │ ┌─────────┐ │ ┌─────────┐     │
│  │ Replica1│ │ │ Replica1│ │ │ Replica1│     │
│  │ Replica2│ │ │ Replica2│ │ │ Replica2│     │
│  └─────────┘ │ └─────────┘ │ └─────────┘     │
├─────────────────────────────────────────────────┤
│ ZooKeeper (Metadata & Coordination)             │
└─────────────────────────────────────────────────┘
```

---

## Sharding Key Distribution Visualization

### How Hash-Based Sharding Distributes Data

```
Sharding Function: cityHash64(user_id) % 3

User Data:
user_id: 1  → cityHash64(1) % 3  = 1 → Shard 2
user_id: 2  → cityHash64(2) % 3  = 2 → Shard 3
user_id: 3  → cityHash64(3) % 3  = 0 → Shard 1
user_id: 4  → cityHash64(4) % 3  = 1 → Shard 2
user_id: 5  → cityHash64(5) % 3  = 2 → Shard 3
user_id: 6  → cityHash64(6) % 3  = 0 → Shard 1
...

Distribution:
┌───────────────────────────────────────────────────────┐
│                    All Users                          │
└───────────────┬───────────────┬───────────────────────┘
                │               │
    ┌───────────┴───┐   ┌──────┴────────┐   ┌──────────┐
    │               │   │               │   │          │
    ▼               ▼   ▼               ▼   ▼          ▼
┌─────────┐   ┌─────────┐   ┌─────────┐
│ Shard 1 │   │ Shard 2 │   │ Shard 3 │
│ (33.3%) │   │ (33.3%) │   │ (33.3%) │
├─────────┤   ├─────────┤   ├─────────┤
│ user 3  │   │ user 1  │   │ user 2  │
│ user 6  │   │ user 4  │   │ user 5  │
│ user 9  │   │ user 7  │   │ user 8  │
│ user 12 │   │ user 10 │   │ user 11 │
│   ...   │   │   ...   │   │   ...   │
└─────────┘   └─────────┘   └─────────┘
```

### Even Distribution Check

```
Monitoring Shard Balance:

┌─────────┬──────────┬───────────┬──────────┐
│ Shard   │ Rows     │ Size      │ Balance  │
├─────────┼──────────┼───────────┼──────────┤
│ Shard 1 │ 33.5M    │ 2.4 GB    │ ✅ Good  │
│ Shard 2 │ 33.2M    │ 2.3 GB    │ ✅ Good  │
│ Shard 3 │ 33.3M    │ 2.4 GB    │ ✅ Good  │
└─────────┴──────────┴───────────┴──────────┘
Total: 100M rows, 7.1 GB

Variance: < 1% (Excellent)
```

---

## Query Execution Flow

### Single-Shard Query (Fast Path)

```
Query: SELECT * FROM events WHERE user_id = 12345

Step 1: Hash Calculation
┌────────────────────────────────┐
│ cityHash64(12345) % 3 = 1      │
│ Target: Shard 2 ONLY           │
└────────────────────────────────┘
           │
           ▼
Step 2: Route to Single Shard
┌─────────┐   ┌─────────┐   ┌─────────┐
│ Shard 1 │   │ Shard 2 │   │ Shard 3 │
│  (idle) │   │ ✅ Query│   │  (idle) │
└─────────┘   └────┬────┘   └─────────┘
                   │
                   ▼
Step 3: Execute on Single Shard
┌────────────────────────────────┐
│ Shard 2: Local Table Scan      │
│ - Scans ONLY user_id 12345     │
│ - Returns: 1,000 rows          │
└────────────────────────────────┘
           │
           ▼
Step 4: Return Results
┌────────────────────────────────┐
│ Client receives 1,000 rows     │
│ Latency: ~100ms (Single shard) │
└────────────────────────────────┘
```

### Multi-Shard Query (Scatter-Gather)

```
Query: SELECT event_type, COUNT(*) FROM events
       WHERE date >= '2026-01-01' GROUP BY event_type

Step 1: No Sharding Key Filter
┌────────────────────────────────┐
│ No user_id filter              │
│ → Broadcast to ALL shards      │
└────────────────────────────────┘
           │
           ▼
Step 2: Parallel Execution on All Shards
┌─────────┐   ┌─────────┐   ┌─────────┐
│ Shard 1 │   │ Shard 2 │   │ Shard 3 │
├─────────┤   ├─────────┤   ├─────────┤
│ ✅ Query│   │ ✅ Query│   │ ✅ Query│
│         │   │         │   │         │
│ Returns:│   │ Returns:│   │ Returns:│
│ click:  │   │ click:  │   │ click:  │
│   10K   │   │   11K   │   │   9K    │
│ view:   │   │ view:   │   │ view:   │
│   20K   │   │   19K   │   │   21K   │
└────┬────┘   └────┬────┘   └────┬────┘
     │             │             │
     └─────────────┴─────────────┘
                   │
                   ▼
Step 3: Coordinator Merges Results
┌────────────────────────────────┐
│ Aggregation on Coordinator     │
│ - click: 10K + 11K + 9K = 30K  │
│ - view: 20K + 19K + 21K = 60K  │
└────────────────────────────────┘
           │
           ▼
Step 4: Return Aggregated Results
┌────────────────────────────────┐
│ Client receives:               │
│ - click: 30,000                │
│ - view: 60,000                 │
│ Latency: ~1-2s (All shards)    │
└────────────────────────────────┘
```

### Query Performance Comparison

```
┌─────────────────────┬────────────────┬──────────────────┐
│ Query Type          │ Shards Queried │ Latency          │
├─────────────────────┼────────────────┼──────────────────┤
│ WITH user_id filter │ 1 shard        │ ~100ms  ✅ Fast  │
│ WITHOUT user_id     │ ALL shards     │ ~1-2s   ⚠️ Slower│
└─────────────────────┴────────────────┴──────────────────┘

Optimization: Always filter by sharding key when possible!
```

---

## Sharding Key Selection

### Key Characteristics

| Criteria | Good | Bad |
|----------|------|-----|
| **Distribution** | Even across shards | Skewed/hotspots |
| **Cardinality** | High (~millions) | Low (<1000) |
| **Stability** | Rarely changes | Frequently changes |
| **Queryability** | Commonly filtered | Rarely used |

### Common Sharding Keys

```
Option 1: User/Entity ID
├─ Hash: xxHash(user_id) % num_shards
├─ Good: High cardinality, stable
└─ Use: User analytics, profiles

Option 2: Time-based
├─ Distribution: Date/Week bucketing
├─ Good: Natural time partitioning
└─ Use: Time-series, logs

Option 3: Geographic
├─ Distribution: Country code, region
├─ Good: Regional compliance
└─ Use: Multi-region deployments

Option 4: Composite
├─ Distribution: country_code % shards
├─ Good: Business logic alignment
└─ Use: SaaS with tenants
```

### Hashing Function

```sql
-- Distribution function
intDiv(xxHash64(user_id), total_weight) % num_shards

-- Example with weights
intDiv(xxHash64(user_id), max_int) % 3  -- 3 shards
```

---

## Cluster Configuration

### config.xml Setup
```xml
<clickhouse>
    <remote_servers>
        <prod_cluster>
            <shard>
                <weight>1</weight>
                <replica>
                    <host>shard1-replica1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>shard1-replica2</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <weight>1</weight>
                <replica>
                    <host>shard2-replica1</host>
                    <port>9000</port>
                </replica>
            </shard>
        </prod_cluster>
    </remote_servers>
</clickhouse>
```

---

## Sharded Table Setup

### 1. Local Table (each shard)
```sql
-- On each shard node
CREATE TABLE events_local ON CLUSTER prod_cluster (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event String,
    value Float64
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/{cluster}/tables/{shard}/events_local',
    '{replica}'
)
ORDER BY (timestamp, user_id)
PARTITION BY toYYYYMM(timestamp);
```

### 2. Distributed Table (query interface)
```sql
-- On any node, acts as router
CREATE TABLE events ON CLUSTER prod_cluster AS events_local
ENGINE = Distributed(
    'prod_cluster',           -- cluster name
    default,                   -- database
    events_local,             -- local table
    intDiv(                   -- sharding key
        xxHash64(user_id),
        9223372036854775807
    ) % 3
);
```

---

## Query Patterns

### Pattern 1: Queries with Sharding Key (Fast ⚡)
```sql
-- Filters by sharding key → single shard
SELECT COUNT(*) FROM events
WHERE user_id = 12345 AND timestamp > now() - INTERVAL 7 DAY;

Result: Hits only 1 shard
Latency: ~100ms
```

### Pattern 2: Queries without Sharding Key (Scatter-Gather)
```sql
-- No sharding key filter → all shards
SELECT event, COUNT(*) FROM events
WHERE timestamp > now() - INTERVAL 7 DAY
GROUP BY event;

Result: All shards queried in parallel
Latency: ~1-2s (depends on data size)
```

### Pattern 3: Aggregation Queries
```sql
-- Two-level aggregation (shard + final)
SELECT
    toStartOfHour(timestamp) as hour,
    event,
    COUNT(*) as cnt
FROM events
WHERE timestamp > now() - INTERVAL 7 DAY
GROUP BY hour, event
ORDER BY cnt DESC;

Process:
1. Each shard groups locally
2. Coordinator merges results
```

---

## Resharding Strategy

### When to Reshard?
- Adding/removing shards
- Load imbalance detected
- Growth beyond single shard capacity

### Methods

**Option 1: Parallel Cluster (Zero-downtime)**
```
Old Cluster (2 shards)  →  New Cluster (3 shards)
1. Setup new cluster
2. Copy data with new sharding key
3. Switch routing in application
```

**Option 2: In-place Reshard**
```sql
-- Extract data
SELECT * FROM events INTO OUTFILE 'events.data' FORMAT Native;

-- Recreate with new shard count
DROP TABLE events;
-- Reconfigure with 3 shards
-- Reload data
```

**Option 3: Heavy-duty Tool**
```bash
# Using clickhouse-copier tool
clickhouse-copier --daemon \
    --config-dir /etc/clickhouse-server \
    --task-path /clickhouse/task_reshard
```

---

## Load Balancing

### Connection Pooling
```xml
<profiles>
    <default>
        <distributed_connections_pool_size>100</distributed_connections_pool_size>
        <distributed_directory_monitor_batch_inserts>true</distributed_directory_monitor_batch_inserts>
        <distributed_directory_monitor_sleep_time_ms>1000</distributed_directory_monitor_sleep_time_ms>
    </default>
</profiles>
```

### Weight-based Load Balancing
```xml
<remote_servers>
    <cluster>
        <shard>
            <weight>2</weight>  <!-- Gets 2x traffic -->
            <replica>
                <host>server1</host>
            </replica>
        </shard>
        <shard>
            <weight>1</weight>
            <replica>
                <host>server2</host>
            </replica>
        </shard>
    </cluster>
</remote_servers>
```

---

## Monitoring & Management

### Check Shard Status
```sql
SELECT
    shard_num,
    shard_weight,
    replica_num,
    host_name,
    is_local
FROM system.clusters
WHERE cluster = 'prod_cluster';
```

### Monitor Distributed Queries
```sql
SELECT
    query_id,
    initial_query_id,
    query,
    elapsed,
    read_rows,
    written_rows
FROM system.query_log
WHERE type = 'QueryFinish'
    AND query LIKE '%Distributed%'
ORDER BY event_time DESC
LIMIT 10;
```

### Imbalance Detection
```sql
SELECT
    shard_num,
    formatReadableSize(sum(bytes)) as size
FROM system.parts
GROUP BY shard_num;
```

---

## Best Practices ✅

| Practice | Details |
|----------|---------|
| **Even Sharding Key** | Use hash for uniform distribution |
| **3-5 Shards Optimal** | Scalability + operational simplicity |
| **Replicate Each Shard** | Min 2x replication for HA |
| **Monitor Imbalance** | Reshard if >30% variance |
| **Test Queries** | Profile scatter-gather vs single-shard |
| **Document Sharding** | Keep cluster topology documented |
| **Use DNS for failover** | Enables replica switching |

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| High latency | All shards queried | Add sharding key to filter |
| Hotspot shard | Skewed distribution | Rebalance or reshard |
| Query timeout | Large scatter-gather | Reduce time range or add filter |
| Uneven load | Poor sharding key | Choose better key, reshard |

---

## Next Steps

✓ Design sharding key strategy
✓ Configure multi-shard cluster
✓ Test shard distribution
→ **Module 4: Replication & High Availability**

---

*Last Updated: Jan 2026*
