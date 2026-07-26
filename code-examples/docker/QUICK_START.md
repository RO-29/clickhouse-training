# Quick Start Guide - ClickHouse Docker

## Prerequisites

Ensure you have:
- Docker Desktop (or Docker Engine) installed
- Docker Compose v2.0+
- At least 8GB RAM
- At least 20GB free disk space

## 5-Minute Setup

### Option 1: Single Node (Development)

```bash
# Navigate to docker directory
cd code-examples/docker

# Start services
docker-compose -f docker-compose-single.yml up -d

# Wait 30 seconds for startup

# Execute a simple query
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server --query "SELECT version()"

# Create a sample table
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server << 'EOF'
CREATE TABLE test_table (
    id UInt32,
    name String,
    created_at DateTime
) ENGINE = MergeTree()
ORDER BY id;
EOF

# Insert sample data
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server << 'EOF'
INSERT INTO test_table VALUES
(1, 'Alice', now()),
(2, 'Bob', now()),
(3, 'Charlie', now());
EOF

# Query the data
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server --query "SELECT * FROM test_table"

# Stop services
docker-compose -f docker-compose-single.yml down
```

### Option 2: Full Cluster (Production-like)

```bash
# Start 3-shard × 2-replica cluster with ZooKeeper
docker-compose -f docker-compose-cluster.yml up -d

# Wait 60-90 seconds for full startup

# Check cluster status
docker-compose -f docker-compose-cluster.yml exec clickhouse-s1r1 \
  clickhouse-client --host clickhouse-s1r1 \
  --query "SELECT * FROM system.clusters"

# View all nodes
docker-compose -f docker-compose-cluster.yml ps

# Stop cluster
docker-compose -f docker-compose-cluster.yml down
```

### Option 3: Kafka Integration (Module 9)

```bash
# Start ClickHouse + Kafka + ZooKeeper
docker-compose -f docker-compose-kafka.yml up -d

# Wait 60 seconds

# Create Kafka topic
docker-compose -f docker-compose-kafka.yml exec kafka kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic test-events \
  --partitions 1 --replication-factor 1

# Access Kafka UI
# Open browser: http://localhost:8080

# Produce test message
echo '{"user_id": 1, "event_type": "click", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S)'"}' | \
docker-compose -f docker-compose-kafka.yml exec -T kafka kafka-console-producer.sh \
  --broker-list localhost:9092 --topic test-events

# Query in ClickHouse
docker-compose -f docker-compose-kafka.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server \
  --query "SELECT * FROM kafka_demo.events LIMIT 10"
```

### Option 4: Monitoring Stack

```bash
# Start ClickHouse + Prometheus + Grafana
docker-compose -f docker-compose-monitoring.yml up -d

# Wait 30 seconds

# Access Grafana
# Open browser: http://localhost:3000
# Login: admin / admin_password

# Access Prometheus
# Open browser: http://localhost:9090

# Query metrics
docker-compose -f docker-compose-monitoring.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server \
  --query "SELECT * FROM monitoring_db.system_metrics LIMIT 10"
```

## Common Operations

### Connect to ClickHouse Client

```bash
# Single node
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server

# Cluster (any node)
docker-compose -f docker-compose-cluster.yml exec clickhouse-s1r1 \
  clickhouse-client --host clickhouse-s1r1
```

### Execute SQL File

```bash
docker-compose -f docker-compose-single.yml exec clickhouse-client \
  clickhouse-client --host clickhouse-server < init-scripts/00-base-setup.sql
```

### View Logs

```bash
# ClickHouse server logs
docker-compose -f docker-compose-single.yml logs clickhouse-server

# Follow logs (like tail -f)
docker-compose -f docker-compose-single.yml logs -f clickhouse-server

# Last 100 lines
docker-compose -f docker-compose-single.yml logs --tail=100 clickhouse-server
```

### Check Container Status

```bash
# View all containers
docker-compose -f docker-compose-single.yml ps

# View container health
docker-compose -f docker-compose-single.yml ps --status=running
```

### Stop Services

```bash
# Stop but keep data
docker-compose -f docker-compose-single.yml stop

# Remove containers but keep volumes
docker-compose -f docker-compose-single.yml down

# Remove everything including data
docker-compose -f docker-compose-single.yml down -v
```

## Troubleshooting

### Check if port is in use

```bash
# On macOS/Linux
lsof -i :8123

# On Windows
netstat -ano | findstr :8123
```

### Container exits immediately

```bash
# Check logs
docker-compose -f docker-compose-single.yml logs clickhouse-server

# Common causes:
# - Port already in use
# - Insufficient disk space
# - Insufficient memory
```

### ClickHouse won't connect

```bash
# Verify container is running
docker-compose -f docker-compose-single.yml ps

# Test connection
docker ps | grep clickhouse-server

# Check if service is ready (wait for "healthy")
docker-compose -f docker-compose-single.yml ps
```

### Out of memory

```bash
# Check Docker resources
docker system df

# Reduce number of containers
docker-compose -f docker-compose-cluster.yml down

# Restart docker daemon and try again
```

## Environment Variables

Create a `.env` file in the docker directory:

```env
# ClickHouse settings
CLICKHOUSE_VERSION=latest
CLICKHOUSE_DB=default

# Kafka settings
KAFKA_PARTITIONS=3
KAFKA_REPLICATION_FACTOR=1

# Resources
COMPOSE_PROJECT_NAME=clickhouse-ks
```

## Performance Tips

### For Single Node
- Use 2-4 CPU cores
- Allocate 2-4GB RAM
- Use SSD for data directory

### For Cluster
- Use 1-2 CPU cores per node
- Allocate 1-2GB RAM per ClickHouse node
- Allocate 512MB RAM per ZooKeeper node
- Ensure network latency < 50ms between nodes

### For Kafka
- Partition count = number of ClickHouse inserts parallelism
- Consumer threads = number of ClickHouse background threads
- Batch size = compromise between latency and throughput

## Next Steps

1. Read the full [README.md](README.md) for detailed documentation
2. Review module-specific guides:
   - Module 9: Kafka integration
3. Explore ClickHouse documentation: https://clickhouse.com/docs/
4. Check monitoring dashboards: http://localhost:3000 (if running monitoring stack)

## Useful Commands Reference

```bash
# Show running containers
docker ps

# Show all containers
docker ps -a

# View container logs
docker logs <container-id>

# Execute command in container
docker exec -it <container-id> <command>

# Inspect container
docker inspect <container-id>

# View Docker resource usage
docker stats

# Clean up unused resources
docker system prune

# View networks
docker network ls

# Inspect network
docker network inspect <network-name>
```

## Module-Specific Quick Starts

### Module 1-5: Fundamentals to Cluster Deployment
```bash
docker-compose -f docker-compose-single.yml up -d
# or
docker-compose -f docker-compose-cluster.yml up -d
```

### Module 6-8: Query Optimization, Backup, Disaster Recovery
```bash
docker-compose -f docker-compose-cluster.yml up -d
# Use the cluster for practicing optimization and backup strategies
```

### Module 9: Kafka Ingestion
```bash
docker-compose -f docker-compose-kafka.yml up -d
# Stream data using Kafka topics
```

