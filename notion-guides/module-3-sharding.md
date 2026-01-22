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
