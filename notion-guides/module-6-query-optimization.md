# 🚀 Module 6: Query Optimization & Performance

> **Key Goal:** Write efficient queries, reduce resource consumption, and maximize throughput

## Architecture Overview

```
Query Submission
      ↓
Parser & Optimizer
      ↓
Execution Planner
      ↓
Distributed Execution (Shards)
      ↓
Aggregation & Result
```

---

## 🎯 Core Optimization Principles

### Query Execution Flow
- **Parsing**: Syntax validation
- **Optimization**: Plan optimization, predicate pushdown
- **Execution**: Distributed processing on shards
- **Aggregation**: Merge results from replicas

### Key Metrics to Monitor
| Metric | Threshold | Action |
|--------|-----------|--------|
| Query Time | > 10s | Check WHERE clause, indexing |
| Memory Usage | > 80% | Optimize GROUP BY cardinality |
| CPU Usage | > 90% | Consider sharding or sampling |
| Disk I/O | Peak hours | Adjust merge policies |

---

## ⚡ Optimization Techniques

### 1️⃣ WHERE Clause Optimization
```sql
-- ❌ Bad: Full scan
SELECT * FROM events WHERE year(timestamp) = 2024;

-- ✅ Good: Partition pruning
SELECT * FROM events WHERE timestamp >= '2024-01-01'
  AND timestamp < '2025-01-01';
```

**Best Practices:**
- Use partition key directly (avoid functions)
- Apply date ranges explicitly
- Add sharding key conditions early

### 2️⃣ Aggregation Optimization
```sql
-- ❌ Bad: High cardinality
SELECT DISTINCT url FROM events LIMIT 1000000;

-- ✅ Good: Pre-aggregation
SELECT uniq(url) FROM events SAMPLE 0.1;
```

**Techniques:**
- Use sampling for cardinality estimation
- Enable `distributed_group_by_memory_usage_ratio`
- Consider two-level aggregation

### 3️⃣ JOIN Optimization
```sql
-- ❌ Bad: Large distributed join
SELECT * FROM events e
  JOIN users u ON e.user_id = u.id;

-- ✅ Good: Local join with replicated table
SELECT * FROM events e
  JOIN users_dict u ON e.user_id = u.id;
```

**Strategies:**
- Use ASOF JOIN for time-series
- Replicate small tables via `ReplicatedMergeTree`
- Use `ANY` instead of `ALL` when possible

### 4️⃣ Data Type Optimization
```sql
-- ❌ Bad: String storage
CREATE TABLE logs (
  id String,
  level String,
  value String
) ENGINE = MergeTree();

-- ✅ Good: Optimized types
CREATE TABLE logs (
  id UInt32,
  level Enum8('DEBUG'=1, 'INFO'=2, 'ERROR'=3),
  value Float32
) ENGINE = MergeTree();
```

| Type | Size | Use Case |
|------|------|----------|
| String | Variable | Unlimited text |
| FixedString(N) | N bytes | URLs, tokens |
| Enum8/16 | 1-2 bytes | Status, categories |
| LowCardinality(T) | Variable | < 10K unique values |
| Decimal(P, S) | Variable | Financial data |

### 5️⃣ Index Strategy
```sql
-- Primary key index (every query should use)
CREATE TABLE metrics (
  timestamp DateTime,
  host String,
  metric_name String,
  value Float64
) ENGINE = MergeTree()
ORDER BY (timestamp, host, metric_name);

-- Secondary indices (for quick filtering)
ALTER TABLE metrics ADD INDEX idx_host host TYPE set(0);
ALTER TABLE metrics ADD INDEX idx_name metric_name TYPE bloom_filter;
```

**Index Types:**
- `set`: Exact match, HashSet
- `bloom_filter`: Probabilistic for high cardinality
- `tokenbf_v1`: Text search with Bloom filter
- `minmax`: Range queries

---

## 🔧 Performance Tuning Settings

### Session-Level Configuration
```sql
-- Sampling (10% of data)
SET max_rows_to_read = 1000000000;
SET max_bytes_to_read = 10737418240;

-- Distributed query settings
SET distributed_group_by_memory_usage_ratio = 0.5;
SET prefer_localhost_replica = 1;
SET max_parallel_replicas = 3;

-- Aggregation settings
SET group_by_overflow_mode = 'break';
SET max_bytes_in_join = 1024000000;
```

### Server-Level Configuration (config.xml)
```xml
<query_volume_limits>
  <max_query_size>262144</max_query_size>
  <max_execution_time>600</max_execution_time>
</query_volume_limits>

<profile>default_profile
  <max_memory_usage>10737418240</max_memory_usage>
  <compression codec="LZ4"></compression>
</profile>
```

---

## 📊 Profiling & Analysis

### Query Analysis Commands
```sql
-- Execution plan
EXPLAIN SELECT * FROM events WHERE timestamp > now() - INTERVAL 1 DAY;

-- Full profiling
EXPLAIN PLAN SELECT COUNT(*) FROM events
  WHERE timestamp > now() - INTERVAL 1 DAY
  GROUP BY toDate(timestamp);

-- Statistics
SELECT * FROM system.query_log
  WHERE event_date = today()
  ORDER BY query_duration_ms DESC
  LIMIT 10;
```

### System Tables for Monitoring
| Table | Purpose |
|-------|---------|
| `system.query_log` | Query execution history |
| `system.processes` | Running queries |
| `system.parts` | Table parts info |
| `system.merges` | Active merge operations |
| `system.replica_delays` | Replication lag |

---

## ✅ Best Practices Checklist

- ✓ Always use WHERE clause with partition key
- ✓ Set appropriate `FINAL` modifier only when needed
- ✓ Use sampling for large cardinality estimates
- ✓ Monitor `system.query_log` regularly
- ✓ Use PREWHERE for early filtering
- ✓ Avoid SELECT *; specify columns
- ✓ Use approximate functions when exact not needed
- ✓ Enable query result caching for repeating queries
- ✓ Schedule heavy queries during off-peak hours
- ✓ Review slow query log weekly

---

## 🎓 Quick Reference

**Common Commands:**
```bash
clickhouse-client --query "SELECT count() FROM table FINAL;"
clickhouse-client --max_rows_to_read=1000000 < query.sql
clickhouse-client --profile=production < batch_query.sql
```

**Useful Functions:**
- `PREWHERE` - Early column filtering
- `SAMPLE` - Approximate query execution
- `arrayJoin()` - Flatten arrays before join
- `uniq()` / `uniqCombined()` - Cardinality estimation
- `quantile()` - Percentile approximation

---

**Last Updated:** 2026-01-22 | **Module:** 6/10 | **Difficulty:** Intermediate
