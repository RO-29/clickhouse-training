-- Migration Setup for Module 10
-- Purpose: Create tables to receive data from MongoDB and MySQL via Kafka/Debezium

CREATE DATABASE IF NOT EXISTS target_db;
CREATE DATABASE IF NOT EXISTS migration_logs;

-- MongoDB data - Users collection
CREATE TABLE IF NOT EXISTS target_db.mongo_users (
    _id String,
    username String,
    email String,
    status String,
    created_at DateTime,
    updated_at DateTime,
    profile_data String
) ENGINE = ReplacingMergeTree()
ORDER BY (_id)
PARTITION BY toYYYYMM(created_at);

-- MongoDB data - Orders collection
CREATE TABLE IF NOT EXISTS target_db.mongo_orders (
    _id String,
    user_id String,
    order_number String,
    items String,
    total_amount Float64,
    currency String,
    status String,
    created_at DateTime,
    updated_at DateTime,
    shipping_address String
) ENGINE = ReplacingMergeTree()
ORDER BY (user_id, created_at)
PARTITION BY toYYYYMM(created_at);

-- MongoDB data - Products collection
CREATE TABLE IF NOT EXISTS target_db.mongo_products (
    _id String,
    name String,
    category String,
    price Float64,
    description String,
    stock_quantity UInt32,
    created_at DateTime,
    updated_at DateTime,
    metadata String
) ENGINE = ReplacingMergeTree()
ORDER BY (_id)
PARTITION BY toYYYYMM(created_at);

-- MySQL data - Customers table
CREATE TABLE IF NOT EXISTS target_db.mysql_customers (
    customer_id UInt64,
    first_name String,
    last_name String,
    email String,
    phone String,
    address String,
    city String,
    country String,
    postal_code String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = ReplacingMergeTree()
ORDER BY (customer_id)
PARTITION BY toYYYYMM(created_at);

-- MySQL data - Sales transactions
CREATE TABLE IF NOT EXISTS target_db.mysql_sales (
    transaction_id UInt64,
    customer_id UInt64,
    sale_date Date,
    sale_datetime DateTime,
    product_id UInt64,
    quantity UInt32,
    unit_price Float64,
    total_amount Float64,
    payment_method String,
    status String,
    created_at DateTime
) ENGINE = MergeTree()
ORDER BY (sale_date, customer_id)
PARTITION BY toYYYYMM(sale_date);

-- MySQL data - Inventory
CREATE TABLE IF NOT EXISTS target_db.mysql_inventory (
    product_id UInt64,
    warehouse_id UInt8,
    quantity_on_hand UInt32,
    quantity_reserved UInt32,
    quantity_available UInt32,
    reorder_point UInt32,
    updated_at DateTime
) ENGINE = ReplacingMergeTree()
ORDER BY (product_id, warehouse_id)
PARTITION BY toYYYYMM(updated_at);

-- Kafka CDC topics - MongoDB users changes
CREATE TABLE IF NOT EXISTS target_db.kafka_mongo_users_cdc (
    op String,
    ts_ms UInt64,
    after String,
    before String,
    source String
) ENGINE = Kafka()
SETTINGS kafka_broker_list = 'kafka:29092',
          kafka_topic_list = 'mongodb.source_db.users',
          kafka_group_id = 'clickhouse-mongo-users',
          kafka_format = 'JSONEachRow',
          kafka_skip_broken_messages = 1,
          kafka_commit_on_select = 1;

-- Kafka CDC topics - MySQL customers changes
CREATE TABLE IF NOT EXISTS target_db.kafka_mysql_customers_cdc (
    op String,
    ts_ms UInt64,
    after String,
    before String,
    source String
) ENGINE = Kafka()
SETTINGS kafka_broker_list = 'kafka:29092',
          kafka_topic_list = 'mysql.source_db.customers',
          kafka_group_id = 'clickhouse-mysql-customers',
          kafka_format = 'JSONEachRow',
          kafka_skip_broken_messages = 1,
          kafka_commit_on_select = 1;

-- Kafka CDC topics - MySQL sales changes
CREATE TABLE IF NOT EXISTS target_db.kafka_mysql_sales_cdc (
    op String,
    ts_ms UInt64,
    after String,
    before String,
    source String
) ENGINE = Kafka()
SETTINGS kafka_broker_list = 'kafka:29092',
          kafka_topic_list = 'mysql.source_db.sales',
          kafka_group_id = 'clickhouse-mysql-sales',
          kafka_format = 'JSONEachRow',
          kafka_skip_broken_messages = 1,
          kafka_commit_on_select = 1;

-- Migration audit log
CREATE TABLE IF NOT EXISTS migration_logs.migration_events (
    event_timestamp DateTime,
    event_type String,
    source_db String,
    table_name String,
    operation String,
    rows_affected UInt64,
    duration_ms UInt64,
    status String,
    error_message String,
    metadata String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_timestamp)
ORDER BY (event_timestamp, source_db, table_name);

-- Data quality metrics table
CREATE TABLE IF NOT EXISTS migration_logs.data_quality_metrics (
    check_timestamp DateTime,
    source_table String,
    target_table String,
    total_rows_source UInt64,
    total_rows_target UInt64,
    missing_rows UInt64,
    extra_rows UInt64,
    checksum_match Bool,
    check_status String
) ENGINE = MergeTree()
ORDER BY (check_timestamp, source_table)
PARTITION BY toYYYYMM(check_timestamp);

-- Reconciliation table
CREATE TABLE IF NOT EXISTS migration_logs.reconciliation (
    reconciliation_time DateTime,
    batch_id String,
    source_system String,
    record_count UInt64,
    checksum String,
    reconciliation_status String,
    notes String
) ENGINE = MergeTree()
ORDER BY (reconciliation_time, source_system)
PARTITION BY toYYYYMM(reconciliation_time);

-- Consolidated view for reporting - combined customer and sales data
CREATE TABLE IF NOT EXISTS target_db.customer_sales_summary (
    customer_id UInt64,
    customer_name String,
    email String,
    total_transactions UInt32,
    total_sales Float64,
    average_transaction Float64,
    first_purchase_date Date,
    last_purchase_date Date,
    last_updated DateTime
) ENGINE = ReplacingMergeTree()
ORDER BY (customer_id)
PARTITION BY toYYYYMM(last_updated);

-- Log successful setup
SELECT 'Migration setup completed successfully' AS status;
