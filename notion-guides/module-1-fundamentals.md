# 📊 Module 1: ClickHouse Fundamentals

## What is ClickHouse?

> ClickHouse is an open-source, **column-oriented OLAP database** designed for real-time analytics on massive datasets.

### Key Characteristics

- **Columnar Storage**: Data stored by columns, not rows → 100x compression
- **Distributed**: Built-in horizontal scaling
- **Fast**: Processes billions of rows/second
- **SQL-Based**: Standard SQL queries with extensions
- **Real-time Ingestion**: Supports streaming data

---

## Core Architecture

### ClickHouse Full Architecture

```
┌─────────────────────────────────────────────────┐
│          Client Application                     │
│   (Python, Go, Java, Node.js, CLI)            │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│      HTTP (Port 8123) / TCP (Port 9000)        │
│         Protocol Layer                          │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│        Query Processing Layer                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  Parser  │→ │Optimizer │→ │ Executor │     │
│  └──────────┘  └──────────┘  └──────────┘     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│         Storage Engine (MergeTree)              │
│   ┌───────────────────────────────────┐        │
│   │   Column-Oriented Storage         │        │
│   │   - Primary Index                 │        │
│   │   - Data Compression (ZSTD, LZ4)  │        │
│   │   - Partitioning                  │        │
│   └───────────────────────────────────┘        │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│            Disk Storage                         │
│   SSD / NVMe / Distributed Storage (S3, etc)   │
└─────────────────────────────────────────────────┘
```

---

## Column-Oriented vs Row-Oriented Storage

### Row-Oriented Storage (MySQL, PostgreSQL)
```
Storage on Disk:
┌─────────────────────────────────────────┐
│ Row 1: [1, Alice, 25, NYC, 50000]      │
├─────────────────────────────────────────┤
│ Row 2: [2, Bob, 30, LA, 60000]         │
├─────────────────────────────────────────┤
│ Row 3: [3, Carol, 35, SF, 70000]       │
└─────────────────────────────────────────┘

Query: SELECT AVG(Salary) FROM users;
Result: ❌ Reads ALL 5 columns for ALL rows
I/O: High (wasted bandwidth)
```

### Column-Oriented Storage (ClickHouse)
```
Storage on Disk:
┌──────────────────────────────────┐
│ ID Column:     [1, 2, 3]         │
├──────────────────────────────────┤
│ Name Column:   [Alice,Bob,Carol] │
├──────────────────────────────────┤
│ Age Column:    [25, 30, 35]      │
├──────────────────────────────────┤
│ City Column:   [NYC, LA, SF]     │
├──────────────────────────────────┤
│ Salary Column: [50000,60000,70000]│
└──────────────────────────────────┘

Query: SELECT AVG(Salary) FROM users;
Result: ✅ Reads ONLY Salary column
I/O: 5x less (only 1 column instead of 5)
Compression: 10-100x better (same values together)
```

---

## MergeTree Architecture

### How MergeTree Organizes Data

```
Table: events
Partition: 202601 (Jan 2026)
├─── Part 1 (10,000 rows)
│    ├─ Primary Index (sparse)
│    ├─ Column Files:
│    │  ├─ event_date.bin
│    │  ├─ user_id.bin
│    │  ├─ event_type.bin
│    │  └─ revenue.bin
│    └─ Checksums
│
├─── Part 2 (15,000 rows)
│    ├─ Primary Index
│    └─ Column Files
│
└─── Part 3 (8,000 rows)
     ├─ Primary Index
     └─ Column Files

          ⬇ Background Merge Process ⬇

Merged Part (33,000 rows)
├─ Optimized Primary Index
└─ Compressed Column Files
```

### MergeTree Merge Process
```
Before Merge (Many Small Parts):
┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
│Part1│ │Part2│ │Part3│ │Part4│ │Part5│
│100KB│ │150KB│ │120KB│ │90KB │ │110KB│
└─────┘ └─────┘ └─────┘ └─────┘ └─────┘
 Query must read 5 separate files

          ⬇ Merge Process ⬇

After Merge (Single Large Part):
┌──────────────────────────────┐
│    Merged Part (570KB)       │
│  Better compressed           │
│  Faster queries              │
└──────────────────────────────┘
 Query reads 1 optimized file
```

---

## Key Concepts

### 1. Column Orientation
| Aspect | Row-oriented | Column-oriented |
|--------|-------------|-----------------|
| **Compression** | ~10x | ~100x |
| **Analytics Speed** | Slow | Very Fast |
| **Insert Speed** | Fast | Medium |
| **Use Case** | OLTP | OLAP |

### 2. Data Types
```sql
-- Scalar Types
Integer: UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64
Float: Float32, Float64
Decimal: Decimal32, Decimal64, Decimal128
String: String, FixedString(N)
DateTime: DateTime, DateTime64
Enum: Enum8, Enum16

-- Complex Types
Array(T): Array of type T
Tuple(T1, T2, ...): Named tuples
Nested: Nested arrays
Map(K, V): Key-value pairs
```

### 3. Data Sampling & Compression
- **LZ4**: Default, fast compression
- **ZSTD**: High compression ratio (slower)
- **Delta**: For time-series data
- **T64**: For numeric data

---

## Quick Reference: Installation & Setup

### Install on macOS
```bash
brew install clickhouse
# Start server
clickhouse-server &
# Connect client
clickhouse-client
```

### Install on Linux
```bash
apt-get install clickhouse-server clickhouse-client
systemctl start clickhouse-server
```

### First Connection
```bash
clickhouse-client --host localhost --port 9000
# or HTTP interface
curl 'http://localhost:8123/?query=SELECT%201'
```

---

## System Tables

| Table | Purpose |
|-------|---------|
| `system.databases` | List all databases |
| `system.tables` | List all tables |
| `system.columns` | Column metadata |
| `system.processes` | Running queries |
| `system.metrics` | Performance metrics |
| `system.query_log` | Query history |

### View Databases
```sql
SELECT * FROM system.databases;
```

### Check Table Structure
```sql
DESCRIBE table_name;
-- or
DESC table_name;
```

---

## Basic Operations

### Create Database
```sql
CREATE DATABASE my_analytics ENGINE = Ordinary;
-- or Atomic (default in v21+)
CREATE DATABASE my_analytics ENGINE = Atomic;
```

### Create Table
```sql
CREATE TABLE events (
    id UInt64,
    timestamp DateTime,
    event_name String,
    user_id UInt32,
    value Float64
) ENGINE = MergeTree()
ORDER BY (timestamp, id);
```

### Insert Data
```sql
INSERT INTO events VALUES
    (1, now(), 'click', 123, 45.5),
    (2, now(), 'view', 456, 23.1);
```

### Query Data
```sql
SELECT
    event_name,
    COUNT(*) as cnt,
    AVG(value) as avg_value
FROM events
GROUP BY event_name;
```

---

## Performance Concepts

### 1. **PRIMARY KEY**
- Defines data ordering
- Enables faster filtering
- Example: `ORDER BY (timestamp, user_id)`

### 2. **Partitioning**
- Separates data by time/category
- Speeds up deletion and queries
```sql
PARTITION BY toYYYYMM(timestamp)
```

### 3. **TTL (Time To Live)**
- Auto-delete old data
```sql
TTL timestamp + INTERVAL 30 DAY
```

### 4. **Merges**
- Background process combines parts
- Improves query performance
- Configurable intervals

---

## Best Practices ✅

| Practice | Reason |
|----------|--------|
| Use **MergeTree** engine | Most flexible, optimized |
| Set **ORDER BY carefully** | Impacts query performance |
| Use **PARTITION BY** | Speeds up date filtering |
| Batch **INSERT** (1000+ rows) | Better performance |
| Monitor **system.processes** | Track running queries |
| Use **ZSTD** for compression | Better ratio, CPU available |
| Set **TTL** for cleanup | Prevent disk overflow |

---

## Common Errors & Solutions

| Error | Cause | Fix |
|-------|-------|-----|
| `Port in use` | Server already running | Check `ps aux \| grep clickhouse` |
| `Cannot insert NULL` | Nullable type issue | Use `Nullable(Type)` |
| `Memory limit exceeded` | Large query | Reduce dataset or add memory |
| `Code 57` (Table not exists) | Wrong table name | Check `SHOW TABLES` |

---

## Next Steps

✓ Understand columnar storage benefits
✓ Master MergeTree table engine
✓ Learn partitioning strategies
→ **Module 2: Table Engines & Data Modeling**

---

*Last Updated: Jan 2026*
