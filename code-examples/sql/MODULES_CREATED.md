# ClickHouse SQL Code Examples - All 10 Modules Created

This directory contains production-ready SQL code examples for all 10 ClickHouse Kubernetes Certification modules.

## Module Structure

### Module 1: Fundamentals
- **01-basic-tables.sql** - Basic table creation, data types, nullable columns, enums, arrays, tuples, partitioning, compression
- **02-data-insertion.sql** - Single/batch insertions, INSERT INTO SELECT, type conversions, array data, aggregations
- **03-queries.sql** - SELECT statements, WHERE/ORDER BY, GROUP BY, JOINs, subqueries, UNIONs, string/date functions

### Module 2: Table Engines
- **01-mergetree-engines.sql** - Standard MergeTree, primary keys, TTL, custom granularity, codec optimization
- **02-replacing-mergetree.sql** - Version-based replacement, soft deletes, update tracking, deduplication
- **03-summing-mergetree.sql** - Automatic summation during merge, pre-aggregated data, metric aggregation
- **04-aggregating-mergetree.sql** - AggregateFunction states, incremental aggregation, avgState/sumState usage
- **05-ttl-examples.sql** - Data deletion/migration, column-level TTL, tiered storage, compliance retention

### Module 3: Sharding and Distribution
- **01-cluster-config.sql** - Cluster topology, connectivity verification, table configuration, distributed setup
- **02-distributed-tables.sql** - Distributed table creation, sharding keys, INSERT/SELECT across shards
- **03-sharding-examples.sql** - Hash-based, range-based, hierarchical sharding, consistent hashing

### Module 4: Replication
- **01-replicated-mergetree.sql** - ReplicatedMergeTree setup, ZooKeeper coordination, replication settings
- **02-replication-monitoring.sql** - Replica health checks, queue monitoring, lag analysis, stuck operation detection
- **03-failover-examples.sql** - Pre-failover validation, leader promotion, failover timing, data consistency

### Module 5: Cluster Deployment
- **01-cluster-setup.sql** - Multi-node initialization, local tables, distributed tables, replication setup
- **02-distributed-ddl.sql** - ON CLUSTER operations, schema propagation, materialized views on cluster
- **03-user-management.sql** - User creation, quotas, roles, permissions, access control, audit trails
- **04-monitoring.sql** - Cluster health, replication status, query performance, merge operations, disk usage

### Module 6: Query Optimization
- **01-query-optimization.sql** - Partition pruning, column selection, aggregation optimization, JOINs, PREWHERE
- **02-explain-examples.sql** - EXPLAIN queries, execution plans, pipeline analysis, memory estimation
- **03-indexes.sql** - Secondary indexes (SET, MINMAX, BLOOM_FILTER), index strategies and best practices
- **04-materialized-views.sql** - Pre-aggregation views, incremental aggregation, nested materialized views

### Module 7: Backup and Recovery
- **01-backup-commands.sql** - FREEZE operations, backup planning, metadata export, partition management
- **02-restore-procedures.sql** - ATTACH PARTITION, data restoration, validation, point-in-time recovery
- **03-pitr-examples.sql** - Point-in-time recovery setup, transaction logs, RTO/RPO calculation

### Module 8: Disaster Recovery
- **01-dr-setup.sql** - DR infrastructure, replicated tables, health checks, readiness assessment
- **02-failover-procedures.sql** - Pre-failover checks, promotion procedures, traffic switching, metrics calculation
- **03-consistency-checks.sql** - Row count validation, checksum verification, data integrity, reconciliation

### Module 9: Kafka Integration
- **01-kafka-engine.sql** - Kafka table engine setup, broker configuration, consumer groups, format handling
- **02-kafka-materialized-views.sql** - MV for Kafka consumption, real-time aggregation, processing pipelines
- **03-kafka-monitoring.sql** - Consumer lag monitoring, throughput measurement, error detection, quality checks

### Module 10: Migration
- **01-schema-mapping.sql** - Data type conversion, schema mapping, transformation logic, validation
- **02-migration-queries.sql** - Batch migration, incremental updates, progress tracking, performance metrics
- **03-validation-queries.sql** - Post-migration validation, data completeness, reconciliation, sign-off

## File Organization

```
/code-examples/sql/
├── module-1/
│   ├── 01-basic-tables.sql
│   ├── 02-data-insertion.sql
│   └── 03-queries.sql
├── module-2/
│   ├── 01-mergetree-engines.sql
│   ├── 02-replacing-mergetree.sql
│   ├── 03-summing-mergetree.sql
│   ├── 04-aggregating-mergetree.sql
│   └── 05-ttl-examples.sql
├── module-3/ to module-10/
└── MODULES_CREATED.md (this file)
```

## Key Features of the SQL Examples

### Production-Ready
- Complete, executable SQL statements
- Error handling and validation
- Comprehensive comments and documentation
- Best practices and optimization techniques

### Practical Examples
- Real-world business scenarios
- Data modeling patterns
- Performance optimization strategies
- Monitoring and operational procedures

### Educational Value
- Step-by-step progressions
- Inline explanations for complex concepts
- Before/after optimization examples
- Common pitfalls and solutions

## Usage

Each SQL file can be executed directly against a ClickHouse instance:

```bash
# Single file execution
clickhouse-client < module-1/01-basic-tables.sql

# Or execute from ClickHouse client
cat module-1/01-basic-tables.sql | clickhouse-client
```

## Total Coverage

- **30 comprehensive SQL files**
- **10 modules** covering entire ClickHouse architecture
- **Production-ready examples** for immediate use
- **Complete documentation** with comments and best practices

## Notes

- All examples follow ClickHouse best practices
- Queries are designed to be educational and functional
- Adapt examples to your specific requirements
- Test thoroughly before production deployment
