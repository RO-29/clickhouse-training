# 🔧 Module 2: Table Engines & Data Modeling

## Table Engines Overview

> A **table engine** defines how data is stored, accessed, and processed. Choice of engine determines performance characteristics.

### Engine Categories

```
┌────────────────────────────────────┐
│      TABLE ENGINES                 │
├────────────────────────────────────┤
│ OLAP (Analytical)                  │
├────────────────────────────────────┤
│ • MergeTree (⭐ primary)           │
│ • ReplicatedMergeTree              │
│ • SummingMergeTree                 │
│ • AggregatingMergeTree             │
└────────────────────────────────────┘
```

---

## 1. MergeTree Family

### MergeTree (Base Engine)
Best for **immutable, time-series data**

```sql
CREATE TABLE metrics (
    timestamp DateTime,
    metric_name String,
    value Float64,
    tags Map(String, String)
) ENGINE = MergeTree()
ORDER BY (timestamp, metric_name)
PARTITION BY toYYYYMM(timestamp)
SETTINGS index_granularity = 8192;
```

**Key Settings:**
- `ORDER BY`: Primary key columns (required)
- `PARTITION BY`: Partitioning strategy
- `index_granularity`: Data block size (default 8192)
- `max_bytes_before_merge`: Trigger merges

### ReplicatedMergeTree
**High Availability version**

```sql
CREATE TABLE events ON CLUSTER 'my_cluster' (
    id UInt64,
    event String,
    timestamp DateTime
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/events',
    '{replica}'
)
ORDER BY timestamp
PARTITION BY toDate(timestamp);
```

**Parameters:**
- `zookeeper_path`: ZooKeeper coordination path
- `replica_name`: Unique replica identifier

---

## 2. Specialized MergeTree Engines

### SummingMergeTree
Auto-aggregates on merge (sum numeric columns)

```sql
CREATE TABLE daily_stats (
    date Date,
    user_id UInt32,
    page_views UInt64,
    revenue Float64
) ENGINE = SummingMergeTree((page_views, revenue))
ORDER BY (date, user_id)
PARTITION BY date;
```

**Use Case:** Pre-aggregated metrics

### AggregatingMergeTree
Stores aggregate states for incremental computation

```sql
CREATE TABLE agg_metrics (
    timestamp DateTime,
    metric_name String,
    value AggregateFunction(avg, Float64)
) ENGINE = AggregatingMergeTree()
ORDER BY (timestamp, metric_name)
PARTITION BY toYYYYMM(timestamp);
```

**Use Case:** Complex rolling aggregations

### ReplacingMergeTree
Handles updates/deletes (keeps latest version)

```sql
CREATE TABLE user_updates (
    user_id UInt32,
    name String,
    email String,
    version UInt32
) ENGINE = ReplacingMergeTree(version)
ORDER BY user_id
PARTITION BY toYYYYMM(now());
```

### GraphiteMergeTree
Optimized for Graphite/Prometheus metrics

```sql
CREATE TABLE graphite (
    Path String,
    Time UInt32,
    Value Float64,
    Version UInt32
) ENGINE = GraphiteMergeTree(config)
ORDER BY (Path, Time);
```

---

## Table Engine Comparison

| Engine | Sorting | Aggregation | Updates | Replication | Best For |
|--------|---------|-------------|---------|-------------|----------|
| **MergeTree** | ✓ | Manual | ✗ | ✗ | General analytics |
| **ReplicatedMergeTree** | ✓ | Manual | ✗ | ✓ | HA deployments |
| **SummingMergeTree** | ✓ | Auto | ✗ | ✗ | Metrics aggregation |
| **AggregatingMergeTree** | ✓ | States | ✗ | ✗ | Complex aggregates |
| **ReplacingMergeTree** | ✓ | Manual | ✓ | ✗ | SCD Type 2 data |

---

## Other Engines

### Log Engines (Small datasets, <100M rows)

```sql
CREATE TABLE small_logs ENGINE = StripeLog;
CREATE TABLE temp_data ENGINE = Memory;
```

| Engine | Persistence | Concurrency | Use Case |
|--------|-------------|-------------|----------|
| **Log** | Disk | Limited | Temp data |
| **StripeLog** | Disk | Limited | Compression logs |
| **TinyLog** | Disk | No | Testing |
| **Memory** | RAM | Limited | Temp cache |

### Integration Engines

```sql
CREATE TABLE kafka_source ENGINE = Kafka(
    broker_list = 'kafka:9092',
    topic_list = 'events',
    group_id = 'clickhouse',
    format = 'JSONEachRow'
);

CREATE TABLE mysql_link ENGINE = MySQL(
    host = '127.0.0.1:3306',
    database = 'db',
    table = 'source_table',
    user = 'root',
    password = 'pass'
);
```

---

## Data Modeling Strategies

### 1. Denormalization
Store redundant data for query speed

```sql
CREATE TABLE order_analytics (
    order_id UInt64,
    order_date Date,
    customer_id UInt32,
    customer_name String,  -- Denormalized
    total_amount Decimal(12,2),
    items_count UInt16,
    category String  -- Denormalized
) ENGINE = MergeTree()
ORDER BY (order_date, customer_id);
```

### 2. Nested Arrays
Efficient for hierarchical data

```sql
CREATE TABLE events_nested (
    event_id UInt64,
    timestamp DateTime,
    attributes Nested(
        key String,
        value String
    )
) ENGINE = MergeTree()
ORDER BY timestamp;
```

### 3. Materialized Views (ETL Pipeline)
```sql
CREATE TABLE raw_logs ENGINE = MergeTree()
ORDER BY timestamp;

CREATE MATERIALIZED VIEW hourly_stats
ENGINE = SummingMergeTree()
ORDER BY (hour, status)
AS SELECT
    toStartOfHour(timestamp) as hour,
    status,
    count() as cnt
FROM raw_logs
GROUP BY hour, status;
```

---

## Best Practices ✅

| Practice | Example |
|----------|---------|
| **Single ORDER BY** | Not multiple; impacts compression |
| **Partition by time** | `PARTITION BY toYYYYMM(date)` |
| **Index granularity** | Set to 1000-8192 per data density |
| **TTL strategy** | `TTL date + INTERVAL 90 DAY` |
| **Denormalize wisely** | Only for frequently joined columns |
| **Use ReplicatedMT for HA** | Always in production |
| **Monitor merge stats** | Check `system.parts` table |
| **Set max_insert_threads** | For parallel inserts |

---

## Quick Commands

```sql
-- Show all engines
SELECT * FROM system.table_engines;

-- View table structure
DESCRIBE table_name;

-- Check table parts
SELECT
    partition,
    count() as parts,
    formatReadableSize(sum(bytes)) as size
FROM system.parts
WHERE table = 'my_table'
GROUP BY partition;

-- Monitor merges
SELECT * FROM system.processes
WHERE query LIKE '%merge%';

-- Optimize table
OPTIMIZE TABLE my_table FINAL;

-- Disable TTL temporarily
ALTER TABLE my_table MODIFY SETTING min_bytes_for_part_consolidation_before_merge = '999999999999';
```

---

## Common Scenarios

### Scenario 1: Real-time Analytics
```sql
CREATE TABLE events_rt (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event_type String,
    value Float64
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/events',
    '{replica}'
)
ORDER BY (timestamp, user_id)
PARTITION BY toDate(timestamp);
```

### Scenario 2: Metrics Storage
```sql
CREATE TABLE metrics (
    timestamp DateTime,
    metric_name String,
    value Float64
) ENGINE = SummingMergeTree((value))
ORDER BY (timestamp, metric_name)
PARTITION BY toYYYYMM(timestamp);
```

### Scenario 3: Slowly Changing Dimensions
```sql
CREATE TABLE customers (
    customer_id UInt32,
    name String,
    version UInt32,
    effective_date Date
) ENGINE = ReplacingMergeTree(version)
ORDER BY customer_id
PARTITION BY toYYYYMM(effective_date);
```

---

## Next Steps

✓ Choose right engine for workload
✓ Design partitioning strategy
✓ Set up materialized views
→ **Module 3: Sharding Strategy**

---

*Last Updated: Jan 2026*
