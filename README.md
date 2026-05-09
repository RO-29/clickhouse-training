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
    ├── demos/                         # ⭐ Self-contained per-module demos (recommended)
    │   ├── README.md                 # Index + standard lifecycle
    │   ├── module-1-fundamentals/    # single  · MergeTree, parts, partitions
    │   ├── module-2-table-engines/   # single  · Replacing/Summing/Aggregating/...
    │   ├── module-3-sharding/        # cluster · Distributed, sharding key
    │   ├── module-4-replication/     # cluster · ReplicatedMergeTree + ZK + drills
    │   ├── module-5-cluster-deploy/  # cluster · ON CLUSTER, cluster()/remote()
    │   ├── module-6-query-opt/       # single  · 60M rows, projections, skip-idx
    │   ├── module-7-backup/          # single + MinIO · BACKUP/RESTORE Disk + S3
    │   ├── module-8-dr/              # cluster · 4 disaster-recovery drills
    │   └── module-9-kafka/           # kafka   · Kafka engine + MV pipeline
    │
    ├── sql/                          # Stand-alone SQL snippets per module
    │   └── module-1/ ... module-10/
    │
    ├── configs/                      # Reference ClickHouse configs (legacy)
    │   ├── config.xml · users.xml · metrika.xml
    │   ├── keeper_config.xml · macros.xml
    │
    └── docker/                       # Legacy shared Docker stacks
        ├── docker-compose-single.yml · -cluster.yml · -kafka.yml
        ├── docker-compose-migration.yml · -monitoring.yml
        ├── init-scripts/ · configs/

ai-changes-md/                       # Archived AI-generated artefacts
                                     # (notion-sync scripts, status summaries,
                                     # one-shot HTML fixers — kept for history)
```

> **Prefer `code-examples/demos/`.** Each module folder there is a complete,
> standalone Docker example with its own compose file, configs, and
> `up.sh / run.sh / down.sh`. The legacy `code-examples/docker/` stacks
> are still around for reference but aren't required.

## 🚀 Quick Start

There are three ways to engage with the material — pick whichever matches
how you learn:

| Path                    | Best for                          | Where                             |
|-------------------------|-----------------------------------|-----------------------------------|
| 🐳 **Hands-on demos**   | Learn by running real ClickHouse  | `code-examples/demos/module-N-*/` |
| 🌐 **Interactive HTML** | Theory + diagrams in your browser | `index.html`                      |
| 📝 **Notion guides**    | Quick reference / cheat-sheets    | `notion-guides/module-N-*.md`     |

### 🐳 Hands-on demos (recommended)

Each module under `code-examples/demos/` is a **self-contained** Docker
example: its own compose file, configs, SQL, and lifecycle scripts. No shared
root infrastructure.

```bash
cd code-examples/demos/module-1-fundamentals/

./up.sh        # docker compose up -d, wait for health
./run.sh       # run the demo (idempotent — re-runnable)
./down.sh      # docker compose down -v  (drops volumes)
```

`./run.sh` self-bootstraps — if the stack isn't already up, it calls
`up.sh` first.

| Module | Demo                                              | Stack             | Host ports                          |
|--------|---------------------------------------------------|-------------------|-------------------------------------|
| 1      | MergeTree basics, parts, partitions               | single (`m1-`)    | 8123, 9000                          |
| 2      | Replacing/Summing/Aggregating/Collapsing engines  | single (`m2-`)    | 8123, 9000                          |
| 3      | Distributed table, sharding key, balance          | cluster (`m3-`)   | 8123-8128, 9000-9005                |
| 4      | ReplicatedMergeTree, ZK, kill-replica drill       | cluster (`m4-`)   | 8123-8128, 9000-9005                |
| 5      | ON CLUSTER DDL, cluster()/remote()/clusterAll     | cluster (`m5-`)   | 8123-8128, 9000-9005                |
| 6      | Query optimization on 60M rows                    | single (`m6-`)    | 8123, 9000                          |
| 7      | BACKUP/RESTORE: local disk + S3 (MinIO)           | single (`m7-`)    | 8123, 9000, 9100/9101 (MinIO)       |
| 8      | 4 disaster-recovery drills                        | cluster (`m8-`)   | 8123-8128, 9000-9005                |
| 9      | Kafka engine + materialized-view pipeline         | kafka (`m9-`)     | 8123, 9000, 9092, 8080 (UI)         |

> **Run one module at a time.** Most modules bind host port `8123`. Tear
> down with `./down.sh` before starting the next module.

See **`code-examples/demos/README.md`** for the full module map.

### 🌐 Interactive HTML modules

```bash
open index.html        # or double-click in Finder/Explorer
```

Theory, diagrams, examples, and templates per module.

### 📝 Notion-style quick guides

```bash
ls notion-guides/      # one .md per module, 200-500 lines each
```

Concise, callout-formatted, portable into Notion.

### 🗄️ Legacy shared Docker stacks (optional)

The original "one big stack" compose files still exist:

```bash
cd code-examples/docker/
docker compose -f docker-compose-single.yml up -d      # single node
docker compose -f docker-compose-cluster.yml up -d     # 3×2 cluster
docker compose -f docker-compose-kafka.yml up -d       # Kafka
docker compose -f docker-compose-migration.yml up -d   # MongoDB/MySQL CDC
docker compose -f docker-compose-monitoring.yml up -d  # Grafana + Prometheus
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

## 💻 Reference Material

### Production-grade configs

Reference XML configs in `code-examples/configs/` — useful for copying into a
real ClickHouse installation, not for the demos (those have their own
configs in `code-examples/demos/module-*/configs/`).

| File                | Purpose                                                      |
|---------------------|--------------------------------------------------------------|
| `config.xml`        | Main server config: ports, memory, cluster, ZK, compression. |
| `users.xml`         | Users, quotas, network restrictions, password hashing.       |
| `metrika.xml`       | ZooKeeper / Keeper config.                                   |
| `keeper_config.xml` | ClickHouse Keeper config.                                    |
| `macros.xml`        | Replication macros (per-node identity).                      |

```bash
sudo cp code-examples/configs/config.xml /etc/clickhouse-server/
sudo cp code-examples/configs/users.xml  /etc/clickhouse-server/
sudo systemctl restart clickhouse-server
```

### Stand-alone SQL snippets

`code-examples/sql/module-N/` contains module-specific `.sql` files you can
run directly against any ClickHouse instance:

```bash
clickhouse-client --multiquery < code-examples/sql/module-1/01-basic-tables.sql
```

### Archive of generation artifacts

`ai-changes-md/` holds the AI-generated summary docs and one-shot fix
scripts that produced this curriculum (Notion sync, HTML cleanups, etc.).
Kept for traceability; not needed to use the course.

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
