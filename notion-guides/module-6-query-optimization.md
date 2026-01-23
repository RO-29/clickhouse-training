# 🚀 Module 6: Query Optimization & Performance

> **Key Goal:** Write efficient queries, reduce resource consumption, and maximize throughput

## Architecture Overview

### Query Execution Pipeline (Parse → Optimize → Execute → Merge)

```
┌─────────────────────────────────────────────────────────────┐
│         QUERY EXECUTION PIPELINE DIAGRAM                    │
└─────────────────────────────────────────────────────────────┘

     📝 SQL Query String
             ↓
┌────────────────────────────┐
│   1️⃣  LEXER               │  Tokenize SQL into tokens
│   Time: ~1-2ms            │  "SELECT", "FROM", "WHERE", etc.
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│   2️⃣  PARSER              │  Build Abstract Syntax Tree (AST)
│   Time: ~2-3ms            │  Hierarchical query structure
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│   3️⃣  SEMANTIC ANALYSIS   │  Validate tables, columns, types
│   Time: ~5-10ms           │  Check permissions
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│   4️⃣  OPTIMIZATION        │  Rewrite for efficiency
│   Time: ~10-20ms          │  • Predicate pushdown
│                           │  • JOIN reordering
│                           │  • Partition pruning
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│   5️⃣  COMPILATION         │  JIT compile expressions
│   Time: ~10-50ms          │  • SIMD vectorization
│   (cached for reuse)      │  • Generate machine code
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│   6️⃣  EXECUTION           │  Run query against data
│   Time: Variable          │  • Read from disk/cache
│   (bulk of query time)    │  • Apply filters
│                           │  • Parallel processing
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│   7️⃣  MERGE RESULTS       │  Combine from all shards
│   Time: ~5-50ms           │  Final aggregation
└────────────┬───────────────┘
             ↓
        ✅ RESULT

Total: Parsing (10-30ms) + Execution (variable) + Merge (5-50ms)
```

### Index Utilization Flowchart

```
┌─────────────────────────────────────────────────────────────┐
│           INDEX UTILIZATION FLOWCHART                       │
└─────────────────────────────────────────────────────────────┘

          📝 Query: SELECT * FROM events
                 WHERE country = 'US'
                       ↓
          ┌────────────────────────┐
          │  Analyze WHERE Clause  │
          └──────────┬─────────────┘
                     ↓
     ┌───────────────┼───────────────┐
     ↓               ↓               ↓
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Primary Key │ │  Skipping   │ │  Partition  │
│   Check     │ │   Indexes   │ │   Pruning   │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       ↓               ↓               ↓
   Does WHERE     Has set/bloom    Filter by
   match ORDER    filter index?   partition key?
       BY?              ↓               ↓
       ↓          ┌─────┴─────┐   ┌────┴────┐
   ┌───┴───┐     │           │   │         │
   │  YES  │     │    YES    │   │   YES   │
   └───┬───┘     └─────┬─────┘   └────┬────┘
       ↓               ↓               ↓
   Range scan     Skip granules   Skip partitions
       │               │               │
       └───────────────┼───────────────┘
                       ↓
           ┌───────────┴───────────┐
           ↓                       ↓
    ┌──────────────┐        ┌─────────────┐
    │ ⚡ OPTIMIZED │        │ 🐌 SLOW     │
    │    PATH      │        │   PATH      │
    ├──────────────┤        ├─────────────┤
    │ Read 0.1%    │        │ Read 100%   │
    │ of table     │        │ of table    │
    │ 10-1000x     │        │ Full scan   │
    │ faster       │        │ Very slow   │
    └──────────────┘        └─────────────┘

Example Results:
✅ Indexed:    10ms,  read 1M rows
❌ Not indexed: 10s,   read 1B rows (1000x slower!)
```

### Materialized View Refresh Diagram

```
┌─────────────────────────────────────────────────────────────┐
│         MATERIALIZED VIEW REFRESH DIAGRAM                   │
└─────────────────────────────────────────────────────────────┘

SOURCE TABLE                  TRIGGER                 MATERIALIZED VIEW
┌──────────────┐                                     ┌──────────────────┐
│   events     │              ⚙️ AUTO                │  events_daily_mv │
│  (Raw Data)  │              TRIGGER                │  (Aggregated)    │
├──────────────┤                                     ├──────────────────┤
│ 1B rows      │◄─────────────────────────────────►│ 365 rows         │
│ Continuous   │        On INSERT/MERGE              │ Pre-computed     │
│ INSERT       │                                     │ Instant queries  │
│              │                                     │                  │
│ Fields:      │     SELECT                          │ Fields:          │
│ • id         │       toDate(event_time) as date,   │ • date           │
│ • event_time │       country,                      │ • country        │
│ • user_id    │       COUNT(*) as count,            │ • count          │
│ • country    │       SUM(revenue) as revenue       │ • revenue        │
│ • revenue    │     FROM events                     │                  │
│              │     GROUP BY date, country          │                  │
└──────┬───────┘                                     └──────────────────┘
       │                                                      ↑
       │                                                      │
       └──────────────────────────────────────────────────────┘
                    Automatic incremental refresh

FLOW:
1️⃣  New row inserted into events table
2️⃣  Materialized view SELECT is triggered automatically
3️⃣  Query aggregates new data (GROUP BY)
4️⃣  Result stored/updated in MV table
5️⃣  Query MV instead of raw table → 100-1000x faster!

Performance:
• Without MV: Scan 1B rows → 5-10 seconds
• With MV:    Scan 365 rows → 10-50 milliseconds
```

### JOIN Execution Strategies

```
┌─────────────────────────────────────────────────────────────┐
│           JOIN EXECUTION STRATEGIES COMPARISON              │
└─────────────────────────────────────────────────────────────┘

🐌 DISTRIBUTED JOIN (Slow)          ⚡ DICTIONARY JOIN (Fast)
┌───────────────────────┐           ┌─────────────────────────┐
│ Large Table A         │           │ Large Table A           │
│ (1B rows, sharded)    │           │ (1B rows, sharded)      │
└───────┬───────────────┘           └────────┬────────────────┘
        │                                     │
        ↓                                     ↓
┌───────────────────────┐           ┌─────────────────────────┐
│ Large Table B         │           │ Small Table B (Dict)    │
│ (100M rows, sharded)  │           │ (100K rows, in RAM)     │
└───────┬───────────────┘           └────────┬────────────────┘
        │                                     │
        ↓                                     ↓
┌───────────────────────┐           ┌─────────────────────────┐
│ Shuffle data across   │           │ Replicate dict to       │
│ network (expensive)   │           │ all nodes (cheap)       │
└───────┬───────────────┘           └────────┬────────────────┘
        │                                     │
        ↓                                     ↓
┌───────────────────────┐           ┌─────────────────────────┐
│ JOIN on coordinator   │           │ Hash lookup on          │
│ (high memory usage)   │           │ each node (local)       │
└───────┬───────────────┘           └────────┬────────────────┘
        │                                     │
        ↓                                     ↓
┌───────────────────────┐           ┌─────────────────────────┐
│ Merge results         │           │ No merge needed         │
└───────────────────────┘           └─────────────────────────┘
        ↓                                     ↓
  Time: 10-60 sec                       Time: 100-500ms
  Network: HIGH                         Network: LOW
  Memory: 10-50 GB                      Memory: 100 MB

❌ Problems:                          ✅ Benefits:
• Network bottleneck                  • All operations local
• High memory usage                   • Minimal memory
• Slow for large tables               • Fast hash lookups
• Can cause OOM                       • Cached in RAM

JOIN TYPE RECOMMENDATIONS:
┌────────────────┬──────────────────┬────────────┬──────────────┐
│  JOIN Type     │   Use Case       │ Performance│ Recommendation│
├────────────────┼──────────────────┼────────────┼──────────────┤
│ Dictionary     │ Small ref tables │ ⚡ Fastest  │ ✅ < 1M rows  │
│ ANY JOIN       │ 1:1 relationships│ Fast       │ ✅ Preferred  │
│ ALL JOIN       │ 1:N relationships│ Medium     │ ⚠️ Filter first│
│ Distributed    │ Large × Large    │ 🐌 Slow    │ ❌ Avoid      │
└────────────────┴──────────────────┴────────────┴──────────────┘

BEST PRACTICE: Denormalize at write time → Eliminate JOINs → 1000x faster!
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
