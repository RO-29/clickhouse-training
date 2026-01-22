-- Base Setup Script for ClickHouse
-- Purpose: Create fundamental databases, users, and tables for all examples

-- Create main databases
CREATE DATABASE IF NOT EXISTS tutorial;
CREATE DATABASE IF NOT EXISTS training;
CREATE DATABASE IF NOT EXISTS analytics;
CREATE DATABASE IF NOT EXISTS kafka_demo;
CREATE DATABASE IF NOT EXISTS target_db;
CREATE DATABASE IF NOT EXISTS monitoring_db;

-- Create system database for monitoring (if not exists)
CREATE DATABASE IF NOT EXISTS system_metrics;

-- Sample data table for testing
CREATE TABLE IF NOT EXISTS tutorial.sample_events (
    event_id UInt64,
    event_date Date,
    event_time DateTime,
    user_id UInt64,
    event_type String,
    event_value Float32,
    event_properties Map(String, String),
    ip_address String,
    user_agent String
) ENGINE = MergeTree()
ORDER BY (event_date, user_id, event_time);

-- Sample orders table
CREATE TABLE IF NOT EXISTS tutorial.orders (
    order_id UInt64,
    order_date Date,
    user_id UInt64,
    product_id UInt64,
    quantity UInt32,
    price Float64,
    total_amount Float64,
    status String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = MergeTree()
ORDER BY (order_date, user_id);

-- Sample users table
CREATE TABLE IF NOT EXISTS tutorial.users (
    user_id UInt64,
    first_name String,
    last_name String,
    email String,
    country String,
    city String,
    registration_date Date,
    last_login DateTime
) ENGINE = ReplacingMergeTree()
ORDER BY (user_id, registration_date);

-- Sample products table
CREATE TABLE IF NOT EXISTS tutorial.products (
    product_id UInt64,
    product_name String,
    category String,
    price Float64,
    quantity_in_stock UInt32,
    created_at DateTime
) ENGINE = ReplacingMergeTree()
ORDER BY (product_id);

-- System metrics table for monitoring
CREATE TABLE IF NOT EXISTS monitoring_db.system_metrics (
    timestamp DateTime,
    metric_name String,
    metric_value Float64,
    labels Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, metric_name);

-- Query statistics table
CREATE TABLE IF NOT EXISTS monitoring_db.query_stats (
    query_time DateTime,
    query_duration_ms UInt64,
    query_text String,
    user String,
    exception_code Int32,
    result_rows UInt64,
    result_bytes UInt64,
    read_rows UInt64,
    read_bytes UInt64
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(query_time)
ORDER BY (query_time, user);

-- Table for storing ETL logs
CREATE TABLE IF NOT EXISTS analytics.etl_logs (
    log_time DateTime,
    job_name String,
    status String,
    rows_processed UInt64,
    rows_failed UInt64,
    duration_seconds UInt32,
    error_message String
) ENGINE = MergeTree()
ORDER BY (log_time, job_name);

-- Dictionary example
CREATE DICTIONARY IF NOT EXISTS tutorial.countries (
    country_id UInt64,
    country_name String
)
PRIMARY KEY country_id
SOURCE(CLICKHOUSE(HOST 'localhost' PORT 9000 TABLE 'countries_dict' DB 'tutorial'))
LIFETIME(MIN 0 MAX 300)
LAYOUT(CACHE(SIZE_IN_CELLS 100));

-- Grant necessary permissions (if needed)
-- These can be customized based on your security requirements
GRANT CREATE ON tutorial.* TO default;
GRANT INSERT ON tutorial.* TO default;
GRANT SELECT ON tutorial.* TO default;
GRANT ALTER ON tutorial.* TO default;

-- Set configuration parameters
-- Note: Some settings may need to be set in config files instead
SET max_insert_threads = 4;
SET max_query_size = 262144;
SET log_queries = 1;
SET log_queries_min_type = 'QUERY_FINISH';

-- Log successful initialization
SELECT 'ClickHouse initialization completed successfully' AS status;
