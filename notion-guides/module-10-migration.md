# 🔄 Module 10: Migration from MongoDB/MySQL

> **Key Goal:** Successfully migrate large datasets from legacy systems to ClickHouse with minimal downtime

## Migration Architecture

```
MongoDB/MySQL (Source)
      ↓
    Extractor
      ↓
   Transform
      ↓
    Loader (ETL)
      ↓
ClickHouse (Target)
      ↓
Validation & Cutover
```

---

## 📊 Pre-Migration Planning

### Compatibility Matrix

| Feature | MySQL | MongoDB | ClickHouse | Action |
|---------|-------|---------|-----------|--------|
| ACID Transactions | ✓ | ✓ | Limited | Use ReplacingMergeTree |
| Denormalization | Limited | Native | Native | Flatten schemas |
| Indexing | Secondary | Index | Primary/Secondary | Redesign indexes |
| TTL | ✓ | ✓ | ✓ | Maintain same |
| Sharding | Manual | Auto | Auto | Rebalance data |

### Assessment Checklist
```
Data Size: ________ GB
Daily Ingestion: ________ GB
Query Complexity: Low / Medium / High
ACID Requirements: Yes / No
Downtime Tolerance: ________ hours
Target Timeline: ________ weeks
```

---

## 🗄️ MySQL to ClickHouse Migration

### Phase 1: Schema Design

**MySQL Source:**
```sql
-- Sample normalized schema
CREATE TABLE users (
  id INT PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255),
  status ENUM('active', 'inactive')
);

CREATE TABLE orders (
  id INT PRIMARY KEY,
  user_id INT,
  amount DECIMAL(10,2),
  created_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

**ClickHouse Target (Denormalized):**
```sql
-- Flat, denormalized structure
CREATE TABLE orders_fact (
  timestamp DateTime,
  order_id UInt64,
  user_id UInt64,
  user_name String,
  user_email String,
  user_status String,
  amount Decimal(10, 2),
  created_at DateTime
) ENGINE = MergeTree()
ORDER BY (timestamp, user_id)
PARTITION BY toYYYYMM(timestamp);
```

**Type Mapping:**
| MySQL | ClickHouse | Notes |
|-------|-----------|-------|
| INT/BIGINT | UInt32/UInt64 | Use unsigned |
| DECIMAL(p,s) | Decimal(p,s) | Preserve precision |
| VARCHAR(n) | String | No length limit |
| ENUM | Enum8/16 or String | Use Enum for low cardinality |
| TIMESTAMP | DateTime | UTC only |
| BOOLEAN | UInt8 | Values 0/1 |
| JSON | String or JSON | Store as string if complex |

### Phase 2: Data Extraction

**Option 1: mysqldump (Small to Medium)**
```bash
# Extract with WHERE clause (parallel)
mysqldump --user=user --password \
  --single-transaction \
  --order-by-primary \
  --no-create-info \
  --tab=/tmp/data/ \
  database_name orders;

# Result: 3 files per table (data, structure, errors)
ls -lh /tmp/data/
# orders.sql, orders.txt, orders.txt
```

**Option 2: SELECT INTO OUTFILE (Fast, Large)**
```sql
-- MySQL session
SELECT
  o.id as order_id,
  o.user_id,
  u.name as user_name,
  u.email as user_email,
  u.status as user_status,
  o.amount,
  o.created_at as timestamp
INTO OUTFILE '/tmp/orders.tsv'
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
FROM orders o
  JOIN users u ON o.user_id = u.id
WHERE o.created_at >= '2024-01-01';

-- Verify output
wc -l /tmp/orders.tsv
```

**Option 3: Python Script (Flexible)**
```python
import pymysql
import csv
from datetime import datetime

conn = pymysql.connect(host='mysql1', user='user', password='pass', database='db')
cursor = conn.cursor()

query = """
  SELECT
    o.id, o.user_id, u.name, u.email, u.status,
    o.amount, o.created_at
  FROM orders o
  JOIN users u ON o.user_id = u.id
  ORDER BY o.created_at
"""

cursor.execute(query)

with open('/tmp/orders_export.csv', 'w', newline='') as f:
  writer = csv.writer(f)
  for row in cursor.fetchall():
    writer.writerow(row)

conn.close()
print("Export completed")
```

### Phase 3: Data Loading

**Method 1: Direct INSERT FROM SELECT**
```sql
-- Create remote table engine (MySQL)
CREATE TABLE mysql_orders (
  id UInt64,
  user_id UInt64,
  amount Decimal(10, 2),
  created_at DateTime
) ENGINE = MySQL(
  'mysql1:3306',
  'database_name',
  'orders',
  'user',
  'password'
);

-- Insert into ClickHouse
INSERT INTO orders_fact
SELECT now() as timestamp, * FROM mysql_orders;
```

**Method 2: Direct File Upload (Fastest)**
```bash
# On ClickHouse server
clickhouse-client --query="
  INSERT INTO orders_fact
  FORMAT TabSeparated
" < /tmp/orders.tsv

# Or with compression
gzip -d /tmp/orders.tsv.gz
clickhouse-client --query="
  INSERT INTO orders_fact FORMAT TabSeparated
" < /tmp/orders.tsv
```

**Method 3: Batch Inserts (Optimal)**
```bash
#!/bin/bash

BATCH_SIZE=100000
TOTAL_ROWS=$(wc -l < /tmp/orders.tsv)

for ((i=1; i<=TOTAL_ROWS; i+=BATCH_SIZE)); do
  END=$((i + BATCH_SIZE - 1))
  echo "Processing rows $i to $END"

  sed -n "${i},${END}p" /tmp/orders.tsv | \
  clickhouse-client --query="
    INSERT INTO orders_fact FORMAT TabSeparated
  "
done
```

---

## 🍃 MongoDB to ClickHouse Migration

### Phase 1: Document Schema Analysis

**MongoDB Collection:**
```javascript
db.events.findOne()
// {
//   "_id": ObjectId(...),
//   "timestamp": ISODate("2026-01-22"),
//   "user_id": 123,
//   "event_type": "purchase",
//   "amount": 99.99,
//   "tags": ["promo", "verified"],
//   "metadata": {
//     "source": "mobile",
//     "os": "iOS"
//   }
// }
```

**ClickHouse Flattened Schema:**
```sql
CREATE TABLE events (
  event_id UUID,
  timestamp DateTime,
  user_id UInt64,
  event_type String,
  amount Decimal(10, 2),
  tags Array(String),
  metadata_source String,
  metadata_os String
) ENGINE = MergeTree()
ORDER BY (timestamp, user_id)
PARTITION BY toYYYYMM(timestamp);
```

### Phase 2: MongoDB Export

**Using mongoexport:**
```bash
# Export to JSON
mongoexport --uri="mongodb://user:pass@mongo1:27017/db" \
  --collection=events \
  --out=/tmp/events.json \
  --query='{"timestamp": {"$gte": ISODate("2024-01-01")}}'

# Verify
head -1 /tmp/events.json | jq .
wc -l /tmp/events.json
```

**Using aggregation pipeline (complex transformations):**
```bash
mongoexport --uri="mongodb://user:pass@mongo1:27017/db" \
  --collection=events \
  --out=/tmp/events_agg.json \
  --aggregationFile=/tmp/pipeline.json
```

**Pipeline file for aggregation:**
```json
[
  {
    "$match": {
      "timestamp": {
        "$gte": {"$date": "2024-01-01T00:00:00Z"}
      }
    }
  },
  {
    "$project": {
      "event_id": "$_id",
      "timestamp": 1,
      "user_id": 1,
      "event_type": 1,
      "amount": 1,
      "tags": 1,
      "metadata_source": "$metadata.source",
      "metadata_os": "$metadata.os"
    }
  }
]
```

### Phase 3: Transform & Load

**Python ETL Script:**
```python
import json
import pymongo
from clickhouse_driver import Client

mongo_client = pymongo.MongoClient('mongodb://user:pass@mongo1:27017')
mongo_db = mongo_client['database']
mongo_collection = mongo_db['events']

clickhouse_client = Client('clickhouse1')

batch = []
batch_size = 10000

for doc in mongo_collection.find(
  {"timestamp": {"$gte": datetime(2024, 1, 1)}}
).batch_size(1000):

  # Transform document
  row = {
    'event_id': str(doc['_id']),
    'timestamp': doc['timestamp'],
    'user_id': doc['user_id'],
    'event_type': doc['event_type'],
    'amount': doc.get('amount', 0),
    'tags': doc.get('tags', []),
    'metadata_source': doc.get('metadata', {}).get('source', ''),
    'metadata_os': doc.get('metadata', {}).get('os', ''),
  }

  batch.append(row)

  # Batch insert
  if len(batch) >= batch_size:
    clickhouse_client.execute(
      'INSERT INTO events VALUES',
      batch,
      types_check=True
    )
    batch = []
    print(f"Inserted {batch_size} records")

# Final batch
if batch:
  clickhouse_client.execute(
    'INSERT INTO events VALUES',
    batch
  )
  print(f"Inserted final {len(batch)} records")
```

---

## ✅ Validation & Cutover

### Data Validation Queries

```sql
-- Row count comparison
SELECT
  'MySQL' as source,
  count() as row_count,
  max(created_at) as max_date
FROM mysql_orders
UNION ALL
SELECT
  'ClickHouse' as source,
  count() as row_count,
  max(timestamp) as max_date
FROM orders_fact;

-- Checksum verification
SELECT
  'MySQL' as source,
  sum(amount) as total_amount,
  count(DISTINCT user_id) as unique_users,
  avg(amount) as avg_amount
FROM mysql_orders
UNION ALL
SELECT
  'ClickHouse' as source,
  sum(amount) as total_amount,
  count(DISTINCT user_id) as unique_users,
  avg(amount) as avg_amount
FROM orders_fact;

-- Sample row comparison
SELECT * FROM mysql_orders ORDER BY id LIMIT 10;
SELECT * FROM orders_fact ORDER BY timestamp LIMIT 10;
```

### Cutover Strategy

```
Phase 1: Read-Only Migration (0 downtime)
  - Run full migration
  - Validate data
  - Keep source system live

Phase 2: Incremental Sync
  - Sync deltas every hour
  - Monitor for differences
  - Build confidence

Phase 3: Cutover Window (Minimal downtime)
  - Stop writes to source
  - Final delta sync
  - Update applications
  - Verify operations
  - Monitor for 24 hours

Phase 4: Decommission
  - Keep source for 30 days backup
  - Archive old backups
  - Document lessons learned
```

### Cutover Script
```bash
#!/bin/bash

# Record start time
START_TIME=$(date +%s)

# Final data sync
echo "Starting final delta sync..."
python /opt/scripts/incremental_sync.py

# Verify counts
MYSQL_COUNT=$(mysql -u user -p --skip-column-names -e \
  "SELECT COUNT(*) FROM database.orders")
CH_COUNT=$(clickhouse-client --query \
  "SELECT count() FROM orders_fact")

if [ "$MYSQL_COUNT" -ne "$CH_COUNT" ]; then
  echo "ERROR: Count mismatch! MySQL: $MYSQL_COUNT, ClickHouse: $CH_COUNT"
  exit 1
fi

echo "✓ Data sync completed"
echo "✓ Row counts match: $CH_COUNT"

# Update application config
sed -i 's/mysql1/clickhouse1/g' /etc/app/config.yml

# Health check
sleep 5
curl -f http://localhost:8080/health || exit 1

# Record end time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "✓ Cutover completed in ${DURATION}s"
```

---

## 📋 Troubleshooting Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Memory exceeded | Large dataset | Batch inserts, parallel load |
| Charset errors | UTF-8 issues | Use `--max_string_size` |
| Slow inserts | Small batches | Increase batch size to 100k+ |
| Missing rows | Incomplete export | Check logs, re-export |
| Type mismatches | Schema mismatch | Verify data types |

---

## ✅ Migration Checklist

- [ ] Assess data size and complexity
- [ ] Design ClickHouse schema
- [ ] Set up test environment
- [ ] Run pilot migration (10% data)
- [ ] Validate data accuracy
- [ ] Document schema mappings
- [ ] Create ETL scripts
- [ ] Test failback procedure
- [ ] Schedule cutover window
- [ ] Notify stakeholders
- [ ] Execute cutover
- [ ] Monitor for 72 hours
- [ ] Archive source system
- [ ] Document lessons learned

---

## 🎓 Quick Reference

**Common Commands:**
```bash
# MySQL export
mysqldump --single-transaction -u user -p db table > /tmp/export.sql

# MongoDB export
mongoexport --uri="mongodb://host/db" --collection=table \
  --out=/tmp/export.json

# ClickHouse import
clickhouse-client < /tmp/export.sql
# or
clickhouse-client --query="INSERT INTO table FORMAT CSV" < /tmp/export.csv
```

**Performance Tips:**
- Use `--max_insert_threads = 4` during loading
- Disable `readonly` for inserts: `SET readonly = 0`
- Monitor: `SELECT * FROM system.query_log WHERE type='QueryFinish'`
- Batch size: 50k-500k records optimal

---

**Last Updated:** 2026-01-22 | **Module:** 10/10 | **Difficulty:** Advanced
