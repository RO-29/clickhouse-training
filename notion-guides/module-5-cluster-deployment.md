# 🚀 Module 5: Full Cluster Deployment

## Cluster Topology Overview

### Production Setup (3-Shard, 2-Replica)

```
┌─────────────────────────────────────────────────────────────────┐
│              FULL CLUSTER TOPOLOGY (3×2)                        │
└─────────────────────────────────────────────────────────────────┘

                    🌐 User Applications
                            ↓
                ┌───────────────────────┐
                │   ⚖️ Load Balancer    │
                │ (HAProxy/Nginx/ALB)   │
                │  Ports: 9000 | 8123   │
                └──────────┬────────────┘
                           ↓
        ┌──────────────────┼──────────────────┐
        ↓                  ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  SHARD 1     │  │  SHARD 2     │  │  SHARD 3     │
│  (33% data)  │  │  (33% data)  │  │  (33% data)  │
├──────────────┤  ├──────────────┤  ├──────────────┤
│ 👑 Node 1    │  │ 👑 Node 3    │  │ 👑 Node 5    │
│ (Primary)    │  │ (Primary)    │  │ (Primary)    │
│ ch1.local    │  │ ch3.local    │  │ ch5.local    │
├──────────────┤  ├──────────────┤  ├──────────────┤
│ 🔄 Node 2    │  │ 🔄 Node 4    │  │ 🔄 Node 6    │
│ (Replica)    │  │ (Replica)    │  │ (Replica)    │
│ ch2.local    │  │ ch4.local    │  │ ch6.local    │
└──────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           ↓
              ┌────────────────────────┐
              │  KEEPER COORDINATION   │
              ├────────────────────────┤
              │ 👑 Keeper-1 (Leader)   │
              │ 🔵 Keeper-2 (Follower) │
              │ 🔵 Keeper-3 (Follower) │
              │   Port: 9181 | 9234    │
              └────────────────────────┘
                           ↓
              ┌────────────────────────┐
              │   📊 MONITORING         │
              │ Prometheus + Grafana   │
              │   Port: 9363           │
              └────────────────────────┘

Total: 6 ClickHouse nodes + 3 Keeper nodes = 9 servers
Fault Tolerance: 1 node per shard + 1 Keeper can fail
```

### Network Architecture & Ports

```
┌─────────────────────────────────────────────────────────────┐
│               NETWORK ARCHITECTURE DIAGRAM                  │
└─────────────────────────────────────────────────────────────┘

PUBLIC NETWORK:                 INTERNAL NETWORK:
┌────────────────┐              ┌─────────────────────┐
│  🌐 Internet   │              │ 🔐 Private Subnet   │
│   Load Balancer│              │   Inter-node Comm   │
│                │              │                     │
│ Port 8123 HTTP │              │ Port 9000 (Native)  │
│ Port 9440 HTTPS│              │ Port 9009 (Replic)  │
│                │              │ Port 9181 (Keeper)  │
│ ✅ TLS/SSL     │              │ Port 9234 (Raft)    │
│ 🛡️ Firewalled  │              │                     │
└────────────────┘              │ 🔒 No external      │
                                │ ⚡ Low latency       │
                                └─────────────────────┘

MONITORING NETWORK:
┌────────────────┐
│ 📊 Metrics     │
│                │
│ Port 9363      │
│ (Prometheus)   │
│                │
│ Port 8123      │
│ (Metrics API)  │
└────────────────┘

FIREWALL RULES:
┌────────┬──────────┬───────────────────────┬─────────────────┐
│  Port  │ Protocol │      Purpose          │     Access      │
├────────┼──────────┼───────────────────────┼─────────────────┤
│  9000  │   TCP    │ ClickHouse Native     │ Internal only   │
│  8123  │   HTTP   │ HTTP Interface        │ LB + monitoring │
│  9009  │   TCP    │ Inter-server Replic   │ Internal only   │
│  9181  │   TCP    │ Keeper Client         │ CH + Keeper     │
│  9234  │   TCP    │ Keeper Raft           │ Keeper only     │
│  9363  │   HTTP   │ Prometheus Metrics    │ Monitoring      │
└────────┴──────────┴───────────────────────┴─────────────────┘
```

### Distributed DDL Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│            DISTRIBUTED DDL EXECUTION DIAGRAM                │
└─────────────────────────────────────────────────────────────┘

Step 1: Submit DDL
┌─────────────────────────────────────┐
│ CREATE TABLE ... ON CLUSTER         │
│ 'my_cluster'                        │
└────────────────┬────────────────────┘
                 ↓
Step 2: Keeper Queue
┌─────────────────────────────────────┐
│ /clickhouse/task_queue/ddl          │
│ ├─ task_0001 (CREATE TABLE)         │
│ └─ Status: PENDING                  │
└────────────────┬────────────────────┘
                 ↓
Step 3: Parallel Execution
         ┌───────┼───────┐
         ↓       ↓       ↓
    ┌────────┬────────┬────────┐
    │ Node 1 │ Node 2 │ Node 3 │
    │ Node 4 │ Node 5 │ Node 6 │
    └────────┴────────┴────────┘
    Execute DDL simultaneously
         ↓       ↓       ↓
         └───────┼───────┘
                 ↓
Step 4: Report Status
┌─────────────────────────────────────┐
│ All nodes ACK to Keeper             │
│ ├─ Node 1: ✅ SUCCESS               │
│ ├─ Node 2: ✅ SUCCESS               │
│ ├─ Node 3: ✅ SUCCESS               │
│ ├─ Node 4: ✅ SUCCESS               │
│ ├─ Node 5: ✅ SUCCESS               │
│ └─ Node 6: ✅ SUCCESS               │
└─────────────────────────────────────┘
                 ↓
Result: Table created on all nodes ✅
```

### User/Role Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│              USER/ROLE HIERARCHY DIAGRAM                    │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   👑 ADMIN USER  │  │ 👤 APP USER      │  │ 📖 READ-ONLY     │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ Permissions:     │  │ Permissions:     │  │ Permissions:     │
│ ✅ ALL privileges│  │ ✅ SELECT        │  │ ✅ SELECT only   │
│ ✅ CREATE/DROP   │  │ ✅ INSERT        │  │ ❌ No INSERT     │
│ ✅ Manage users  │  │ ❌ No DDL        │  │ ❌ No DDL        │
│ ✅ Cluster ops   │  │ ❌ No DROP       │  │ ❌ No mutations  │
│ ✅ System tables │  │ ❌ No user mgmt  │  │ ❌ No writes     │
│                  │  │                  │  │                  │
│ Profile:         │  │ Profile:         │  │ Profile:         │
│ • unlimited      │  │ • app_profile    │  │ • readonly       │
│                  │  │                  │  │                  │
│ Quota:           │  │ Quota:           │  │ Quota:           │
│ • none           │  │ • 10K queries/hr │  │ • 1K queries/hr  │
│                  │  │                  │  │                  │
│ Memory:          │  │ Memory:          │  │ Memory:          │
│ • 32 GB          │  │ • 10 GB          │  │ • 5 GB           │
│                  │  │                  │  │                  │
│ Networks:        │  │ Networks:        │  │ Networks:        │
│ • internal only  │  │ • app subnet     │  │ • public/VPN     │
└──────────────────┘  └──────────────────┘  └──────────────────┘

RESOURCE LIMITS BY PROFILE:
┌───────────────────────┬─────────┬─────────────┬──────────────┐
│       Setting         │  Admin  │ Application │  Read-Only   │
├───────────────────────┼─────────┼─────────────┼──────────────┤
│ max_memory_usage      │  32 GB  │    10 GB    │    5 GB      │
│ max_execution_time    │ Unlimited│   300 sec   │   60 sec     │
│ max_threads           │   16    │      8      │      4       │
│ readonly              │    0    │      0      │      1       │
└───────────────────────┴─────────┴─────────────┴──────────────┘
```

---

## Prerequisites

### Hardware Requirements

| Component | CPU | RAM | Storage | Network |
|-----------|-----|-----|---------|---------|
| **ClickHouse Node** | 8-16 cores | 32-64 GB | 500GB SSD+ | 1Gbps+ |
| **ZooKeeper Node** | 4 cores | 8-16 GB | 100GB SSD | 1Gbps+ |
| **Monitoring Node** | 4 cores | 8 GB | 50GB SSD | 1Gbps+ |

### Software Stack
```
Operating System: Ubuntu 20.04 LTS or Rocky Linux 8+
ClickHouse Server: v22.3+ (LTS recommended)
ZooKeeper: 3.7+
Java: OpenJDK 11+
Python: 3.8+ (for scripts)
```

---

## Step 1: ZooKeeper Cluster Setup

### Installation
```bash
# Download ZooKeeper
cd /opt
wget https://archive.apache.org/dist/zookeeper/zookeeper-3.8.0/apache-zookeeper-3.8.0-bin.tar.gz
tar -xzf apache-zookeeper-3.8.0-bin.tar.gz
ln -s apache-zookeeper-3.8.0-bin zookeeper
chown -R zookeeper:zookeeper /opt/zookeeper

# Install Java
apt-get install openjdk-11-jdk-headless
```

### Configuration: zoo.cfg
```ini
# /opt/zookeeper/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
server.1=zk1.example.com:2888:3888
server.2=zk2.example.com:2888:3888
server.3=zk3.example.com:2888:3888

# Performance tuning
autopurge.snapRetainCount=5
autopurge.purgeInterval=24
maxClientCnxns=0
```

### Start ZooKeeper
```bash
# Create myid file (different on each node)
echo "1" > /var/lib/zookeeper/myid  # Node 1
echo "2" > /var/lib/zookeeper/myid  # Node 2
echo "3" > /var/lib/zookeeper/myid  # Node 3

# Start service
/opt/zookeeper/bin/zkServer.sh start

# Verify
/opt/zookeeper/bin/zkCli.sh -server localhost:2181
> status
```

---

## Step 2: ClickHouse Installation

### Install on All Nodes
```bash
# Add repository
apt-get install -y apt-transport-https ca-certificates dirmngr gnupg2
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E0C56BD4

echo "deb https://repo.clickhouse.tech/deb/stable/ main/" | tee /etc/apt/sources.list.d/clickhouse.list

apt-get update
apt-get install -y clickhouse-server clickhouse-client
```

### Verify Installation
```bash
clickhouse-server --version
clickhouse-client --version
```

---

## Step 3: Cluster Configuration

### config.xml - Remote Servers

**Path:** `/etc/clickhouse-server/config.d/cluster.xml`

```xml
<?xml version="1.0"?>
<clickhouse>
    <remote_servers>
        <prod_cluster>
            <!-- Shard 1 -->
            <shard>
                <weight>1</weight>
                <replica>
                    <host>ch1-shard1-replica1</host>
                    <port>9000</port>
                    <user>default</user>
                    <password></password>
                </replica>
                <replica>
                    <host>ch2-shard1-replica2</host>
                    <port>9000</port>
                </replica>
            </shard>
            <!-- Shard 2 -->
            <shard>
                <weight>1</weight>
                <replica>
                    <host>ch3-shard2-replica1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch4-shard2-replica2</host>
                    <port>9000</port>
                </replica>
            </shard>
            <!-- Shard 3 -->
            <shard>
                <weight>1</weight>
                <replica>
                    <host>ch5-shard3-replica1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch6-shard3-replica2</host>
                    <port>9000</port>
                </replica>
            </shard>
        </prod_cluster>
    </remote_servers>

    <!-- ZooKeeper settings -->
    <zookeeper>
        <node index="1">
            <host>zk1.example.com</host>
            <port>2181</port>
        </node>
        <node index="2">
            <host>zk2.example.com</host>
            <port>2181</port>
        </node>
        <node index="3">
            <host>zk3.example.com</host>
            <port>2181</port>
        </node>
    </zookeeper>

    <!-- Macros for dynamic paths -->
    <macros>
        <shard>1</shard>
        <replica>replica1</replica>
    </macros>
</clickhouse>
```

### config.xml - Performance Settings

**Path:** `/etc/clickhouse-server/config.d/performance.xml`

```xml
<?xml version="1.0"?>
<clickhouse>
    <profiles>
        <default>
            <!-- Memory -->
            <max_memory_usage>32000000000</max_memory_usage>
            <max_memory_usage_for_user>32000000000</max_memory_usage_for_user>

            <!-- Threads -->
            <max_threads>16</max_threads>
            <max_insert_threads>4</max_insert_threads>

            <!-- Replication -->
            <insert_quorum>2</insert_quorum>
            <insert_quorum_timeout_ms>5000</insert_quorum_timeout_ms>

            <!-- Distributed queries -->
            <distributed_connections_pool_size>100</distributed_connections_pool_size>
            <max_replica_delay_for_distributed_queries>300</max_replica_delay_for_distributed_queries>
        </default>
    </profiles>

    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</clickhouse>
```

---

## Step 4: Create Tables Cluster-wide

### Database Creation
```sql
CREATE DATABASE events ON CLUSTER 'prod_cluster'
ENGINE = Atomic;
```

### Local Table (on each node via cluster)
```sql
CREATE TABLE events_local ON CLUSTER 'prod_cluster' (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event String,
    value Float64
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/{cluster}/tables/{shard}/events',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, user_id)
SETTINGS index_granularity = 8192;
```

### Distributed Table (query interface)
```sql
CREATE TABLE events ON CLUSTER 'prod_cluster' (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event String,
    value Float64
)
ENGINE = Distributed(
    'prod_cluster',
    default,
    events_local,
    intDiv(xxHash64(user_id), 9223372036854775807) % 3
);
```

---

## Step 5: Start Services

### Start ClickHouse on All Nodes
```bash
# On each node
systemctl start clickhouse-server
systemctl enable clickhouse-server

# Verify
systemctl status clickhouse-server
clickhouse-client -q "SELECT version()"
```

### Health Check Script
```bash
#!/bin/bash
# check_cluster.sh

for node in ch1 ch2 ch3 ch4 ch5 ch6; do
    echo "Checking $node..."
    clickhouse-client -h $node -q "SELECT 1" && echo "✓ $node OK" || echo "✗ $node FAILED"
done
```

---

## Step 6: Data Ingestion Setup

### Kafka Integration
```sql
CREATE TABLE kafka_events (
    id UInt64,
    timestamp DateTime,
    user_id UInt32,
    event String,
    value Float64
) ENGINE = Kafka('kafka:9092', 'events', 'clickhouse-group',
                  'JSONEachRow');

-- Materialized view to consume & store
CREATE MATERIALIZED VIEW kafka_consumer TO events AS
SELECT * FROM kafka_events;
```

### API Endpoint (Python/Flask)
```python
from flask import Flask, request
from clickhouse_driver import Client

app = Flask(__name__)
client = Client('ch1.example.com')

@app.route('/events', methods=['POST'])
def ingest_event():
    data = request.json
    client.execute(
        'INSERT INTO events VALUES',
        [(
            data['id'],
            data['timestamp'],
            data['user_id'],
            data['event'],
            data['value']
        )]
    )
    return {'status': 'ok'}, 200
```

---

## Step 7: Monitoring Setup

### Prometheus Config
```yaml
# /etc/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'clickhouse'
    static_configs:
      - targets: ['ch1:8123', 'ch2:8123', 'ch3:8123', 'ch4:8123', 'ch5:8123', 'ch6:8123']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

### Key Metrics to Monitor
```sql
SELECT
    metric,
    value
FROM system.metrics
WHERE metric IN (
    'ReplicasMaxAbsoluteDelay',
    'ReplicasMaxRelativeDelay',
    'Uptime',
    'Query',
    'InsertedRows',
    'InsertedBytes'
);
```

### Grafana Dashboard
- Use official ClickHouse Grafana templates
- Monitor: QPS, latency, memory, disk, replicas
- Alerts: Replica lag >60s, disk >80%, failed queries

---

## Deployment Checklist

### Pre-deployment
- [ ] Capacity planning done
- [ ] Network latency <10ms between nodes
- [ ] DNS resolvable for all hostnames
- [ ] Firewall rules configured (ports 9000, 8123, 2181)
- [ ] Disk space verified (3x data size minimum)

### Installation
- [ ] ZooKeeper 3-node cluster running
- [ ] ClickHouse installed on all nodes
- [ ] Cluster config distributed
- [ ] Tables created on cluster
- [ ] Test insert/select working

### Verification
- [ ] All nodes visible in system.clusters
- [ ] Replication queue empty
- [ ] No replica lag
- [ ] Distributed queries working
- [ ] Monitoring dashboards active

---

## Production Best Practices ✅

| Area | Best Practice |
|------|----------------|
| **Sizing** | Start 3 shards × 2 replicas |
| **Upgrade** | Rolling upgrade (one node at a time) |
| **Backups** | Daily backups to S3/distributed storage |
| **Monitoring** | Alert on replica lag, disk, memory |
| **Network** | Dedicated network for internal traffic |
| **Security** | Use TLS, strong passwords, firewalls |
| **Documentation** | Keep topology diagram updated |

---

## Troubleshooting Deployment

| Issue | Solution |
|-------|----------|
| ZK not connecting | Check firewall, verify ZK status |
| Replica stuck offline | Check network, restart ClickHouse |
| Slow queries | Profile, add indexes, check disk I/O |
| High memory | Reduce max_memory_usage, query optimization |

---

## Post-Deployment

### Backup Strategy
```bash
# Backup all data
clickhouse-backup create

# Verify backup
clickhouse-backup list

# Restore if needed
clickhouse-backup restore
```

### Regular Maintenance
```bash
# Monthly: Optimize tables
clickhouse-client -q "OPTIMIZE TABLE events FINAL;"

# Weekly: Vacuum old partitions
clickhouse-client -q "ALTER TABLE events DROP PARTITION ID 'old-partition';"
```

---

## Summary

✓ 3-shard, 2-replica cluster deployed
✓ ZooKeeper coordination running
✓ Replication working across nodes
✓ Sharding distributing data
✓ Monitoring active
✓ Ready for production workloads

---

## Architecture Decision Tree

```
Need ClickHouse?
├─ Single Node (dev/test)
│  └─ MergeTree, local storage
├─ Scale to millions of rows
│  └─ Add sharding (3-5 shards)
├─ Need high availability
│  └─ Add 2x replication per shard
└─ Enterprise production
   └─ Full 3-shard 2-replica + monitoring
```

---

## Additional Resources

- Official Docs: https://clickhouse.com/docs
- GitHub: https://github.com/ClickHouse/ClickHouse
- Community: https://clickhouse.com/community

---

*Last Updated: Jan 2026*
*Ready for Production Deployment*
