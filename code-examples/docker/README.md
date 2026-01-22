# ClickHouse Docker Configurations

Comprehensive Docker setups for the ClickHouse Knowledge Series training project. Each configuration is production-grade with proper networking, volumes, healthchecks, and resource limits.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration Overview](#configuration-overview)
3. [Docker Compose Files](#docker-compose-files)
4. [Directory Structure](#directory-structure)
5. [Usage Instructions](#usage-instructions)
6. [Production Considerations](#production-considerations)
7. [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 8GB+ RAM (16GB+ recommended for cluster)
- 20GB+ available disk space

### Basic Single-Node Setup

```bash
# Navigate to docker directory
cd code-examples/docker

# Start single node ClickHouse with client
docker-compose -f docker-compose-single.yml up -d

# Check status
docker-compose -f docker-compose-single.yml ps

# Access ClickHouse
docker-compose -f docker-compose-single.yml exec clickhouse-client clickhouse-client --host clickhouse-server

# Stop services
docker-compose -f docker-compose-single.yml down
```

## Configuration Overview

### Environments

All configurations include:

- **Networking**: Custom bridge networks for service isolation
- **Volumes**: Persistent storage for data and logs
- **Health Checks**: Automatic health monitoring with restart policies
- **Resource Limits**: CPU and memory constraints for stability
- **Logging**: Centralized logging with proper rotation
- **Security**: User/password management, access controls

### Ports

| Service | Port | Purpose |
|---------|------|---------|
| ClickHouse HTTP | 8123 | Web UI, REST API |
| ClickHouse Native | 9000 | Native protocol |
| ClickHouse SSL | 9009 | Interserver communication |
| Kafka | 9092 | Kafka broker |
| ZooKeeper | 2181 | Coordination service |
| Prometheus | 9090 | Metrics collection |
| Grafana | 3000 | Dashboards |
| AlertManager | 9093 | Alert management |
| Node Exporter | 9100 | System metrics |

## Docker Compose Files

### 1. docker-compose-single.yml

**Purpose**: Single-node ClickHouse with client for development and testing

**Services**:
- clickhouse-server: Single ClickHouse instance
- clickhouse-client: Client container for executing queries

**Resources**:
- CPU: 1-2 cores
- Memory: 2-4GB
- Disk: ~20GB

**Usage**:
```bash
docker-compose -f docker-compose-single.yml up -d

# Connect and run queries
docker-compose -f docker-compose-single.yml exec clickhouse-client clickhouse-client \
  --host clickhouse-server --query "SELECT version()"

# View logs
docker-compose -f docker-compose-single.yml logs clickhouse-server
```

**Databases Created**:
- tutorial: Sample data for learning
- training: Training exercises
- analytics: Analytics examples

---

### 2. docker-compose-cluster.yml

**Purpose**: Full production-grade 3-shard × 2-replica cluster with ZooKeeper

**Services**:
- 3x ZooKeeper nodes: Cluster coordination
- 6x ClickHouse nodes: Distributed cluster (3 shards, 2 replicas each)

**Topology**:
```
Shard 1: clickhouse-s1r1 (replica 1), clickhouse-s1r2 (replica 2)
Shard 2: clickhouse-s2r1 (replica 1), clickhouse-s2r2 (replica 2)
Shard 3: clickhouse-s3r1 (replica 1), clickhouse-s3r2 (replica 2)

ZooKeeper Ensemble: zookeeper-1, zookeeper-2, zookeeper-3
```

**Resources**:
- Total CPU: 6-12 cores
- Total Memory: 12-24GB
- Disk per node: ~20GB
- ZooKeeper: 0.5GB each

**Usage**:
```bash
# Start cluster
docker-compose -f docker-compose-cluster.yml up -d

# Wait for all nodes to be healthy (30-60 seconds)
docker-compose -f docker-compose-cluster.yml ps

# Connect to any node
docker-compose -f docker-compose-cluster.yml exec clickhouse-s1r1 clickhouse-client \
  --host clickhouse-s1r1 --query "SELECT version()"

# Query cluster status
docker-compose -f docker-compose-cluster.yml exec clickhouse-s1r1 clickhouse-client \
  --host clickhouse-s1r1 --query "SELECT * FROM system.clusters"

# Create replicated tables
docker-compose -f docker-compose-cluster.yml exec clickhouse-s1r1 clickhouse-client \
  --host clickhouse-s1r1 --multiquery < configs/cluster-setup.sql
```

**Cluster Configuration**:
- Cluster name: `clickhouse_cluster`
- Replication: Via ZooKeeper
- Sharding: Hash-based, weight=1 per shard
- DDL: Distributed across all nodes

**Performance Notes**:
- Data automatically replicated to both replicas per shard
- Queries can target specific shards or all shards
- ZooKeeper handles replica synchronization
- Monitor `system.replication_queue` for replication lag

---

### 3. docker-compose-kafka.yml

**Purpose**: ClickHouse + Kafka + ZooKeeper for real-time data ingestion (Module 9)

**Services**:
- ZooKeeper: Kafka coordination
- Kafka Broker: Message streaming
- ClickHouse Server: Data storage with Kafka tables
- Kafka UI: Web interface for Kafka management

**Resources**:
- Kafka: 1-2 cores, 2GB
- ZooKeeper: 0.5 cores, 512MB
- ClickHouse: 2 cores, 4GB

**Usage**:
```bash
# Start stack
docker-compose -f docker-compose-kafka.yml up -d

# Access Kafka UI
# Open browser: http://localhost:8080

# Create Kafka topics
docker-compose -f docker-compose-kafka.yml exec kafka kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic events-topic \
  --partitions 3 --replication-factor 1

# Produce test messages
docker-compose -f docker-compose-kafka.yml exec kafka kafka-console-producer.sh \
  --broker-list localhost:9092 --topic events-topic

# Example message (paste into producer):
# {"event_id": "1", "event_timestamp": "2024-01-22T10:00:00", "user_id": 123, "event_type": "click"}

# Query data from ClickHouse
docker-compose -f docker-compose-kafka.yml exec clickhouse-client clickhouse-client \
  --host clickhouse-server --query "SELECT * FROM kafka_demo.events LIMIT 10"
```

**Kafka Topics Created**:
- events-topic: Raw events stream
- orders-topic: Order stream
- topics for metrics aggregation

**Key Features**:
- Kafka table engine for raw data reading
- Materialized views for data processing
- Automatic data insertion into target tables
- Error handling with dead letter queue

---

### 4. docker-compose-migration.yml

**Purpose**: Full migration stack with MongoDB, MySQL, Debezium, Kafka, and ClickHouse (Module 10)

**Services**:
- MongoDB: Source document database
- MySQL: Source relational database
- ZooKeeper: Kafka coordination
- Kafka: Change stream broker
- Debezium Connect: CDC platform
- ClickHouse: Data warehouse target
- Kafka UI: Monitoring

**Data Flow**:
```
MongoDB -> Debezium -> Kafka -> ClickHouse
MySQL   -> Debezium -> Kafka -> ClickHouse
```

**Resources**:
- MongoDB: 1 core, 2GB
- MySQL: 1-2 cores, 2GB
- Debezium: 1-2 cores, 2GB
- Kafka: 1-2 cores, 2GB
- ClickHouse: 2 cores, 4GB

**Setup Steps**:

```bash
# Start stack
docker-compose -f docker-compose-migration.yml up -d

# Wait for all services to be healthy (60-90 seconds)
docker-compose -f docker-compose-migration.yml ps

# Verify MongoDB initialization
docker-compose -f docker-compose-migration.yml exec mongodb mongosh \
  --authenticationDatabase admin -u root -p password \
  localhost/source_db --eval "db.users.find().pretty()"

# Verify MySQL initialization
docker-compose -f docker-compose-migration.yml exec mysql mysql \
  -h localhost -u root -proot_password source_db \
  -e "SELECT * FROM customers LIMIT 5;"

# Create Debezium connectors
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @configs/debezium-connectors/mongodb-connector.json

curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @configs/debezium-connectors/mysql-connector.json

# Monitor Debezium connectors
curl http://localhost:8083/connectors

# Query migrated data in ClickHouse
docker-compose -f docker-compose-migration.yml exec clickhouse-client clickhouse-client \
  --host clickhouse-server --query "SELECT * FROM target_db.mongo_users LIMIT 5"
```

**Source Databases**:

**MongoDB** (source_db):
- Collections: users, orders, products
- Replica set enabled for CDC
- Sample data: ~15 documents

**MySQL** (source_db):
- Tables: customers, sales, products, inventory
- Binary logging enabled
- Sample data: ~50 rows per table

**Migration Tables in ClickHouse**:
- Raw CDC topic tables (Kafka table engine)
- Materialized views for transformation
- Final destination tables (ReplacingMergeTree)

**Data Quality**:
- Reconciliation tables for validation
- Audit logs for tracking changes
- Error handling with dead letter queues

---

### 5. docker-compose-monitoring.yml

**Purpose**: Complete monitoring stack with ClickHouse + Prometheus + Grafana + AlertManager

**Services**:
- ClickHouse: Time-series data storage
- Prometheus: Metrics collection and aggregation
- Grafana: Visualization and dashboards
- AlertManager: Alert routing and management
- Node Exporter: System metrics
- cAdvisor: Container metrics

**Resources**:
- ClickHouse: 2 cores, 4GB
- Prometheus: 0.5-1 core, 1-2GB
- Grafana: 0.5 cores, 512MB
- AlertManager: 0.25 cores, 256MB
- Node Exporter: 0.25 cores, 256MB

**Usage**:

```bash
# Start monitoring stack
docker-compose -f docker-compose-monitoring.yml up -d

# Access web interfaces
# Grafana: http://localhost:3000 (admin/admin_password)
# Prometheus: http://localhost:9090
# AlertManager: http://localhost:9093

# Verify data collection
docker-compose -f docker-compose-monitoring.yml exec prometheus wget -O - \
  "http://prometheus:9090/api/v1/query?query=up"

# Query metrics from ClickHouse
docker-compose -f docker-compose-monitoring.yml exec clickhouse-client clickhouse-client \
  --host clickhouse-server --query "SELECT * FROM monitoring_db.system_metrics LIMIT 10"

# View alerts
curl http://localhost:9093/api/v1/alerts
```

**Metrics Collected**:

From **Prometheus**:
- CPU usage
- Memory utilization
- Disk I/O and space
- Network traffic
- Container resource usage

From **ClickHouse**:
- Query execution times
- Insert/Select rates
- Part counts per table
- Replication lag
- Cache statistics

**Dashboards Available**:
- System Overview (CPU, Memory, Network)
- ClickHouse Performance
- Query Analytics
- Table Statistics
- Alert Status

**Alerts Configured**:
- Critical: Server down, critical memory/disk usage
- Warning: High CPU, memory, disk usage
- Performance: Slow queries, high concurrency
- Data Quality: Merge stalls, high failure rates

---

## Directory Structure

```
docker/
├── docker-compose-single.yml          # Single node configuration
├── docker-compose-cluster.yml         # 3-shard × 2-replica cluster
├── docker-compose-kafka.yml           # Kafka integration (Module 9)
├── docker-compose-migration.yml       # Migration stack (Module 10)
├── docker-compose-monitoring.yml      # Monitoring stack
├── Dockerfile-custom                  # Custom ClickHouse image
├── README.md                          # This file
│
├── configs/                           # Configuration files
│   ├── single-node.xml                # Single node config
│   ├── cluster-node.xml               # Cluster node config
│   ├── kafka-node.xml                 # Kafka config
│   ├── migration-node.xml             # Migration config
│   ├── monitoring-node.xml            # Monitoring config
│   ├── client-config.xml              # Client config
│   ├── macros-s*.xml                  # Shard/replica macros
│   ├── prometheus.yml                 # Prometheus config
│   ├── alert-rules.yml                # Alert rules
│   ├── alertmanager.yml               # AlertManager config
│   ├── debezium-connectors/           # Debezium connector configs
│   └── grafana/                       # Grafana provisioning
│       ├── provisioning/
│       │   ├── datasources/
│       │   │   └── prometheus-datasource.yml
│       │   └── dashboards/
│       │       └── dashboards.yml
│       └── dashboards/
│           └── clickhouse-overview.json
│
└── init-scripts/                      # SQL initialization scripts
    ├── 00-base-setup.sql              # Base database setup
    ├── kafka-setup.sql                # Kafka tables (Module 9)
    ├── clickhouse-migration-setup.sql # Migration tables (Module 10)
    ├── monitoring-setup.sql           # Monitoring tables
    ├── mongodb-setup.js               # MongoDB init
    └── mysql-setup.sql                # MySQL init
```

## Usage Instructions

### Starting Services

```bash
# Single node
docker-compose -f docker-compose-single.yml up -d

# Cluster
docker-compose -f docker-compose-cluster.yml up -d

# Kafka
docker-compose -f docker-compose-kafka.yml up -d

# Migration
docker-compose -f docker-compose-migration.yml up -d

# Monitoring
docker-compose -f docker-compose-monitoring.yml up -d
```

### Common Commands

```bash
# View running containers
docker-compose -f docker-compose-*.yml ps

# View logs
docker-compose -f docker-compose-*.yml logs -f clickhouse-server

# Execute SQL on ClickHouse
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server --query "SELECT 1"

# Interactive client
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server

# Stop services
docker-compose -f docker-compose-*.yml down

# Stop and remove volumes
docker-compose -f docker-compose-*.yml down -v
```

### Monitoring and Debugging

```bash
# Check container health
docker-compose -f docker-compose-*.yml ps

# View resource usage
docker stats

# Check network connectivity
docker network inspect docker_clickhouse-network

# View event logs
docker-compose -f docker-compose-*.yml events

# Check disk usage
docker system df
```

## Production Considerations

### Performance Tuning

1. **Memory Settings**:
   - Adjust `max_memory_usage` based on available RAM
   - Set `max_memory_usage_for_user` to 70% of max_memory_usage
   - Monitor `system.asynchronous_metrics` for memory pressure

2. **CPU Optimization**:
   - Set background pool sizes based on core count
   - Monitor CPU usage with Prometheus
   - Adjust thread pool sizes for merge operations

3. **Disk I/O**:
   - Use SSD for data directory when possible
   - Monitor with `system.part_log`
   - Adjust merge thread counts based on I/O capacity

### Data Management

1. **Backup Strategy**:
   - Regular backups of metadata
   - Partition-level backups for large tables
   - Test recovery procedures

2. **Replication**:
   - Monitor `system.replication_queue`
   - Set appropriate deduplication windows
   - Watch for replication lag

3. **TTL Policies**:
   - Configure TTL for data retention
   - Monitor with `system.ttl_table_log`
   - Clean up old partitions

### Security

1. **Network**:
   - Use private networks for internal communication
   - Enable firewall rules for cluster nodes
   - Use SSL/TLS for external connections

2. **Access Control**:
   - Create specific users with limited permissions
   - Use IP-based access control
   - Monitor user activity in `system.query_log`

3. **Encryption**:
   - Enable SSL for Kafka connections
   - Encrypt credentials in configuration
   - Use secure storage for sensitive data

### Monitoring

1. **Key Metrics**:
   - Query execution times (p95, p99)
   - Error rates and types
   - Replication lag
   - Disk space usage
   - Memory pressure

2. **Alerting**:
   - Set thresholds based on SLOs
   - Test alert routing and notifications
   - Create runbooks for common alerts

## Troubleshooting

### Common Issues

**Issue**: Containers won't start
```bash
# Check logs
docker-compose -f docker-compose-*.yml logs clickhouse-server

# Verify resources
docker system df

# Check port conflicts
lsof -i :8123 :9000
```

**Issue**: ClickHouse connection refused
```bash
# Verify container is running
docker-compose -f docker-compose-*.yml ps

# Test connectivity
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  nc -v clickhouse-server 9000

# Check logs
docker-compose -f docker-compose-*.yml logs clickhouse-server
```

**Issue**: Replication not working
```bash
# Check ZooKeeper connectivity
docker-compose -f docker-compose-cluster.yml exec zookeeper-1 \
  echo "ruok" | nc localhost 2181

# Check replication queue
docker-compose -f docker-compose-*.yml exec clickhouse-s1r1 \
  clickhouse-client --host clickhouse-s1r1 \
  --query "SELECT * FROM system.replication_queue"
```

**Issue**: High memory usage
```bash
# Check table sizes
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server \
  --query "SELECT database, table, formatReadableSize(total_bytes) FROM system.tables"

# Check merge operations
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server \
  --query "SELECT * FROM system.merges"
```

### Health Check Verification

```bash
# Check all services
docker-compose -f docker-compose-*.yml ps

# Expected: All containers should show "healthy" or "up"
# If any show "unhealthy" or "exited", check logs:
docker-compose -f docker-compose-*.yml logs <service-name>
```

### Performance Debugging

```bash
# Query performance
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server \
  --query "SELECT query, type, event_time, query_duration_ms FROM system.query_log LIMIT 10"

# Table statistics
docker-compose -f docker-compose-*.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server \
  --query "SELECT database, table, parts, bytes_on_disk FROM system.parts"
```

---

## Advanced Topics

### Custom ClickHouse Image

Build a custom image with additional tools:

```bash
docker build -f Dockerfile-custom -t clickhouse-custom:latest .

# Use in docker-compose
image: clickhouse-custom:latest
```

### Multi-Environment Setup

Run multiple configurations simultaneously:

```bash
# Terminal 1: Single node
docker-compose -f docker-compose-single.yml up -d

# Terminal 2: Cluster (uses different ports)
docker-compose -f docker-compose-cluster.yml up -d

# Terminal 3: Kafka
docker-compose -f docker-compose-kafka.yml up -d
```

### Environment Variables

Create `.env` file to override defaults:

```
CLICKHOUSE_VERSION=latest
KAFKA_VERSION=7.5.0
ZOOKEEPER_VERSION=latest
PROMETHEUS_VERSION=latest
GRAFANA_VERSION=latest
```

### Scaling Considerations

For production deployments:

1. Add more Kafka partitions
2. Increase thread pool sizes
3. Configure multiple ClickHouse replicas
4. Add load balancing (HAProxy, Nginx)
5. Implement separate monitoring cluster

---

## Support and Resources

- [ClickHouse Official Documentation](https://clickhouse.com/docs/)
- [Kafka Connector Docs](https://debezium.io/documentation/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

For issues or questions, refer to the main project documentation or module-specific guides.

---

**Last Updated**: January 2026
**ClickHouse Version**: Latest
**Docker Compose Version**: 2.0+
