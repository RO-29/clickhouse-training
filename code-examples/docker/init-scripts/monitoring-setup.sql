-- Monitoring Setup for Metrics Collection
-- Purpose: Create tables for storing system metrics and performance data

CREATE DATABASE IF NOT EXISTS monitoring_db;

-- System metrics table for time-series data
CREATE TABLE IF NOT EXISTS monitoring_db.system_metrics (
    timestamp DateTime,
    metric_name String,
    metric_value Float64,
    tags Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, metric_name);

-- Query performance metrics
CREATE TABLE IF NOT EXISTS monitoring_db.query_metrics (
    query_start_time DateTime,
    query_id String,
    query_text String,
    user String,
    query_duration_ms UInt64,
    read_rows UInt64,
    read_bytes UInt64,
    written_rows UInt64,
    written_bytes UInt64,
    memory_usage UInt64,
    result_rows UInt64,
    result_bytes UInt64,
    exception_code Int32
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(query_start_time)
ORDER BY (query_start_time, user);

-- Table size statistics
CREATE TABLE IF NOT EXISTS monitoring_db.table_statistics (
    stat_timestamp DateTime,
    database String,
    table_name String,
    engine String,
    total_rows UInt64,
    total_bytes UInt64,
    compressed_bytes UInt64,
    partition_count UInt32,
    modification_time DateTime
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(stat_timestamp)
ORDER BY (stat_timestamp, database, table_name);

-- Server resource utilization
CREATE TABLE IF NOT EXISTS monitoring_db.server_resources (
    measurement_time DateTime,
    cpu_percent Float32,
    memory_percent Float32,
    disk_usage_percent Float32,
    open_connections UInt32,
    queries_running UInt32,
    merge_operations UInt32,
    background_pool_size UInt32,
    background_pool_tasks UInt32
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(measurement_time)
ORDER BY measurement_time;

-- Replication metrics
CREATE TABLE IF NOT EXISTS monitoring_db.replication_metrics (
    timestamp DateTime,
    database String,
    table_name String,
    is_leader UInt8,
    is_replica UInt8,
    replica_path String,
    zk_path String,
    is_session_expired UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, database, table_name);

-- Merge/Background job statistics
CREATE TABLE IF NOT EXISTS monitoring_db.merge_statistics (
    event_timestamp DateTime,
    database String,
    table_name String,
    event_type String,
    rows_read UInt64,
    bytes_read UInt64,
    rows_written UInt64,
    bytes_written UInt64,
    duration_ms UInt64,
    result String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_timestamp)
ORDER BY (event_timestamp, database, table_name);

-- Exception/Error log
CREATE TABLE IF NOT EXISTS monitoring_db.exception_log (
    exception_time DateTime,
    exception_code Int32,
    exception_text String,
    query_id String,
    user String,
    database String,
    query_text String,
    stack_trace String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(exception_time)
ORDER BY (exception_time, exception_code);

-- Alerts/Events
CREATE TABLE IF NOT EXISTS monitoring_db.alerts (
    alert_time DateTime,
    alert_level String,
    alert_name String,
    alert_message String,
    affected_entity String,
    metric_value Float64,
    threshold Float64,
    status String,
    acknowledged_at DateTime,
    acknowledged_by String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(alert_time)
ORDER BY (alert_time, alert_level);

-- Dictionary entry storage metrics
CREATE TABLE IF NOT EXISTS monitoring_db.dictionary_metrics (
    timestamp DateTime,
    dictionary_name String,
    dictionary_database String,
    element_count UInt64,
    load_time_ms UInt64,
    last_load_time DateTime,
    failed_lookups UInt64,
    successful_lookups UInt64,
    hit_rate Float32
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, dictionary_name);

-- Backup and restore events
CREATE TABLE IF NOT EXISTS monitoring_db.backup_events (
    event_timestamp DateTime,
    backup_id String,
    operation_type String,
    database String,
    table_name String,
    backup_size_bytes UInt64,
    duration_seconds UInt32,
    status String,
    error_message String,
    backup_location String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_timestamp)
ORDER BY (event_timestamp, database);

-- Create materialized views for common metrics

-- View: Average query execution time by user per hour
CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring_db.hourly_query_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(metric_hour)
ORDER BY (metric_hour, user)
AS SELECT
    toStartOfHour(query_start_time) as metric_hour,
    user,
    count() as query_count,
    avg(query_duration_ms) as avg_duration,
    max(query_duration_ms) as max_duration,
    sum(read_rows) as total_read_rows,
    sum(read_bytes) as total_read_bytes
FROM monitoring_db.query_metrics
GROUP BY metric_hour, user;

-- View: Table growth over time
CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring_db.table_growth
ENGINE = ReplacingMergeTree()
ORDER BY (stat_timestamp, database, table_name)
PARTITION BY toYYYYMM(stat_timestamp)
AS SELECT
    stat_timestamp,
    database,
    table_name,
    total_rows,
    total_bytes,
    compressed_bytes
FROM monitoring_db.table_statistics;

-- View: System health summary
CREATE TABLE IF NOT EXISTS monitoring_db.system_health_summary (
    check_time DateTime,
    overall_status String,
    cpu_status String,
    memory_status String,
    disk_status String,
    replication_status String,
    num_critical_alerts UInt32,
    num_warning_alerts UInt32,
    last_successful_backup DateTime,
    notes String
) ENGINE = ReplacingMergeTree()
ORDER BY (check_time)
PARTITION BY toYYYYMM(check_time);

-- Helper function for calculating percentiles
CREATE AGGREGATE FUNCTION IF NOT EXISTS quantile_95(x Float64) RETURNS Float64
AS 'quantile' ALIAS sequenceMatch WITH '(x >= 0.95)' IN monitoring_db;

-- Log successful setup
SELECT 'Monitoring setup completed successfully' AS status;
