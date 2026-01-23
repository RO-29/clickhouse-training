# 🚨 Module 8: Disaster Recovery & Business Continuity

> **Key Goal:** Prepare for total failure, maintain continuous availability, and achieve zero data loss

## Multi-Datacenter Architecture Diagram

### Active-Passive DR Setup
```
┌─────────────────────────────────┐         ┌─────────────────────────────────┐
│   PRIMARY DATACENTER (US-East)  │         │    DR DATACENTER (US-West)      │
│                                 │         │                                 │
│  ┌──────────────────────────┐  │         │  ┌──────────────────────────┐  │
│  │  ClickHouse Cluster      │  │         │  │  ClickHouse Cluster      │  │
│  │  ┌────┐ ┌────┐ ┌────┐   │  │         │  │  ┌────┐ ┌────┐ ┌────┐   │  │
│  │  │ N1 │ │ N2 │ │ N3 │   │  │         │  │  │ N1 │ │ N2 │ │ N3 │   │  │
│  │  └────┘ └────┘ └────┘   │  │         │  │  └────┘ └────┘ └────┘   │  │
│  │  ✍️  ACTIVE (Writes)     │  │────────→│  │  🔒 STANDBY (Read-Only)  │  │
│  │  📖 Serves Reads         │  │Real-Time│  │  📖 Receives Replicated  │  │
│  └──────────────────────────┘  │Sync     │  └──────────────────────────┘  │
│                                 │< 1 sec  │                                 │
│  ┌──────────────────────────┐  │         │  ┌──────────────────────────┐  │
│  │  ZooKeeper Ensemble      │  │         │  │  ZooKeeper Observers     │  │
│  │  ┌────┐ ┌────┐ ┌────┐   │  │         │  │  ┌────┐ ┌────┐           │  │
│  │  │ZK1 │ │ZK2 │ │ZK3 │   │  │←──────→│  │  │ZK4 │ │ZK5 │           │  │
│  │  └────┘ └────┘ └────┘   │  │Quorum   │  │  └────┘ └────┘           │  │
│  │  (Voting Members)        │  │         │  │  (Non-voting)            │  │
│  └──────────────────────────┘  │         │  └──────────────────────────┘  │
└─────────────────────────────────┘         └─────────────────────────────────┘

FAILOVER: DNS Update → DR becomes Primary → Applications reconnect
RTO: 15 minutes | RPO: < 1 minute
```

### Active-Passive vs Active-Active
```
ACTIVE-PASSIVE:                          ACTIVE-ACTIVE:

┌─────────────────┐                      ┌─────────────────┐
│   Primary DC    │                      │   Primary DC    │
│  ✍️  Writes 100% │                      │  ✍️  Writes 50%  │
│  📖 Reads 100%   │                      │  📖 Reads 50%    │
│  Status: ACTIVE │                      │  Status: ACTIVE │
└────────┬────────┘                      └────────┬────────┘
         │                                        │
         │ Replication                            │ Bi-directional
         ↓                                        ↕ Sync
┌─────────────────┐                      ┌─────────────────┐
│     DR DC       │                      │     DR DC       │
│  🔒 Writes 0%    │                      │  ✍️  Writes 50%  │
│  📖 Reads 0%     │                      │  📖 Reads 50%    │
│  Status: STANDBY│                      │  Status: ACTIVE │
└─────────────────┘                      └─────────────────┘

✅ Simple                                ✅ Full utilization
✅ Easy failover                         ✅ No failover needed
✅ Lower cost                            ✅ Load balanced
⚠️  Wasted DR resources                 ⚠️  Complex coordination
```

### Failover Decision Tree
```
                    ⚠️  PRIMARY DC FAILURE DETECTED
                              │
                              ↓
                    ┌──────────────────┐
                    │ Is DR DC Healthy?│
                    └────────┬─────────┘
                    ┌────────┴────────┐
                 NO │                 │ YES
                    ↓                 ↓
         ┌──────────────────┐  ┌─────────────────┐
         │  Abort Failover  │  │Check Replication│
         │                  │  │      Lag        │
         └────────┬─────────┘  └────────┬────────┘
                  ↓                     ↓
         ┌──────────────────┐  ┌─────────────────┐
         │ Alert Operations │  │Wait Queue Drain │
         │                  │  │    (<30 sec)    │
         └────────┬─────────┘  └────────┬────────┘
                  ↓                     ↓
         ┌──────────────────┐  ┌─────────────────┐
         │     Manual       │  │  Update DNS to  │
         │  Investigation   │  │      DR DC      │
         └──────────────────┘  └────────┬────────┘
                                        ↓
                               ┌─────────────────┐
                               │  Promote DR to  │
                               │     Primary     │
                               └────────┬────────┘
                                        ↓
                               ┌─────────────────┐
                               │Resume Application│
                               │     Traffic     │
                               └────────┬────────┘
                                        ↓
                               ✅ FAILOVER COMPLETE
```

### RTO/RPO Timeline
```
Timeline:
─────────────────────────────────────────────────────────────────→
         │                    │                    │
    14:28:00             14:30:00             14:45:00
         │                    │                    │
  ┌──────────┐         ┌──────────┐         ┌──────────┐
  │   Last   │         │ FAILURE  │         │ Recovery │
  │   Good   │         │ Detected │         │ Complete │
  │  State   │         │    ⚠️     │         │    ✅    │
  └──────────┘         └──────────┘         └──────────┘
         │                    │                    │
         ├────── RPO ─────────┤                    │
         │   (Data Loss)      │                    │
         │    2 minutes       │                    │
         │                    ├────── RTO ─────────┤
         │                    │    (Downtime)      │
         │                    │   15 minutes       │

RPO (Recovery Point Objective):    RTO (Recovery Time Objective):
• Max data loss: 2 minutes         • Max downtime: 15 minutes
• Actual loss: 14:28-14:30         • Actual time: 14:30-14:45
• Status: ✅ Within SLA             • Status: ✅ Within SLA
```

## Disaster Recovery Levels

```
Level 0: Single Server (RTO: Hours, RPO: Minutes)
   ↓
Level 1: HA Pair (RTO: Minutes, RPO: Seconds)
   ↓
Level 2: Multi-Region (RTO: < 1 Min, RPO: 0)
   ↓
Level 3: Multi-Cloud (RTO: < 30s, RPO: 0)
```

---

## 🏗️ Architecture for Business Continuity

### Level 1: Basic HA with Replication
```
     Primary (Write)
         ↓
      Replicas (Read)
         ↓
    ZooKeeper Cluster
         ↓
    Automatic Failover
```

**Setup:**
```sql
-- Primary cluster config
<cluster>
  <primary>
    <shard>
      <replica><host>clickhouse1</host><port>9000</port></replica>
      <replica><host>clickhouse2</host><port>9000</port></replica>
    </shard>
  </primary>
</cluster>

-- Create table with replication
CREATE TABLE events (
  timestamp DateTime,
  event_id UInt64,
  data String
) ENGINE = ReplicatedMergeTree(
  '/clickhouse/tables/events',
  'replica1'
)
ORDER BY (timestamp, event_id)
SETTINGS
  max_replica_delay_for_distributed_queries = 30;
```

### Level 2: Multi-Region Setup
```
Region A (Primary)              Region B (DR)
┌─────────────────┐          ┌──────────────┐
│ Cluster 1       │          │ Cluster 2    │
│ 3 nodes         │◄────────►│ 3 nodes      │
│ RTO: 1 min      │ Async    │ RTO: 1 min   │
│ RPO: 5 secs     │ Repl.    │ RPO: 5 secs  │
└─────────────────┘          └──────────────┘
     ↓                              ↓
   S3 Backup               S3 Backup (Replicated)
   Every 6 hours          Every 6 hours
```

### Level 3: Active-Active Multi-Cloud
```
AWS ClickHouse Cluster     ← Bidirectional Replication →    GCP ClickHouse Cluster
  (Primary Write)                                              (Secondary Write)
       ↓                                                            ↓
     S3 Backup                                                   GCS Backup
       ↓                                                            ↓
   Application Load Balancer                                 Application Load Balancer
```

---

## 🔄 Synchronous Replication (Zero Data Loss)

### Configuration for RPO = 0
```xml
<!-- config.xml -->
<replication>
  <min_replicated_logs_to_keep>10</min_replicated_logs_to_keep>
  <max_replicated_logs_to_keep>1000</max_replicated_logs_to_keep>
  <replicated_can_become_leader>1</replicated_can_become_leader>
  <connection_pool_size>100</connection_pool_size>
  <recovery_initial_state_size>262144</recovery_initial_state_size>
</replication>

<distributed_ddl>
  <task_max_lifetime>3600</task_max_lifetime>
  <task_cleanup_period>600</task_cleanup_period>
</distributed_ddl>
```

### Monitoring Replication Health
```sql
-- Check replica status
SELECT
  database,
  table,
  replica_name,
  is_leader,
  absolute_delay,
  queue_size
FROM system.replicas
WHERE absolute_delay > 30;

-- Set alert if delay > 60 seconds
SELECT
  if(max(absolute_delay) > 60, 'CRITICAL', 'OK') as status,
  max(absolute_delay) as max_delay
FROM system.replicas;
```

---

## 🎯 Failover Procedures

### Manual Failover Steps

```bash
# 1. Detect primary failure
clickhouse-client -h clickhouse1 --query="SELECT 1" 2>&1 | grep -q "Connection refused"

# 2. Check replica lag on secondary
clickhouse-client -h clickhouse2 \
  --query="SELECT absolute_delay FROM system.replicas"

# 3. If lag is acceptable (< 30 seconds)
clickhouse-client -h clickhouse2 \
  --query="ALTER TABLE events MODIFY SETTING readonly = 0"

# 4. Redirect application traffic to clickhouse2
# Update DNS/SLB configuration

# 5. Verify write capability
clickhouse-client -h clickhouse2 \
  --query="INSERT INTO events VALUES (now(), 1, 'test')"

# 6. Start recovery on primary when available
```

### Automated Failover with Keeper (ZooKeeper Replacement)
```sql
-- Enable auto-failover
SET allow_automatic_leader_election = 1;

-- Monitor election status
SELECT
  keeper_path,
  is_active
FROM system.zookeeper
WHERE path = '/clickhouse/task_queue';

-- Restart leader election
ALTER TABLE events MODIFY SETTING
  replicated_replicat_can_become_leader = 1;
```

### Health Check Script
```bash
#!/bin/bash

HOSTS=("clickhouse1" "clickhouse2" "clickhouse3")
ALERT_EMAIL="ops@example.com"

for host in "${HOSTS[@]}"; do
  if ! timeout 5 clickhouse-client -h "$host" \
    --query="SELECT 1" > /dev/null 2>&1; then
    echo "Alert: $host is down" | mail -s "ClickHouse Failure" "$ALERT_EMAIL"
    # Trigger failover procedure
    /opt/scripts/failover.sh "$host"
  fi
done
```

---

## 📊 Monitoring & Alerting

### Key Metrics for DR
| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Replica Lag | > 10s | > 60s | Check network, disk I/O |
| ZK Connectivity | N/A | Lost | Restart ZK cluster |
| Disk Space | > 85% | > 95% | Archive old data |
| Queue Size | > 1000 | > 10000 | Scale horizontally |

### Prometheus Alerts
```yaml
groups:
  - name: clickhouse_dr
    rules:
      - alert: HighReplicaLag
        expr: increase(system_replicas_absolute_delay[5m]) > 60
        for: 5m
        annotations:
          summary: "High replica lag on {{ $labels.host }}"

      - alert: ZookeeperDown
        expr: up{job="zookeeper"} == 0
        for: 2m
        annotations:
          summary: "ZooKeeper is down"

      - alert: QueueSizeHigh
        expr: system_replicas_queue_size > 10000
        for: 10m
        annotations:
          summary: "Queue backlog {{ $value }}"
```

---

## 🔐 Data Integrity Checks

### Before Failover Verification
```sql
-- Check data consistency across replicas
SELECT
  'replica1' as replica,
  count() as rows,
  sum(cityHash64(*)) as hash
FROM cluster('primary', default, events)
WHERE replica_name = 'replica1'
UNION ALL
SELECT
  'replica2' as replica,
  count() as rows,
  sum(cityHash64(*)) as hash
FROM cluster('primary', default, events)
WHERE replica_name = 'replica2';

-- Should return identical hashes
```

### Post-Recovery Validation
```bash
#!/bin/bash

# Count verification
SOURCE_COUNT=$(clickhouse-client -h source_cluster \
  --query="SELECT count() FROM events")
DR_COUNT=$(clickhouse-client -h dr_cluster \
  --query="SELECT count() FROM events")

if [ "$SOURCE_COUNT" != "$DR_COUNT" ]; then
  echo "CRITICAL: Row count mismatch"
  echo "Source: $SOURCE_COUNT, DR: $DR_COUNT"
  exit 1
fi

echo "✓ Row count verified"
```

---

## 📋 Disaster Recovery Plan Template

### RPO & RTO Targets
```
Scenario 1: Single Node Failure
  RTO: 5 minutes (automatic failover)
  RPO: 0 seconds (replicated)

Scenario 2: Entire Datacenter Down
  RTO: 30 minutes (manual failover + app redirection)
  RPO: 0 seconds (multi-region replication)

Scenario 3: Catastrophic Data Corruption
  RTO: 2 hours (restore from backup)
  RPO: 6 hours (last backup before corruption)
```

### Monthly DR Testing Checklist
- [ ] Simulate primary node failure
- [ ] Verify automatic failover works
- [ ] Check application connectivity
- [ ] Validate data integrity
- [ ] Monitor performance during failover
- [ ] Document recovery time
- [ ] Update runbook based on findings
- [ ] Train ops team on procedures

---

## ✅ Business Continuity Best Practices

- ✓ Maintain 3+ replicas across geographies
- ✓ Use synchronous replication for critical data
- ✓ Test failover monthly
- ✓ Implement automatic health checks
- ✓ Set up alerts for all critical metrics
- ✓ Keep backup copies in separate regions
- ✓ Document all recovery procedures
- ✓ Train team on incident response
- ✓ Use SLB/DNS for transparent failover
- ✓ Implement circuit breakers in applications

---

## 🎓 Quick Reference

**Critical Commands:**
```bash
# Check replica status
clickhouse-client --query="SELECT * FROM system.replicas"

# Trigger failover
ALTER TABLE events MODIFY SETTING
  replicated_can_become_leader = 1

# Restore from backup (DR site)
clickhouse-backup restore --backup=latest_backup

# Verify replication
clickhouse-client --query="
  SELECT database, table, replica_name, absolute_delay
  FROM system.replicas ORDER BY absolute_delay DESC"
```

**Response Workflow:**
1. Detect failure → Alert team
2. Check replica lag → Assess risk
3. Initiate failover → Promote replica
4. Update DNS/SLB → Redirect traffic
5. Notify stakeholders → 99.9% uptime
6. Recover primary → Full redundancy

---

**Last Updated:** 2026-01-22 | **Module:** 8/10 | **Difficulty:** Advanced
