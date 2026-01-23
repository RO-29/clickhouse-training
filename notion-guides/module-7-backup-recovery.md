# 💾 Module 7: Backup, Recovery & PITR

> **Key Goal:** Implement reliable backups, ensure data recovery, and enable Point-In-Time-Recovery

## Architecture Overview

### Backup Architecture Diagram
```
┌─────────────────────────────────────────────┐
│     ClickHouse Cluster (Production)         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Node 1  │  │  Node 2  │  │  Node 3  │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
         ┌─────────────────────┐
         │ clickhouse-backup   │
         │      Tool           │
         └──────────┬──────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ↓           ↓           ↓
┌──────────┐  ┌──────────┐  ┌──────────┐
│  Local   │  │ S3/Cloud │  │ Glacier  │
│ Storage  │→ │ Storage  │→ │ Archive  │
│ 48 hours │  │ 90 days  │  │ 7 years  │
└──────────┘  └──────────┘  └──────────┘
```

### Full vs Incremental Backup Flow
```
FULL BACKUP STRATEGY:           INCREMENTAL BACKUP STRATEGY:
┌──────────────────┐            ┌──────────────────┐
│ Day 1: Full 100GB│            │ Day 1: Full 100GB│
└────────┬─────────┘            └────────┬─────────┘
         │                               │
         ↓                               ↓
┌──────────────────┐            ┌──────────────────┐
│ Day 2: Full 102GB│            │ Day 2: Inc +2GB  │
└────────┬─────────┘            └────────┬─────────┘
         │                               │
         ↓                               ↓
┌──────────────────┐            ┌──────────────────┐
│ Day 3: Full 105GB│            │ Day 3: Inc +3GB  │
└──────────────────┘            └──────────────────┘

Total: 307GB                    Total: 105GB
Time: 3hrs each                 Time: 10min each
Recovery: Fast                  Recovery: Slower
```

### Point-in-Time Recovery Timeline
```
Timeline:
┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
│ Sunday │────→│ Monday │────→│ Tuesday│────→│Wed 14:30│
│ Full   │     │ Inc+Log│     │ Inc+Log│     │DISASTER!│
└────────┘     └────────┘     └────────┘     └────────┘
   100GB          +2GB          +3GB          ⚠️ Data Loss

RECOVERY PROCESS:
1. Restore Sunday Full Backup ──────────→ Base State (100GB)
2. Apply Monday Incremental  ──────────→ +2GB changes
3. Apply Tuesday Incremental ──────────→ +3GB changes
4. Apply Wed Logs (00:00-14:29:59) ────→ Precise Recovery
                                          ✅ Recovered to 14:29:59
```

### Restore Procedure Flowchart
```
      START: Detect Failure
             ↓
      ┌──────────────────┐
      │ Identify Backup  │
      │ (Most Recent)    │
      └────────┬─────────┘
               ↓
      ┌──────────────────┐
      │ Download from S3 │
      │ (if needed)      │
      └────────┬─────────┘
               ↓
      ┌──────────────────┐
      │ Restore Schema   │
      │ (Metadata)       │
      └────────┬─────────┘
               ↓
      ┌──────────────────┐
      │ Restore Data     │
      │ (Parts/Tables)   │
      └────────┬─────────┘
               ↓
      ┌──────────────────┐
      │ Apply Incremental│
      │ Changes          │
      └────────┬─────────┘
               ↓
      ┌──────────────────┐
      │ Verify Integrity │
      │ (Count/Checksums)│
      └────────┬─────────┘
               ↓
      ✅ Resume Operations
```

---

## 🎯 Backup Strategy

### Types of Backups

| Type | Duration | Frequency | Use Case |
|------|----------|-----------|----------|
| **Full** | 1-24 hours | Weekly | Complete data snapshot |
| **Incremental** | Minutes | Daily/Hourly | Changed data only |
| **Differential** | Hours | Weekly | Changes since last full |
| **Log-based** | Seconds | Continuous | Binary logs → recovery |

### Full Backup Process
```sql
-- Create backup directory
BACKUP TABLE table_name
  TO 'S3(s3://bucket/path/backup_name/)'
  SETTINGS compression_codec = 'LZ4';

-- Verify backup
SELECT * FROM system.backup_status;
```

### Incremental Backup Strategy
```bash
# Daily incremental backups
0 1 * * * clickhouse-backup create -t clickhouse_instance \
  --schema=yes --rbac=yes --data=yes

# Weekly full backups
0 2 * * 0 clickhouse-backup create -t clickhouse_instance_full \
  --schema=yes --rbac=yes --data=yes
```

---

## 🔄 Replication-Based Recovery

### Setup Replicated MergeTree
```sql
-- Create replicated table on server 1
CREATE TABLE events_rep (
  timestamp DateTime,
  event_id UInt64,
  data String
) ENGINE = ReplicatedMergeTree(
  '/clickhouse/tables/events',  -- ZooKeeper path
  'replica1'                     -- Replica name
)
ORDER BY (timestamp, event_id);

-- Same schema on server 2, different replica name
-- Replication happens automatically via ZooKeeper
```

### Recovery from Replica
```sql
-- 1. Stop all writes to primary
-- 2. Wait for replica to catch up
SELECT replica_name, absolute_delay FROM system.replicas;

-- 3. Promote replica to primary (or restore from it)
ALTER TABLE events_rep MODIFY SETTING
  readonly = 0;

-- 4. Verify data consistency
SELECT count() FROM events_rep;
```

### ReplicatedReplacingMergeTree for Mutations
```sql
CREATE TABLE users (
  id UInt64,
  name String,
  email String,
  version UInt64
) ENGINE = ReplicatedReplacingMergeTree(version)(
  '/clickhouse/tables/users',
  'replica1'
)
ORDER BY id
SETTINGS clean_deleted_rows = 'never';
```

---

## ⏮️ Point-In-Time Recovery (PITR)

### Binary Log Setup
```xml
<!-- config.xml -->
<binary_log>
  <path>/var/lib/clickhouse/binary_logs/</path>
  <enabled>1</enabled>
  <max_size>1GB</max_size>
  <rotation_size>1GB</rotation_size>
</binary_log>
```

### PITR Recovery Process
```bash
# 1. Find recovery point timestamp
find /var/lib/clickhouse/binary_logs/ -type f -mtime -7

# 2. List available backups with timestamps
clickhouse-backup list

# 3. Restore to specific timestamp
clickhouse-backup restore \
  --backup=backup_2026_01_22_full \
  --restore-data=true \
  --on-cluster=default

# 4. Replay binary logs up to timestamp
-- Automated during restore
```

### Query Binary Log for Audit
```sql
SELECT
  timestamp,
  database,
  table,
  type,
  query
FROM system.query_log
WHERE query_start_time BETWEEN
  '2026-01-20 00:00:00' AND '2026-01-22 10:00:00'
  AND type = 'QueryFinish'
ORDER BY timestamp DESC;
```

---

## 🛠️ Tools & Utilities

### Using clickhouse-backup Tool

```bash
# Installation
wget https://github.com/AlexAkulov/clickhouse-backup/releases/download/v2.x.x/clickhouse-backup-2.x.x-linux-amd64.tar.gz
tar xzf clickhouse-backup-*.tar.gz
sudo mv clickhouse-backup /usr/local/bin/

# Configuration
cat > /etc/clickhouse-backup/config.yml << EOF
general:
  remote_storage: s3
  backup_dir: /var/lib/clickhouse/backups/
s3:
  access_key_id: AWS_KEY
  secret_access_key: AWS_SECRET
  bucket: clickhouse-backups
  region: us-east-1
EOF

# Create backup
clickhouse-backup create -t clickhouse_instance \
  --schema=true --rbac=true

# Restore backup
clickhouse-backup restore --backup=backup_name
```

### mysqldump Alternative for MySQL Tables
```bash
# Export table to SQL
clickhouse-client --query="
  SELECT * FROM mysql_table
  FORMAT TabSeparatedWithNames
" > /tmp/export.tsv

# Restore
clickhouse-client --query="
  INSERT INTO table FORMAT TabSeparatedWithNames
" < /tmp/export.tsv
```

---

## 📋 Backup Storage Options

| Storage | Pros | Cons | Setup Complexity |
|---------|------|------|------------------|
| **S3** | Scalable, multi-region | Cost, latency | Low |
| **HDFS** | Large clusters, cheap | Complex setup | High |
| **GCS** | Fast, integrated | Cost, vendor lock | Medium |
| **Local Disk** | Fast, simple | Limited capacity | Very Low |
| **NFS** | Shared storage | SPOF, network | Medium |

### S3 Configuration
```xml
<!-- config.xml -->
<s3>
  <use_environment_credentials>1</use_environment_credentials>
  <access_key_id>YOUR_KEY</access_key_id>
  <secret_access_key>YOUR_SECRET</secret_access_key>
  <region>us-east-1</region>
  <endpoint_override>https://s3.amazonaws.com</endpoint_override>
</s3>
```

---

## 🔍 Monitoring & Testing

### Backup Health Check
```sql
-- Check backup status
SELECT
  backup_name,
  start_time,
  end_time,
  dataDiff('minute', start_time, end_time) as duration_minutes,
  status
FROM system.backup_status
ORDER BY start_time DESC;

-- Verify table existence after restore
SELECT
  database,
  name,
  engine,
  total_bytes,
  total_rows
FROM system.tables
WHERE database NOT IN ('system', 'information_schema')
ORDER BY total_bytes DESC;
```

### Recovery Time Objective (RTO)
```bash
# Test recovery time
time clickhouse-backup restore --backup=test_backup

# Expected times:
# - Schema restoration: < 1 minute
# - Data restoration (10GB): 5-15 minutes
# - Verification: 2-5 minutes
```

### Test Restore Procedure (Monthly)
```bash
1. Create isolated test environment
2. Restore latest backup to test DB
3. Run integrity checks
4. Verify record counts match source
5. Compare checksums
6. Document results
```

---

## ✅ Best Practices Summary

- ✓ **Frequency:** Full backup weekly, incremental daily
- ✓ **Testing:** Test restore monthly on isolated environment
- ✓ **Validation:** Verify backup integrity after creation
- ✓ **Encryption:** Use SSL/TLS for remote storage
- ✓ **Retention:** Keep 4 weeks of backups minimum
- ✓ **Monitoring:** Alert on failed backups within 30 minutes
- ✓ **Documentation:** Maintain recovery runbook
- ✓ **Redundancy:** Store backups in different regions
- ✓ **Replication:** Use ReplicatedMergeTree for HA
- ✓ **Automation:** Implement backup scripts with cron

---

## 🎓 Quick Reference

**Common Commands:**
```bash
# Full backup
clickhouse-backup create -t default --schema --rbac --data

# List backups
clickhouse-backup list

# Restore specific backup
clickhouse-backup restore --backup=backup_2026_01_22

# Remove old backups (older than 7 days)
clickhouse-backup cleanup --keep-backups=7
```

**Critical Recovery Steps:**
1. Stop all writes to primary
2. Wait for replication to catch up
3. Restore from latest backup
4. Verify checksums
5. Promote to primary
6. Resume writes

---

**Last Updated:** 2026-01-22 | **Module:** 7/10 | **Difficulty:** Advanced
