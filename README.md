# ClickHouse Knowledge Transfer - Complete Training Series

> 🎓 **A comprehensive 6-8 week training program for mastering ClickHouse from fundamentals to production deployment**

## 📊 Overview

This repository contains a complete ClickHouse training curriculum designed to take you from beginner to expert. The course covers everything from basic architecture to advanced topics like sharding, replication, real-time ingestion, and production migrations.

### Key Statistics

- **Duration:** 6-8 weeks
- **Total Hours:** 66-88 hours
- **Modules:** 10 comprehensive modules
- **Session Frequency:** 2-3 sessions per week
- **Session Length:** 2-3 hours each
- **Code Examples:** 100+ production-ready SQL examples
- **Configurations:** Complete Docker, config, and deployment files

## 🗂️ Repository Structure

```
clickhouse-ks/
├── index.html                          # Main landing page (start here!)
├── ch-kt-roadmap.pdf                   # Training roadmap PDF
│
├── HTML Modules (Interactive Learning)
├── module-1-fundamentals.html          # Module 1: Fundamentals & Architecture
├── module-2-table-engines.html         # Module 2: Table Engines & Data Modeling
├── module-3-sharding.html              # Module 3: Sharding Strategy & Distribution
├── module-4-replication.html           # Module 4: Replication & High Availability
├── module-5-cluster-deployment.html    # Module 5: Full Cluster Deployment
├── module-6-query-optimization.html    # Module 6: Query Optimization & Performance
├── module-7-backup-recovery.html       # Module 7: Backup, Recovery & PITR
├── module-8-disaster-recovery.html     # Module 8: Disaster Recovery & Business Continuity
├── module-9-kafka-ingestion.html       # Module 9: Kafka-Based Real-Time Ingestion
└── module-10-migration.html            # Module 10: Migration from MongoDB/MySQL
│
├── notion-guides/                      # Concise Notion-style markdown guides
│   ├── module-1-fundamentals.md
│   ├── module-2-table-engines.md
│   ├── module-3-sharding.md
│   ├── module-4-replication.md
│   ├── module-5-cluster-deployment.md
│   ├── module-6-query-optimization.md
│   ├── module-7-backup-recovery.md
│   ├── module-8-disaster-recovery.md
│   ├── module-9-kafka-ingestion.md
│   └── module-10-migration.md
│
└── code-examples/                      # Production-ready code examples
    ├── sql/                           # SQL examples organized by module
    │   ├── module-1/
    │   ├── module-2/
    │   ├── module-3/
    │   ├── module-4/
    │   ├── module-5/
    │   ├── module-6/
    │   ├── module-7/
    │   ├── module-8/
    │   ├── module-9/
    │   └── module-10/
    │
    ├── configs/                       # ClickHouse configuration files
    │   ├── config.xml                # Main server configuration
    │   ├── users.xml                 # User management & permissions
    │   ├── metrika.xml               # ZooKeeper/Keeper config
    │   ├── keeper_config.xml         # ClickHouse Keeper config
    │   └── macros.xml                # Replication macros
    │
    ├── docker/                        # Docker Compose setups
    │   ├── docker-compose-single.yml
    │   ├── docker-compose-cluster.yml
    │   ├── docker-compose-kafka.yml
    │   ├── docker-compose-migration.yml
    │   ├── docker-compose-monitoring.yml
    │   ├── Dockerfile-custom
    │   ├── init-scripts/
    │   └── configs/
    │
    └── scripts/                       # Automation scripts
        ├── backup/
        ├── monitoring/
        └── migration/
```

## 🚀 Quick Start

### Option 1: Interactive HTML Learning (Recommended)

1. **Open the landing page:**
   ```bash
   open index.html
   # or double-click index.html in your file browser
   ```

2. **Follow the modules sequentially:**
   - Start with Module 1: Fundamentals & Architecture
   - Progress through each module in order
   - Each module includes: theory, examples, best practices, and templates

### Option 2: Notion-Style Quick Guides

For concise theory and quick references:

```bash
# View markdown guides
cd notion-guides/
open module-1-fundamentals.md
```

These guides are:
- ✅ Concise (200-500 lines each)
- ✅ Notion-formatted with emojis and callouts
- ✅ Perfect for quick reference
- ✅ Include ASCII architecture diagrams
- ✅ Portable and easy to import into Notion

### Option 3: Hands-On with Docker

Get a ClickHouse environment running immediately:

```bash
cd code-examples/docker/

# Single node (development)
docker-compose -f docker-compose-single.yml up -d

# Full cluster (3 shards × 2 replicas)
docker-compose -f docker-compose-cluster.yml up -d

# Kafka streaming setup
docker-compose -f docker-compose-kafka.yml up -d

# Complete migration stack
docker-compose -f docker-compose-migration.yml up -d

# Monitoring stack (Grafana + Prometheus)
docker-compose -f docker-compose-monitoring.yml up -d
```

## 📚 Module Breakdown

### Week 1: Foundations

**Module 1: Fundamentals & Architecture** (4-6 hours)
- ClickHouse architecture and use cases
- Column-oriented storage concepts
- Differences from traditional RDBMS
- Hardware requirements and installation

**Module 2: Table Engines & Data Modeling** (6-8 hours)
- MergeTree family engines
- ReplacingMergeTree, SummingMergeTree, AggregatingMergeTree
- Partitioning strategies and keys
- Data types, codecs, and TTL policies

### Week 2-3: Scaling

**Module 3: Sharding Strategy & Distribution** (6-8 hours)
- Distributed table architecture
- Sharding key selection
- Data distribution across shards
- Resharding considerations

### Week 3-4: High Availability

**Module 4: Replication & High Availability** (6-8 hours)
- ReplicatedMergeTree engine
- ClickHouse Keeper architecture
- Multi-replica cluster setup
- Failover handling

### Week 4-5: Production Deployment

**Module 5: Full Cluster Deployment** (8-10 hours)
- Production cluster topology (3 shards × 2 replicas)
- Configuration management
- Security: users, roles, permissions
- SSL/TLS and monitoring setup

### Week 5-6: Performance

**Module 6: Query Optimization & Performance** (6-8 hours)
- Query execution pipeline
- Index utilization strategies
- Materialized views
- JOIN optimization

### Week 6: Data Protection

**Module 7: Backup, Recovery & PITR** (4-6 hours)
- Full vs incremental backups
- Point-in-Time Recovery
- Restore procedures
- Backup automation

### Week 7: Business Continuity

**Module 8: Disaster Recovery & Business Continuity** (4-6 hours)
- DR strategy and RTO/RPO planning
- Multi-datacenter setups
- Failover/failback procedures
- Geo-replication

### Week 7: Real-Time Data

**Module 9: Kafka-Based Real-Time Ingestion** (6-8 hours)
- Kafka Engine fundamentals
- Materialized views with Kafka
- Message format handling (JSON, Avro, Protobuf)
- Performance optimization

### Week 7-8: Migration

**Module 10: Migration from MongoDB/MySQL** (10-14 hours)
- Schema mapping strategies
- Debezium CDC setup
- Historical + live streaming
- Data validation and cutover

## 💻 Using the Code Examples

### SQL Examples

Navigate to any module's SQL directory:

```bash
cd code-examples/sql/module-1/

# Run examples
clickhouse-client --multiquery < 01-basic-tables.sql
clickhouse-client --multiquery < 02-data-insertion.sql
clickhouse-client --multiquery < 03-queries.sql
```

Each SQL file contains:
- ✅ Well-commented, production-ready code
- ✅ Step-by-step examples
- ✅ Best practices
- ✅ Common patterns and anti-patterns

### Configuration Files

Production-ready configurations in `code-examples/configs/`:

**config.xml** - Main server configuration
- HTTP/TCP port configuration
- Memory and thread limits
- Cluster definitions (3 shards × 2 replicas)
- ZooKeeper/Keeper configuration
- Compression and logging settings

**users.xml** - User management
- Multiple users: default, admin, readonly, app_user
- Quotas and resource limits
- Network restrictions
- Password hashing

**Usage:**
```bash
# Copy configurations to ClickHouse directory
sudo cp code-examples/configs/config.xml /etc/clickhouse-server/
sudo cp code-examples/configs/users.xml /etc/clickhouse-server/
sudo systemctl restart clickhouse-server
```

### Docker Environments

**Single Node Setup:**
```bash
cd code-examples/docker/
docker-compose -f docker-compose-single.yml up -d
docker exec -it clickhouse-server clickhouse-client
```

**Full Cluster (3×2 with ZooKeeper):**
```bash
docker-compose -f docker-compose-cluster.yml up -d
# Access any shard
docker exec -it clickhouse-shard1-replica1 clickhouse-client
```

**Kafka Streaming:**
```bash
docker-compose -f docker-compose-kafka.yml up -d
# Kafka UI available at http://localhost:8080
```

**Migration Stack:**
```bash
docker-compose -f docker-compose-migration.yml up -d
# MongoDB: localhost:27017
# MySQL: localhost:3306
# ClickHouse: localhost:9000
# Kafka UI: localhost:8080
```

## 🎯 Learning Paths

### Path 1: Database Administrator
Focus on deployment, monitoring, and operations:
- Module 1 (Fundamentals)
- Module 5 (Cluster Deployment)
- Module 4 (Replication & HA)
- Module 7 (Backup & Recovery)
- Module 8 (Disaster Recovery)

### Path 2: Data Engineer
Focus on data modeling, ingestion, and optimization:
- Module 1 (Fundamentals)
- Module 2 (Table Engines)
- Module 9 (Kafka Ingestion)
- Module 6 (Query Optimization)
- Module 10 (Migration)

### Path 3: Architect
Complete comprehensive path:
- Follow all 10 modules sequentially
- Complete all code examples
- Deploy all Docker environments
- Build production-grade solutions

## 🔍 What You'll Learn

### By the End of This Course:

✅ **Architecture & Fundamentals**
- Column-oriented storage principles
- MergeTree engine family
- When to use ClickHouse vs other databases

✅ **Data Modeling**
- Schema design for analytical workloads
- Partitioning and primary key strategies
- Specialized engines (Replacing, Summing, Aggregating)

✅ **Distributed Systems**
- Sharding strategies and key selection
- Multi-replica replication
- Distributed query execution

✅ **Production Operations**
- Cluster deployment and configuration
- Security and user management
- Backup, recovery, and disaster recovery

✅ **Performance Optimization**
- Query optimization techniques
- Index strategies
- Materialized views

✅ **Real-World Integration**
- Kafka-based real-time ingestion
- Migration from MongoDB/MySQL
- Production deployment patterns

## 📖 How to Use This Course

### For Self-Study:

1. **Start with index.html** - Get an overview of all modules
2. **Follow modules sequentially** - Each builds on previous knowledge
3. **Run the code examples** - Practice with real SQL
4. **Deploy Docker environments** - Get hands-on experience
5. **Use Notion guides** - Quick reference when needed

### For Instructor-Led Training:

1. **Session Structure:**
   - 30 min: Theory (HTML module)
   - 60 min: Hands-on practice (SQL examples)
   - 30 min: Deploy and test (Docker)
   - 30 min: Q&A and exercises

2. **Homework Assignments:**
   - Read next module's Notion guide
   - Complete practice exercises
   - Deploy relevant Docker environment

3. **Assessments:**
   - Module quizzes (create based on content)
   - Hands-on lab exercises
   - Final project: Build production cluster

## 🛠️ Prerequisites

### Required Knowledge:
- Basic SQL (SELECT, INSERT, JOIN)
- Command line basics (bash, terminal)
- Understanding of databases (tables, indexes)

### Recommended Knowledge:
- Linux system administration
- Docker basics
- Distributed systems concepts

### Software Requirements:
- Docker & Docker Compose (for hands-on)
- Web browser (for HTML modules)
- Text editor (for Notion guides)
- (Optional) ClickHouse installed locally

## 📊 Performance Expectations

After completing this course, you'll be able to:

- Deploy production ClickHouse clusters
- Handle **billions of rows** with sub-second queries
- Achieve **100-1000x faster** queries than traditional RDBMS
- Implement **real-time analytics** with Kafka streaming
- Migrate **terabytes of data** from MongoDB/MySQL
- Design **highly available** multi-datacenter setups
- Optimize queries for **10-100x compression** ratios

## 🤝 Contributing

This is a training curriculum. If you find errors or have improvements:

1. Note the module and section
2. Suggest improvements with examples
3. Test changes with provided Docker environments

## 📄 License

This training material is provided for educational purposes.

## 🔗 Additional Resources

- **Official Documentation:** https://clickhouse.com/docs
- **ClickHouse Blog:** https://clickhouse.com/blog
- **GitHub:** https://github.com/ClickHouse/ClickHouse
- **Slack Community:** https://clickhouse.com/slack
- **Stack Overflow:** Tagged with `clickhouse`

## 🎓 About This Course

This comprehensive training series was designed to provide a complete learning path for ClickHouse, from fundamentals to advanced production scenarios. Each module includes:

- **Theory:** Comprehensive explanations with diagrams
- **Practice:** Production-ready code examples
- **Templates:** Copy-paste solutions for common scenarios
- **Best Practices:** Industry-standard patterns
- **Real-World Cases:** Proven solutions from production

---

**Ready to start?** Open `index.html` and begin your ClickHouse journey!

📊 **Happy Learning!** 🚀
