# ClickHouse Docker Configuration Index

Welcome to the comprehensive Docker configuration documentation for the ClickHouse Knowledge Series training project.

## Start Here

### New to These Configurations?
1. Start with **[QUICK_START.md](QUICK_START.md)** - 5-minute setup guide
2. Then read **[README.md](README.md)** - Complete technical documentation
3. Reference **[FILES_MANIFEST.md](FILES_MANIFEST.md)** - What's included

### Need to Deploy?
1. Run **[verify-setup.sh](verify-setup.sh)** - Check your environment
2. Choose your configuration below
3. Follow the module-specific guides

## Documentation Map

### Primary Documents

| Document | Purpose | Read Time | Audience |
|----------|---------|-----------|----------|
| [QUICK_START.md](QUICK_START.md) | Get running in 5 minutes | 10 min | Everyone |
| [README.md](README.md) | Full technical reference | 30 min | Operators |
| [FILES_MANIFEST.md](FILES_MANIFEST.md) | File inventory and specs | 15 min | Architects |
| [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) | Overview and summary | 10 min | Managers |
| [INDEX.md](INDEX.md) | This navigation guide | 5 min | Everyone |

## Docker Compose Files Guide

### Choose Your Setup

#### 1. Single Node (Learning & Development)
**File**: `docker-compose-single.yml`

Best for:
- Learning ClickHouse basics
- Module 1-6 training
- Development and testing
- Quick prototyping

Quick Start:
```bash
docker-compose -f docker-compose-single.yml up -d
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server
```

📖 See: [README.md - Single Node](README.md#1-docker-compose-singleyml)

---

#### 2. Cluster (Production Features)
**File**: `docker-compose-cluster.yml`

Best for:
- Module 3-8 training
- Sharding and replication
- Production simulation
- Advanced operations

Architecture:
- 3 shards × 2 replicas each
- 3 ZooKeeper nodes
- Full replication support

Quick Start:
```bash
docker-compose -f docker-compose-cluster.yml up -d
docker-compose -f docker-compose-cluster.yml exec clickhouse-s1r1 \
  clickhouse-client --host clickhouse-s1r1 \
  --query "SELECT * FROM system.clusters"
```

📖 See: [README.md - Cluster](README.md#2-docker-compose-clusteryml)

---

#### 3. Kafka Integration (Real-time Streaming)
**File**: `docker-compose-kafka.yml`

Best for:
- Module 9 training
- Stream processing
- Real-time data ingestion
- Kafka integration testing

Components:
- Kafka broker with topics
- ZooKeeper coordination
- Kafka UI for management
- ClickHouse with stream tables

Quick Start:
```bash
docker-compose -f docker-compose-kafka.yml up -d
# Open browser: http://localhost:8080 (Kafka UI)
```

📖 See: [README.md - Kafka](README.md#3-docker-compose-kafkayml)

---

#### 4. Data Migration (CDC & ETL)
**File**: `docker-compose-migration.yml`

Best for:
- Module 10 training
- Data migration patterns
- Change Data Capture (CDC)
- Multi-source ingestion

Data Sources:
- MongoDB (document)
- MySQL (relational)
- Debezium CDC platform
- Kafka streaming

Quick Start:
```bash
docker-compose -f docker-compose-migration.yml up -d
# Sources: MongoDB (27017), MySQL (3306)
# CDC: Debezium (8083), Kafka (9092)
# Target: ClickHouse (8123, 9000)
```

📖 See: [README.md - Migration](README.md#4-docker-compose-migrationyml)

---

#### 5. Monitoring Stack (Observability)
**File**: `docker-compose-monitoring.yml`

Best for:
- Monitoring any setup
- Performance metrics
- Alert configuration
- Dashboard creation

Components:
- Prometheus (metrics collection)
- Grafana (dashboards)
- AlertManager (alerting)
- Node Exporter (system metrics)

Access:
```bash
# Grafana: http://localhost:3000 (admin/admin_password)
# Prometheus: http://localhost:9090
# AlertManager: http://localhost:9093
```

📖 See: [README.md - Monitoring](README.md#6-docker-compose-monitoringyml)

---

## Configuration Files

### ClickHouse Configuration XMLs

| File | Purpose | When to Use |
|------|---------|------------|
| `configs/single-node.xml` | Single node settings | docker-compose-single.yml |
| `configs/cluster-node.xml` | Cluster node settings | docker-compose-cluster.yml |
| `configs/kafka-node.xml` | Kafka settings | docker-compose-kafka.yml |
| `configs/migration-node.xml` | Migration settings | docker-compose-migration.yml |
| `configs/monitoring-node.xml` | Monitoring settings | docker-compose-monitoring.yml |

### Advanced Configurations

**Cluster Macros** (6 files)
- Define shard/replica identifiers
- Located in: `configs/macros-*.xml`
- Auto-loaded by cluster nodes

**Monitoring** (3 files)
- `prometheus.yml` - Scrape configuration
- `alert-rules.yml` - 20+ alert conditions
- `alertmanager.yml` - Alert routing

**CDC Platform** (2 files)
- `debezium-connectors/mongodb-connector.json`
- `debezium-connectors/mysql-connector.json`

**Grafana** (3 files)
- `grafana/provisioning/datasources/`
- `grafana/provisioning/dashboards/`
- `grafana/dashboards/`

📖 Complete details: [FILES_MANIFEST.md](FILES_MANIFEST.md)

## Initialization Scripts

### ClickHouse Databases

**Base Setup**: `init-scripts/00-base-setup.sql`
- Creates 6 databases
- Sample tables with data
- Monitoring tables
- ~400 lines

**Kafka Integration**: `init-scripts/kafka-setup.sql`
- Kafka table engines
- Materialized views
- Stream aggregations
- ~200 lines

**Data Migration**: `init-scripts/clickhouse-migration-setup.sql`
- CDC target tables
- Reconciliation tables
- Migration audit logs
- ~350 lines

**Monitoring**: `init-scripts/monitoring-setup.sql`
- System metrics tables
- Performance tracking
- Aggregated views
- ~250 lines

### Source Databases

**MongoDB**: `init-scripts/mongodb-setup.js`
- 4 collections
- 15+ sample documents
- Replica set enabled
- ~180 lines

**MySQL**: `init-scripts/mysql-setup.sql`
- 5 tables with relationships
- 50+ sample rows
- Binary logging enabled
- ~320 lines

📖 Details: [README.md - Initialization](README.md#directory-structure)

## Module Learning Paths

### Module 1-2: Fundamentals
```
Start: docker-compose-single.yml
Learn: Basic operations, queries, table creation
Follow: README.md section "Docker Compose Files"
```

### Module 3: Sharding
```
Start: docker-compose-cluster.yml
Learn: Shard definition, distributed tables
Follow: README.md - Cluster Configuration
```

### Module 4: Replication
```
Start: docker-compose-cluster.yml
Learn: Replica synchronization, ZooKeeper
Follow: README.md - Production Considerations
```

### Module 5: Cluster Deployment
```
Start: docker-compose-cluster.yml
Learn: Full cluster topology, DDL distribution
Follow: README.md - Cluster Topology
```

### Module 6-8: Operations
```
Start: docker-compose-cluster.yml
Add: docker-compose-monitoring.yml
Learn: Query optimization, backup, recovery
Follow: README.md - Advanced Topics
```

### Module 9: Kafka Ingestion
```
Start: docker-compose-kafka.yml
Learn: Stream tables, Kafka integration
Follow: README.md - Kafka Configuration
```

### Module 10: Data Migration
```
Start: docker-compose-migration.yml
Learn: CDC, Debezium, multi-source migration
Follow: README.md - Migration Configuration
```

## Ports Reference

Quick port lookup:

```
ClickHouse HTTP:       8123
ClickHouse Native:     9000
ClickHouse Interserver: 9009
Kafka:                 9092
ZooKeeper:             2181
Prometheus:            9090
Grafana:               3000
AlertManager:          9093
Node Exporter:         9100
cAdvisor:              8085
Kafka UI:              8080
MongoDB:               27017
MySQL:                 3306
Debezium:              8083
```

Full reference: [README.md - Ports](README.md#ports)

## Common Commands

### View Status
```bash
docker-compose -f docker-compose-*.yml ps
```

### View Logs
```bash
docker-compose -f docker-compose-*.yml logs -f clickhouse-server
```

### Execute Query
```bash
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server --query "SELECT 1"
```

### Stop Services
```bash
docker-compose -f docker-compose-*.yml down
```

### Clean Everything
```bash
docker-compose -f docker-compose-*.yml down -v
```

More commands: [QUICK_START.md - Common Operations](QUICK_START.md#common-operations)

## Troubleshooting Guide

### Issues by Type

**Startup Issues**
- Container won't start
- Health checks failing
- Ports in use
→ See: [README.md - Troubleshooting](README.md#troubleshooting)

**Connection Issues**
- Can't connect to ClickHouse
- Network problems
- Host resolution
→ See: [QUICK_START.md - Troubleshooting](QUICK_START.md#troubleshooting)

**Performance Issues**
- High memory usage
- Slow queries
- Merge stalls
→ See: [README.md - Production Considerations](README.md#production-considerations)

**Data Issues**
- Replication lag
- Missing data
- Failed inserts
→ See: [README.md - Monitoring](README.md#monitoring-and-debugging)

## Environment Setup

### Verify Your System
```bash
./verify-setup.sh
```

Checks:
- Docker installation ✓
- Docker Compose version ✓
- System resources ✓
- Port availability ✓
- Configuration files ✓

### Configure Environment
```bash
cp .env.example .env
# Edit .env as needed
```

Variables: [.env.example](.env.example)

## File Organization

```
docker/
├── Documentation (5 files)
│   ├── README.md (main reference)
│   ├── QUICK_START.md (getting started)
│   ├── FILES_MANIFEST.md (inventory)
│   ├── DEPLOYMENT_SUMMARY.md (overview)
│   └── INDEX.md (this file)
│
├── Compose Files (5 files)
│   ├── docker-compose-single.yml
│   ├── docker-compose-cluster.yml
│   ├── docker-compose-kafka.yml
│   ├── docker-compose-migration.yml
│   └── docker-compose-monitoring.yml
│
├── Configurations (20+ files)
│   ├── configs/
│   │   ├── *.xml (ClickHouse configs)
│   │   ├── *.yml (Prometheus, AlertManager)
│   │   ├── *.json (Debezium, Grafana)
│   │   └── grafana/ (Grafana provisioning)
│   │
├── Initialization (6 files)
│   └── init-scripts/
│       ├── *.sql (ClickHouse, MySQL)
│       └── *.js (MongoDB)
│
├── Utilities (3 files)
│   ├── Dockerfile-custom
│   ├── verify-setup.sh
│   └── .env.example
```

## Quick Reference Links

### By Use Case

**I want to...**

- [Learn ClickHouse](QUICK_START.md) → Start with Single Node
- [Run a Cluster](README.md#2-docker-compose-clusteryml) → Use Cluster Compose
- [Stream Data](README.md#3-docker-compose-kafkayml) → Use Kafka Compose
- [Migrate Data](README.md#4-docker-compose-migrationyml) → Use Migration Compose
- [Monitor Everything](README.md#6-docker-compose-monitoringyml) → Use Monitoring Stack
- [Verify Setup](verify-setup.sh) → Run verification script
- [Find a File](FILES_MANIFEST.md) → Check manifest
- [Troubleshoot](README.md#troubleshooting) → See troubleshooting guide

### By Module

- Module 1-2: [Single Node Setup](QUICK_START.md#option-1-single-node-development)
- Module 3-4: [Cluster Setup](QUICK_START.md#option-2-full-cluster-production-like)
- Module 5: [Deployment Guide](README.md#2-docker-compose-clusteryml)
- Module 6-8: [Operations Guide](README.md#production-considerations)
- Module 9: [Kafka Guide](QUICK_START.md#option-3-kafka-integration-module-9)
- Module 10: [Migration Guide](QUICK_START.md#option-4-monitoring-stack)

## Support & Help

### Documentation Hierarchy

```
START HERE → QUICK_START.md (fastest path)
   ↓
Need details? → README.md (comprehensive reference)
   ↓
Looking for files? → FILES_MANIFEST.md (complete inventory)
   ↓
Project overview? → DEPLOYMENT_SUMMARY.md (big picture)
   ↓
Need navigation? → INDEX.md (this document)
```

### External Resources

- [ClickHouse Official Docs](https://clickhouse.com/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## Getting Started Checklist

- [ ] Read this INDEX.md (5 min)
- [ ] Run `./verify-setup.sh` (2 min)
- [ ] Read QUICK_START.md (10 min)
- [ ] Choose docker-compose file for your module
- [ ] Start services: `docker-compose -f <file> up -d`
- [ ] Wait for health checks to pass (30-90 sec)
- [ ] Execute test queries
- [ ] Access monitoring dashboards (if using monitoring)
- [ ] Reference README.md for detailed operations

## Status & Version

- **Version**: 1.0
- **Status**: Production Ready
- **Created**: January 22, 2026
- **Last Updated**: January 22, 2026
- **Files**: 40+
- **Documentation**: 2000+ lines
- **Modules Covered**: All 10 modules
- **Features**: 100% complete

---

## Quick Start (TL;DR)

```bash
# 1. Verify setup
./verify-setup.sh

# 2. Choose configuration
# Single node (learning):
docker-compose -f docker-compose-single.yml up -d

# OR Cluster (advanced):
docker-compose -f docker-compose-cluster.yml up -d

# 3. Wait for startup (30-90 seconds)
docker-compose ps

# 4. Connect and test
docker-compose exec clickhouse-client \
  clickhouse-client --host clickhouse-server

# 5. Access web interfaces
# Grafana: http://localhost:3000 (if monitoring active)
# Prometheus: http://localhost:9090
# Kafka UI: http://localhost:8080
```

---

**For detailed help, see [README.md](README.md)**

**For quick start, see [QUICK_START.md](QUICK_START.md)**

**Happy learning with ClickHouse!**
