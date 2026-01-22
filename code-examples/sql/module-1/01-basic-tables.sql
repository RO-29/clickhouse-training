-- ============================================================================
-- MODULE 1: FUNDAMENTALS
-- File: 01-basic-tables.sql
-- Purpose: Basic table creation examples in ClickHouse
-- ============================================================================

-- Create a simple table with basic data types
-- This is the foundational starting point for ClickHouse database design
CREATE TABLE IF NOT EXISTS basic_events (
    event_id UInt64,
    event_date Date,
    event_time DateTime,
    user_id UInt32,
    event_name String,
    event_value Float64,
    event_source String
) ENGINE = MergeTree()
ORDER BY (event_date, user_id)
COMMENT 'Basic events table for storing application events';

-- Create a table with nullable columns
CREATE TABLE IF NOT EXISTS events_with_nulls (
    event_id UInt64,
    event_date Date,
    user_id UInt32,
    event_name String,
    optional_data Nullable(String),
    optional_value Nullable(Float64),
    user_agent Nullable(String)
) ENGINE = MergeTree()
ORDER BY (event_date, user_id)
COMMENT 'Events table allowing null values in optional fields';

-- Create a table with enum data type
CREATE TABLE IF NOT EXISTS user_activity (
    activity_id UInt64,
    activity_date Date,
    user_id UInt32,
    activity_type Enum8('login' = 1, 'logout' = 2, 'purchase' = 3, 'browse' = 4),
    activity_duration UInt32,
    is_successful UInt8
) ENGINE = MergeTree()
ORDER BY (activity_date, user_id)
COMMENT 'User activity tracking with predefined activity types';

-- Create a table with array columns
CREATE TABLE IF NOT EXISTS product_views (
    session_id String,
    view_date Date,
    user_id UInt32,
    product_ids Array(UInt32),
    product_names Array(String),
    view_timestamps Array(DateTime),
    price_points Array(Float64)
) ENGINE = MergeTree()
ORDER BY (view_date, user_id)
COMMENT 'Product view sessions with arrays of products per session';

-- Create a table with tuple columns
CREATE TABLE IF NOT EXISTS geo_events (
    event_id UInt64,
    event_date Date,
    user_id UInt32,
    location Tuple(
        latitude Float64,
        longitude Float64,
        accuracy Float64,
        altitude Nullable(Float64)
    ),
    event_type String
) ENGINE = MergeTree()
ORDER BY (event_date, user_id)
COMMENT 'Events with geographic coordinates stored as tuples';

-- Check all tables
SHOW TABLES;
