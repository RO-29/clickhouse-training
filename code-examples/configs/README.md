# ClickHouse Configuration Files

This directory contains production-ready ClickHouse configuration files for a distributed, replicated cluster setup.

## Files Overview

### 1. **config.xml** (15 KB)
Main ClickHouse server configuration file containing:
- **Network Configuration**: HTTP (8123), TCP (9000), MySQL (3306), PostgreSQL (5432) ports
- **Interserver Communication**: Port 9009 for replication traffic
- **Path Settings**: Data storage, temporary files, user files locations
- **Resource Limits**: Memory (10GB), thread counts, connection limits
- **Logging Configuration**: Query logs, thread logs, trace logs with rotation
- **Compression Settings**: LZ4/Zstandard compression for storage and network
- **Cluster Topology**: 3 shards × 2 replicas per shard distributed setup
- **ZooKeeper Configuration**: 3-node ensemble for coordination
- **Distributed DDL Settings**: ON CLUSTER query execution paths
- **Merge Tree Settings**: Background merge and replication thread pools
- **Storage Policies**: Hot (SSD) and cold (HDD) tiered storage
- **Dictionary Configuration**: External dictionary support

**Key Parameters**:
```xml
<max_memory_usage>10737418240</max_memory_usage>     <!-- 10GB per query -->
<max_threads>16</max_threads>                         <!-- 16 threads -->
<max_connections>4096</max_connections>               <!-- 4096 concurrent connections -->
<max_concurrent_queries>100</max_concurrent_queries> <!-- 100 simultaneous queries -->
```

### 2. **users.xml** (16 KB)
User management and access control with 6 predefined users:

#### Default User
- No restrictions, for basic connections
- Empty password (development only)

#### Admin User
- Full administrative privileges
- Access restricted to localhost (127.0.0.1)
- Unlimited quotas and resource access
- Can create users and manage access

#### Readonly User
- Read-only queries only
- No DDL, no INSERT operations
- Memory limit: 2GB
- Timeout: 30 seconds

#### App User (Application/Service Account)
- For production applications
- Network restricted to 10.0.1.0/24 and 10.0.2.0/24
- Memory limit: 5GB
- Timeout: 5 minutes
- Enforced quotas: 1000 queries/minute, 100M rows/minute

#### Replicator User (Interserver Communication)
- Used for replica-to-replica communication
- Restricted to internal network (10.0.0.0/8)
- Required for replication operations

#### Monitoring User
- For Prometheus/monitoring systems
- Read-only access
- Memory limit: 1GB
- Timeout: 10 seconds

**Password Hashing Methods**:
```xml
<!-- SHA256 hashing (recommended) -->
<password_sha256_hex>e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855</password_sha256_hex>

<!-- Generate: echo -n 'password' | sha256sum | cut -c1-64 -->
```

**Quotas Examples**:
- Per-minute, per-hour, per-day intervals
- Configurable limits: queries, errors, rows read/returned, execution time
- Prevents runaway queries and resource exhaustion

### 3. **metrika.xml** (9.5 KB)
ZooKeeper and ClickHouse Keeper cluster configuration:

#### ZooKeeper Cluster (3-node ensemble)
- Recommended for production HA setups
- Nodes: zookeeper-1, zookeeper-2, zookeeper-3 on port 2181
- Session timeout: 30 seconds
- Operation timeout: 10 seconds

#### ClickHouse Keeper Configuration
- Modern alternative to ZooKeeper (embedded in ClickHouse)
- Same 3-node ensemble structure
- Inter-server communication ports: 9234, 9235

#### Cluster Definitions
- **Production Cluster**: 3 shards × 2 replicas each
  - Shard 1: Replicas on ch-prod-shard1-replica1, ch-prod-shard1-replica2
  - Shard 2: Replicas on ch-prod-shard2-replica1, ch-prod-shard2-replica2
  - Shard 3: Replicas on ch-prod-shard3-replica1, ch-prod-shard3-replica2
- **Analytics Cluster**: 2 shards without replication for historical data

#### Macros Definition
- `{shard}`: Shard identifier (01, 02, 03, etc.)
- `{replica}`: Replica number within shard (01, 02, etc.)
- `{cluster}`: Cluster name for distributed operations

### 4. **keeper_config.xml** (8.9 KB)
ClickHouse Keeper (native coordination service) configuration:

#### Server Configuration
- Listen port: 2181 (ZooKeeper-compatible)
- Secure port: 2281 (optional TLS)
- Server-to-server port: 9234 (Raft consensus)
- Data storage: /var/lib/clickhouse/keeper

#### Timing Parameters
- Session timeout: 30 seconds
- Operation timeout: 10 seconds
- Heartbeat interval: 500ms
- Election timeout: 3 seconds
- Startup timeout: 15 seconds

#### Snapshot & Log Management
- Auto-snapshot every 1 hour
- Keep 3 most recent snapshots
- Commit logs in batches of 100 for performance
- Reserved log items: 100,000

#### Performance Tuning
- Max connections: 10,000
- Snapshot builder threads: 4
- Log replayer threads: 4
- Max memory: 8GB
- Compression: Zstandard (level 3)

#### Cluster Configuration
- Server 1: keeper-1.example.com:9234
- Server 2: keeper-2.example.com:9234
- Server 3: keeper-3.example.com:9234

### 5. **macros.xml** (7.0 KB)
Replication and sharding macro definitions with extensive examples:

#### Key Macros
```xml
<shard>01</shard>           <!-- Shard number (horizontal partitioning) -->
<replica>01</replica>       <!-- Replica number within shard (vertical replication) -->
<cluster>production</cluster> <!-- Cluster name -->
<database>default</database> <!-- Database name -->
<environment>production</environment> <!-- Environment tier -->
<node>clickhouse-shard-1-replica-1</node> <!-- Server identifier -->
```

#### Usage in Table Definitions

**ReplicatedMergeTree with Macros**:
```sql
CREATE TABLE events ON CLUSTER {cluster}
(
    event_id UInt64,
    event_time DateTime,
    event_type String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/{database}/{table}',
    '{replica}'
)
ORDER BY (event_time, event_id)
PARTITION BY toYYYYMM(event_time);
```

Expands on shard-1-replica-1 to:
```
ReplicatedMergeTree('/clickhouse/tables/01/default/events', '01')
```

**Distributed Table**:
```sql
CREATE TABLE events_distributed ON CLUSTER {cluster}
(
    event_id UInt64,
    event_time DateTime,
    event_type String
)
ENGINE = Distributed('{cluster}', '{database}', events);
```

#### ZooKeeper Path Organization
```
/clickhouse
├── tables
│   ├── 01 (Shard 1)
│   │   ├── default
│   │   │   ├── events
│   │   │   │   ├── replicas
│   │   │   │   │   ├── 01 (Replica 1)
│   │   │   │   │   └── 02 (Replica 2)
│   │   │   │   └── logs
│   │   ├── 02 (Shard 2)
│   │   └── 03 (Shard 3)
│   └── task_queue
│       └── ddl
```

## Configuration Deployment

### Step 1: Copy Files to Servers

```bash
# Copy to primary config directory
scp config.xml clickhouse@shard1-replica1:/etc/clickhouse-server/

# Copy users and coordination configs
scp users.xml clickhouse@shard1-replica1:/etc/clickhouse-server/
scp metrika.xml clickhouse@shard1-replica1:/etc/clickhouse-server/
scp keeper_config.xml clickhouse@shard1-replica1:/etc/clickhouse-server/

# Copy macros (customize per server)
scp macros.xml clickhouse@shard1-replica1:/etc/clickhouse-server/
```

### Step 2: Customize Per Server

For **shard1-replica1**:
```xml
<macros>
    <shard>01</shard>
    <replica>01</replica>
    <cluster>production</cluster>
</macros>
```

For **shard1-replica2**:
```xml
<macros>
    <shard>01</shard>
    <replica>02</replica>
    <cluster>production</cluster>
</macros>
```

For **shard2-replica1**:
```xml
<macros>
    <shard>02</shard>
    <replica>01</replica>
    <cluster>production</cluster>
</macros>
```

### Step 3: Set File Permissions

```bash
sudo chown clickhouse:clickhouse /etc/clickhouse-server/*.xml
sudo chmod 640 /etc/clickhouse-server/config.xml
sudo chmod 640 /etc/clickhouse-server/users.xml
sudo chmod 640 /etc/clickhouse-server/metrika.xml
```

### Step 4: Validate Configuration

```bash
# Check for XML syntax errors
clickhouse-server --validate-config

# Test connectivity to ZooKeeper
echo "stat" | nc zookeeper-1 2181
```

### Step 5: Restart ClickHouse

```bash
# Graceful restart (waits for queries to complete)
sudo systemctl restart clickhouse-server

# Check logs
tail -f /var/log/clickhouse-server/clickhouse-server.log
```

## Security Recommendations for Production

### 1. Change Default Passwords
All user passwords in the examples are provided for reference. Replace them:

```bash
# Generate strong password hash
echo -n 'your_strong_password_here' | sha256sum | cut -c1-64
```

### 2. Network Isolation
- Restrict ZooKeeper connections to internal network
- Use firewall rules to limit inter-server traffic
- Enable TLS for interserver communication

```xml
<interserver_http_port_secure>9010</interserver_http_port_secure>
<tcp_port_secure>9440</tcp_port_secure>
<http_port_secure>8443</http_port_secure>
```

### 3. User Permissions
- Never use default admin user in production
- Create dedicated service accounts with minimal privileges
- Implement row-level security with database-level restrictions

### 4. Resource Limits
- Adjust memory limits based on available RAM
- Set appropriate query timeouts for your workload
- Monitor quota usage and adjust as needed

### 5. Backup and Recovery
- Regularly backup cluster metadata from ZooKeeper
- Test restoration procedures
- Maintain backup of critical system tables

```bash
# Backup ZooKeeper data
zkServer.sh stop
tar czf zk-backup-$(date +%Y%m%d).tar.gz /var/lib/zookeeper
zkServer.sh start
```

### 6. Monitoring
- Configure centralized logging
- Set up alerts for replica lag
- Monitor disk usage on hot/cold tiers

## Cluster Topology Reference

### 3 Shards × 2 Replicas Configuration

```
Production Cluster
├── Shard 01
│   ├── Replica 01 (Primary) - ch-shard1-replica1
│   │   └── Port 9000, ZK: shard=01, replica=01
│   └── Replica 02 (Backup) - ch-shard1-replica2
│       └── Port 9000, ZK: shard=01, replica=02
├── Shard 02
│   ├── Replica 01 (Primary) - ch-shard2-replica1
│   │   └── Port 9000, ZK: shard=02, replica=01
│   └── Replica 02 (Backup) - ch-shard2-replica2
│       └── Port 9000, ZK: shard=02, replica=02
└── Shard 03
    ├── Replica 01 (Primary) - ch-shard3-replica1
    │   └── Port 9000, ZK: shard=03, replica=01
    └── Replica 02 (Backup) - ch-shard3-replica2
        └── Port 9000, ZK: shard=03, replica=02

ZooKeeper Coordination (Port 2181)
├── Node 1 - zookeeper-1
├── Node 2 - zookeeper-2
└── Node 3 - zookeeper-3
```

## Common Customizations

### Reduce Resource Usage (Development)
```xml
<!-- config.xml -->
<max_memory_usage>1073741824</max_memory_usage>      <!-- 1GB instead of 10GB -->
<max_threads>4</max_threads>                         <!-- 4 threads instead of 16 -->
<max_concurrent_queries>10</max_concurrent_queries> <!-- 10 instead of 100 -->
```

### Increase Performance (Production)
```xml
<max_threads>32</max_threads>
<background_pool_size>32</background_pool_size>
<background_move_pool_size>16</background_move_pool_size>
```

### Enable TLS
```xml
<tcp_port_secure>9440</tcp_port_secure>
<http_port_secure>8443</http_port_secure>

<openSSL>
    <server>
        <certificateFile>/path/to/server.crt</certificateFile>
        <privateKeyFile>/path/to/server.key</privateKeyFile>
        <dhParamsFile>/path/to/dhparam.pem</dhParamsFile>
        <verificationMode>none</verificationMode>
    </server>
</openSSL>
```

### Single-Node Deployment
Remove cluster configuration and use:
```xml
<shard>01</shard>
<replica>01</replica>
```
Use standard MergeTree (not ReplicatedMergeTree) without ZooKeeper.

## Verification Commands

```bash
# Check cluster status
clickhouse-client -q "SELECT * FROM system.clusters"

# Verify replication
clickhouse-client -q "SELECT database, table, is_leader, absolute_delay, replica_name FROM system.replicas"

# Check server version
clickhouse-client -q "SELECT version()"

# Monitor active queries
clickhouse-client -q "SELECT * FROM system.processes"

# Check ZooKeeper connectivity
clickhouse-client -q "SELECT * FROM system.zookeeper WHERE path = '/clickhouse'"
```

## Troubleshooting

### Replica Not Replicating
```bash
# Check replica status
clickhouse-client -q "SELECT database, table, replica_name, is_leader FROM system.replicas"

# Check ZooKeeper path permissions
echo "stat /clickhouse/tables/01" | nc zookeeper-1 2181

# Check logs for replication errors
tail -100 /var/log/clickhouse-server/clickhouse-server.err.log | grep -i replica
```

### High Memory Usage
- Reduce `max_memory_usage` in profiles
- Lower `background_pool_size` for merges
- Implement aggressive TTL policies

### Slow Queries
- Enable query logging: check `query_log` table
- Use `EXPLAIN` to analyze query plans
- Consider partitioning strategy

### ZooKeeper Connection Issues
```bash
# Test ZooKeeper connectivity
echo "ping" | nc zookeeper-1 2181

# Check ZooKeeper logs
tail -100 /var/log/zookeeper/zookeeper.log
```

## References

- [ClickHouse Official Documentation](https://clickhouse.com/docs/)
- [Replication and HA Guide](https://clickhouse.com/docs/operations/replication/)
- [Cluster Deployment](https://clickhouse.com/docs/operations/configuration-files/index.html)
- [User Management](https://clickhouse.com/docs/operations/access-rights/)
