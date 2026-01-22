# ClickHouse Configuration Files - Complete Index

## Overview

This directory contains a complete, production-ready ClickHouse cluster configuration for a distributed architecture with:
- **3 Shards** (horizontal partitioning)
- **2 Replicas per Shard** (vertical replication)
- **ZooKeeper/Keeper Coordination** (leader election and metadata sync)
- **6 Predefined Users** (with different access levels and quotas)
- **Tiered Storage** (hot SSD + cold HDD)
- **Comprehensive Security** (network restrictions, password hashing, quotas)

**Total Content**: 7 files, 2,408 lines, 92 KB

---

## File Guide

### 📋 Documentation Files

#### 1. **INDEX.md** (This File)
Navigation guide for all configuration files and documentation.

#### 2. **QUICK_START.md** (8.3 KB, 313 lines)
Fast reference guide with:
- File summary table
- Key features overview
- Deployment checklist
- Configuration customization examples
- Common SQL examples
- Troubleshooting quick links
- Password generation tools
- File location reference

**Start here if you want a quick overview and immediate deployment checklist.**

#### 3. **README.md** (13 KB, 452 lines)
Comprehensive deployment guide covering:
- Detailed explanation of each configuration file
- All configuration parameters explained
- Step-by-step deployment procedure
- Security recommendations for production
- Backup and recovery strategies
- Monitoring setup
- Complete cluster topology diagram
- Common customizations
- Verification commands
- Troubleshooting guide

**Read this for in-depth understanding of all settings.**

---

### ⚙️ Configuration Files

#### 1. **config.xml** (15 KB, 443 lines)
**Main ClickHouse server configuration**

Contains 10 major sections:

1. **Listen Configuration**
   - HTTP: 8123 / 8443 (secure)
   - TCP Native: 9000 / 9440 (secure)
   - MySQL Protocol: 3306
   - PostgreSQL Protocol: 5432
   - Interserver Communication: 9009 / 9010 (secure)

2. **Path Configuration**
   - Data: `/var/lib/clickhouse/`
   - Temporary: `/var/lib/clickhouse/tmp/`
   - User Files: `/var/lib/clickhouse/user_files/`

3. **Memory and Resource Limits**
   - Max Memory: 10 GB per query
   - Max Threads: 16
   - Max Connections: 4,096
   - Max Concurrent Queries: 100

4. **Logging Configuration**
   - Log level: trace (customizable)
   - File rotation: 1 GB per file, 10 files kept
   - Query logging: Every query recorded
   - Thread logging: Per-thread metrics
   - Trace logging: Performance profiling

5. **Compression Settings**
   - Storage: LZ4 (fast) or Zstandard (high compression)
   - Network: LZ4 (fast)
   - Compression level: 1-3 (balanced)

6. **Cluster and Replication**
   - Production cluster: 3 shards × 2 replicas
   - Analytics cluster: 2 shards (no replication)
   - Internal replication: enabled
   - Interserver credentials: username/password

7. **ZooKeeper Configuration**
   - Ensemble: 3 nodes
   - Session timeout: 30 seconds
   - Operation timeout: 10 seconds
   - Retry timeout: 5 seconds

8. **Distributed DDL Settings**
   - ZK path: `/clickhouse/task_queue/ddl`
   - Profile: default
   - Execution profile: admin

9. **Merge Tree Settings**
   - Background threads: 16
   - Parallel sends per table: 5
   - Parallel fetches per table: 5

10. **Storage Policies**
    - Hot storage: SSD (`/mnt/ssd/`)
    - Cold storage: HDD (`/mnt/hdd/`)
    - Tiered policy: Auto-move to cold after size threshold
    - Free space reservation: 10 GB per disk

**Key Parameters Summary**:
```xml
<max_memory_usage>10737418240</max_memory_usage>        <!-- 10 GB -->
<max_threads>16</max_threads>
<max_connections>4096</max_connections>
<max_concurrent_queries>100</max_concurrent_queries>
<compression>lz4</compression>
<session_timeout_ms>30000</session_timeout_ms>
<snapshots_builder_threads>4</snapshots_builder_threads>
```

---

#### 2. **users.xml** (16 KB, 435 lines)
**User management and access control**

Defines 6 users with different privilege levels:

1. **default** (Development)
   - No password
   - No network restrictions
   - Unlimited quotas
   - Profile: default

2. **admin** (Administrator)
   - Password: SHA256 ("admin123")
   - Network: localhost only (127.0.0.1, ::1)
   - Profile: admin (unlimited)
   - Quota: admin (unlimited)
   - Permissions: Full DDL, access management enabled

3. **readonly** (Reporting/BI)
   - Password: SHA256 ("readonly")
   - Network: anywhere
   - Profile: readonly
   - Quota: 10,000 queries/hour
   - Memory: 2 GB limit
   - Timeout: 30 seconds
   - Readonly mode: enabled (no writes)

4. **app_user** (Application Service Account)
   - Password: SHA256 ("app_password")
   - Network: 10.0.1.0/24, 10.0.2.0/24
   - Profile: app_profile
   - Quota: app_quota
   - Memory: 5 GB limit
   - Timeout: 5 minutes
   - Queries/minute: 1,000 limit

5. **replicator** (System - Inter-Replica Communication)
   - Password: Strong hash
   - Network: 10.0.0.0/8 (internal)
   - Profile: replication_profile
   - Used for replica-to-replica data sync

6. **monitoring** (Monitoring Systems)
   - Password: SHA256 ("monitoring")
   - Network: 10.0.3.0/24
   - Profile: monitoring_profile (1 GB memory)
   - Quota: 100 queries/minute
   - Readonly mode: enabled
   - Timeout: 10 seconds

**Quotas (3-tier system)**:
- Per-second intervals
- Per-minute intervals
- Per-hour intervals
- Per-day intervals

Configurable limits:
- Queries count
- Error count
- Rows read
- Rows returned
- Execution time

**Profiles (Query Setting Templates)**:
- default: Balanced for general use
- admin: No restrictions
- readonly: Strict limits for safety
- app_profile: 5GB memory, 5 min timeout
- replication_profile: System operations
- monitoring_profile: Lightweight queries

---

#### 3. **metrika.xml** (9.5 KB, 290 lines)
**ZooKeeper and ClickHouse Keeper cluster configuration**

1. **ZooKeeper Cluster (3-node ensemble)**
   ```
   zookeeper-1:2181
   zookeeper-2:2181
   zookeeper-3:2181
   ```
   - Session timeout: 30 seconds
   - Operation timeout: 10 seconds
   - Retry timeout: 5 seconds
   - Secure ports: 2281 (optional)

2. **ClickHouse Keeper Cluster (Modern Alternative)**
   ```
   keeper-1:2181 (client), 9234 (server-to-server), 9235 (election)
   keeper-2:2181 (client), 9234 (server-to-server), 9235 (election)
   keeper-3:2181 (client), 9234 (server-to-server), 9235 (election)
   ```

3. **Remote Servers (Cluster Topology)**

   **Production Cluster** (3 shards × 2 replicas):
   ```
   Shard 01:
     - ch-prod-shard1-replica1:9000
     - ch-prod-shard1-replica2:9000
   Shard 02:
     - ch-prod-shard2-replica1:9000
     - ch-prod-shard2-replica2:9000
   Shard 03:
     - ch-prod-shard3-replica1:9000
     - ch-prod-shard3-replica2:9000
   ```

   **Analytics Cluster** (2 shards, no replication):
   ```
   Shard 01: analytics-1:9000
   Shard 02: analytics-2:9000
   ```

4. **Macros Definition**
   - Shard: 01-99 (identifies horizontal partition)
   - Replica: 01-99 (identifies copy within shard)
   - Cluster: production/analytics (cluster name)

5. **Distributed DDL**
   - Path: `/clickhouse/task_queue/ddl`

---

#### 4. **keeper_config.xml** (8.9 KB, 255 lines)
**ClickHouse Keeper (Native Coordination Service) Configuration**

ClickHouse Keeper is the modern replacement for ZooKeeper, embedded in ClickHouse.

1. **Server Configuration**
   - Listen port: 2181 (ZooKeeper-compatible)
   - Secure port: 2281 (optional TLS)
   - Server-to-server port: 9234 (Raft consensus)
   - Data directory: `/var/lib/clickhouse/keeper/`

2. **Cluster Configuration (Raft Quorum)**
   ```
   Node 1 (ID=1): keeper-1.example.com:9234
   Node 2 (ID=2): keeper-2.example.com:9234
   Node 3 (ID=3): keeper-3.example.com:9234
   ```

3. **Timing Parameters**
   - Session timeout: 30 seconds
   - Min/Max session timeout: 4-40 seconds
   - Operation timeout: 10 seconds
   - Heartbeat interval: 500 ms
   - Election timeout: 3 seconds
   - Startup timeout: 15 seconds

4. **Snapshot Management**
   - Auto-snapshot interval: 1 hour
   - Snapshots to keep: 3
   - Stale log gap: 10,000 transactions
   - Reserved log items: 100,000

5. **Performance Tuning**
   - Max connections: 10,000
   - Snapshot builder threads: 4
   - Log replayer threads: 4
   - Max memory: 8 GB
   - Batch commit size: 100 logs

6. **Compression**
   - Method: Zstandard
   - Level: 3 (balanced)
   - Format: Protobuf (pb)

7. **Security**
   - Client auth type: digest
   - Server auth: optional
   - TLS: optional (commented out)

---

#### 5. **macros.xml** (7.0 KB, 220 lines)
**Replication and Sharding Macro Definitions**

Macros are template variables used in table creation for replication setup.

**Core Macros**:
```xml
<shard>01</shard>              <!-- Horizontal partition (01-99) -->
<replica>01</replica>          <!-- Copy within shard (01-99) -->
<cluster>production</cluster>  <!-- Cluster name -->
<database>default</database>   <!-- Database name -->
<environment>production</environment> <!-- Tier: prod/staging/dev -->
<node>clickhouse-shard-1-replica-1</node> <!-- Server identifier -->
<zk_path>/clickhouse</zk_path> <!-- ZK namespace prefix -->
```

**Usage in Table Creation**:

Example 1: ReplicatedMergeTree
```sql
CREATE TABLE events ON CLUSTER {cluster}
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/{database}/{table}',
    '{replica}'
)
ORDER BY id
PARTITION BY toYYYYMM(event_time);
```
Expands on shard-1-replica-1 to:
```
ReplicatedMergeTree('/clickhouse/tables/01/default/events', '01')
```

Example 2: Distributed Table
```sql
CREATE TABLE events_dist ON CLUSTER {cluster}
ENGINE = Distributed('{cluster}', '{database}', events);
```
Expands to:
```
ENGINE = Distributed('production', 'default', events)
```

**ZooKeeper Path Organization**:
```
/clickhouse                    (zk_path)
├── tables
│   ├── 01                     (shard)
│   │   ├── default            (database)
│   │   │   ├── events         (table)
│   │   │   │   ├── replicas
│   │   │   │   │   ├── 01     (replica 1)
│   │   │   │   │   └── 02     (replica 2)
│   │   │   │   └── logs
│   │   ├── 02
│   │   └── 03
│   └── task_queue
│       └── ddl
```

**Per-Server Customization**:
```
shard-1-replica-1: <shard>01</shard> <replica>01</replica>
shard-1-replica-2: <shard>01</shard> <replica>02</replica>
shard-2-replica-1: <shard>02</shard> <replica>01</replica>
shard-2-replica-2: <shard>02</shard> <replica>02</replica>
shard-3-replica-1: <shard>03</shard> <replica>01</replica>
shard-3-replica-2: <shard>03</shard> <replica>02</replica>
```

---

## Deployment Workflow

### 1. Pre-Deployment Phase
- [ ] Review all configuration files
- [ ] Customize hostnames and IPs for your environment
- [ ] Generate secure passwords (see QUICK_START.md)
- [ ] Plan storage infrastructure (paths for data, temp, keeper)
- [ ] Prepare ZooKeeper/Keeper cluster

### 2. Configuration Phase
- [ ] Copy all .xml files to `/etc/clickhouse-server/`
- [ ] Customize `macros.xml` for each server (shard/replica numbers)
- [ ] Create storage directories with correct permissions
- [ ] Set file ownership: `chown clickhouse:clickhouse`
- [ ] Set file permissions: `chmod 640`

### 3. Validation Phase
- [ ] Validate XML syntax: `xmllint *.xml`
- [ ] Run: `clickhouse-server --validate-config`
- [ ] Test connectivity to ZooKeeper/Keeper
- [ ] Verify network ports are accessible

### 4. Deployment Phase
- [ ] Start ClickHouse services
- [ ] Monitor logs for startup errors
- [ ] Run: `clickhouse-client -q "SELECT 1"`
- [ ] Verify cluster: `SELECT * FROM system.clusters`

### 5. Post-Deployment Phase
- [ ] Test user connections (all 6 users)
- [ ] Create test ReplicatedMergeTree table
- [ ] Verify replication: `SELECT * FROM system.replicas`
- [ ] Test distributed queries
- [ ] Configure monitoring and alerting
- [ ] Establish backup procedures

---

## Configuration Relationships

```
config.xml (Main Server Config)
├── Defines: Networking, Resources, Logging, Compression
├── References: users.xml, metrika.xml, macros.xml
└── Remote Servers: 3 shards × 2 replicas
    └── Maps to macros.xml: {shard}, {replica}
    └── Uses ZK from metrika.xml: 3 nodes
    └── Auth: Users from users.xml

users.xml (User Management)
├── Defines: 6 Users with different roles
├── Per-user quotas (queries, memory, rows)
└── Per-user profiles (settings templates)

metrika.xml (Cluster Topology)
├── Defines: ZooKeeper 3-node ensemble
├── Defines: ClickHouse Keeper 3-node ensemble
├── Defines: Remote servers (production, analytics)
└── References: Cluster names used by macros.xml

keeper_config.xml (Keeper Server)
├── Single file for all 3 Keeper nodes
├── Each node has unique server_id (1, 2, 3)
└── Cluster discovery via raft_configuration

macros.xml (Replication Templates)
├── Defines: {shard}, {replica}, {cluster}
├── Uses: Cluster names from metrika.xml
├── Generates: ZooKeeper paths for replication
└── Per-server customization required
```

---

## Security Features

### Authentication
- SHA256 password hashing (recommended)
- Double SHA1 legacy support
- Plaintext passwords (development only)
- Per-user network restrictions (IP whitelist)

### Authorization
- 6 predefined roles with different permissions
- Profile-based settings per user
- Quota enforcement (per-second to per-day)
- Readonly mode for reporting users
- Admin user with full control

### Network
- Interserver credentials (username/password)
- Optional TLS/SSL support
- Network isolation (10.0.0.0/8 for internal)
- External facing: restricted to HTTP/TCP

### Audit
- Query logging (every query recorded)
- Thread logging (per-thread metrics)
- Trace logging (performance profiling)
- Error logging (separate error log)

---

## Production Checklist

Before deploying to production:

- [ ] All XML files are valid (xmllint check passes)
- [ ] Hostnames and IPs customized for your environment
- [ ] Passwords changed from examples
- [ ] TLS certificates configured (if security required)
- [ ] Storage paths verified (SSD/HDD availability)
- [ ] ZooKeeper/Keeper cluster operational
- [ ] Network connectivity between all nodes verified
- [ ] Firewall rules allow necessary ports
- [ ] Backup strategy defined and tested
- [ ] Monitoring and alerting configured
- [ ] Disaster recovery procedures documented
- [ ] Load testing completed successfully

---

## Getting Started

**New to this configuration?** Start here:
1. **Read**: QUICK_START.md (5 min overview)
2. **Read**: README.md (20 min deep dive)
3. **Review**: Individual .xml files for your use case
4. **Customize**: Update hostnames, passwords, paths
5. **Deploy**: Follow deployment checklist
6. **Verify**: Run verification commands from README

**Updating existing cluster?**
1. **Review**: Changes in README.md "Customization" section
2. **Backup**: Current configuration files
3. **Update**: Specific sections in config files
4. **Validate**: XML syntax and ClickHouse validation
5. **Test**: On staging cluster first
6. **Deploy**: With minimal downtime strategy

**Troubleshooting issues?**
1. Check logs: `/var/log/clickhouse-server/clickhouse-server.log`
2. Review: README.md "Troubleshooting" section
3. Run: Verification commands from QUICK_START.md
4. Check: System tables (system.replicas, system.processes, etc.)

---

## File Statistics

| File | Size | Lines | Purpose |
|------|------|-------|---------|
| config.xml | 15 KB | 443 | Main server config |
| users.xml | 16 KB | 435 | User & quota management |
| metrika.xml | 9.5 KB | 290 | Cluster & ZK definition |
| keeper_config.xml | 8.9 KB | 255 | Keeper coordination |
| macros.xml | 7.0 KB | 220 | Replication templates |
| README.md | 13 KB | 452 | Detailed guide |
| QUICK_START.md | 8.3 KB | 313 | Quick reference |
| INDEX.md | This | File | Navigation guide |

**Total**: 8 files, 92 KB, 2,408 lines

---

## Support & Resources

### Official Documentation
- Main Site: https://clickhouse.com/
- Documentation: https://clickhouse.com/docs/
- Configuration: https://clickhouse.com/docs/operations/configuration-files/
- Replication: https://clickhouse.com/docs/operations/replication/

### Configuration Reference
- Server Configuration: config.xml schema
- User Configuration: users.xml schema
- Cluster Management: remote_servers definition
- Table Engines: ReplicatedMergeTree, Distributed

### Community & Support
- GitHub Issues: https://github.com/ClickHouse/ClickHouse
- Community Slack: https://clickhouse.com/community/
- Official Blog: https://clickhouse.com/blog/

---

**Last Updated**: January 22, 2026
**Configuration Version**: 24.x Compatible
**Cluster Type**: Production 3-Shard 2-Replica Setup
**Status**: Ready for Deployment
