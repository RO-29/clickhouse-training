-- MySQL Initialization Script for Migration Module
-- Purpose: Create source database with tables for Debezium CDC

-- Create source database
CREATE DATABASE IF NOT EXISTS source_db;
USE source_db;

-- Enable binary logging (required for Debezium)
-- This should be set in the MySQL command line options

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Products table
CREATE TABLE IF NOT EXISTS products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL,
    description TEXT,
    stock_quantity INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sales/Orders table
CREATE TABLE IF NOT EXISTS sales (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    sale_date DATE NOT NULL,
    sale_datetime DATETIME NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50),
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_sale_date (sale_date),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inventory/Stock table
CREATE TABLE IF NOT EXISTS inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    quantity_on_hand INT DEFAULT 0,
    quantity_reserved INT DEFAULT 0,
    quantity_available INT DEFAULT 0,
    reorder_point INT DEFAULT 10,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    UNIQUE KEY unique_product_warehouse (product_id, warehouse_id),
    INDEX idx_warehouse_id (warehouse_id),
    INDEX idx_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(255),
    operation VARCHAR(10),
    record_id INT,
    old_values JSON,
    new_values JSON,
    changed_by VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_table_name (table_name),
    INDEX idx_changed_at (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample customers
INSERT INTO customers (first_name, last_name, email, phone, address, city, country, postal_code) VALUES
('John', 'Doe', 'john.doe@example.com', '+1-555-0001', '123 Main Street', 'New York', 'USA', '10001'),
('Jane', 'Smith', 'jane.smith@example.com', '+1-555-0002', '456 Oak Avenue', 'Los Angeles', 'USA', '90001'),
('Robert', 'Johnson', 'robert.johnson@example.com', '+1-555-0003', '789 Pine Road', 'Chicago', 'USA', '60601'),
('Emily', 'Williams', 'emily.williams@example.com', '+44-555-0004', '321 Elm Street', 'London', 'UK', 'SW1A 1AA'),
('Michael', 'Brown', 'michael.brown@example.com', '+1-555-0005', '654 Maple Drive', 'Toronto', 'Canada', 'M5H 2N2');

-- Insert sample products
INSERT INTO products (product_name, category, price, description, stock_quantity) VALUES
('Laptop', 'Electronics', 999.99, 'High-performance laptop for professionals', 50),
('Wireless Mouse', 'Accessories', 29.99, 'Ergonomic wireless mouse with USB receiver', 200),
('Monitor 27-inch 4K', 'Electronics', 299.99, '27-inch 4K Ultra HD monitor', 75),
('Mechanical Keyboard', 'Accessories', 79.99, 'RGB mechanical keyboard with Cherry MX switches', 120),
('USB-C Cable', 'Accessories', 14.99, '2-meter USB-C charging and data cable', 500),
('Webcam HD', 'Accessories', 59.99, '1080p HD webcam with microphone', 80),
('Desk Lamp LED', 'Accessories', 39.99, 'Adjustable LED desk lamp with USB charging', 90),
('Monitor Stand Arm', 'Accessories', 49.99, 'Full-motion monitor stand arm for 17-32 inch displays', 60);

-- Insert sample sales transactions
INSERT INTO sales (customer_id, sale_date, sale_datetime, product_id, quantity, unit_price, total_amount, payment_method, status) VALUES
(1, '2024-01-20', '2024-01-20 10:15:00', 1, 1, 999.99, 999.99, 'credit_card', 'completed'),
(1, '2024-01-20', '2024-01-20 10:20:00', 2, 2, 29.99, 59.98, 'credit_card', 'completed'),
(2, '2024-01-21', '2024-01-21 14:30:00', 3, 1, 299.99, 299.99, 'debit_card', 'completed'),
(3, '2024-01-21', '2024-01-21 15:45:00', 4, 1, 79.99, 79.99, 'credit_card', 'processing'),
(4, '2024-01-22', '2024-01-22 09:00:00', 6, 1, 59.99, 59.99, 'paypal', 'pending'),
(5, '2024-01-22', '2024-01-22 11:30:00', 5, 3, 14.99, 44.97, 'credit_card', 'completed'),
(2, '2024-01-22', '2024-01-22 16:20:00', 7, 2, 39.99, 79.98, 'credit_card', 'completed'),
(1, '2024-01-23', '2024-01-23 08:45:00', 8, 1, 49.99, 49.99, 'credit_card', 'processing');

-- Insert sample inventory records
INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand, quantity_reserved, quantity_available, reorder_point) VALUES
(1, 1, 50, 5, 45, 10),
(1, 2, 30, 2, 28, 10),
(2, 1, 200, 20, 180, 50),
(2, 2, 150, 15, 135, 50),
(3, 1, 75, 10, 65, 15),
(4, 1, 120, 12, 108, 20),
(5, 1, 500, 50, 450, 100),
(6, 1, 80, 8, 72, 15),
(7, 1, 90, 9, 81, 20),
(8, 1, 60, 6, 54, 12);

-- Create views for common queries
CREATE VIEW IF NOT EXISTS customer_order_summary AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    COUNT(s.transaction_id) AS total_orders,
    SUM(s.total_amount) AS total_spent,
    AVG(s.total_amount) AS average_order,
    MAX(s.sale_date) AS last_order_date
FROM customers c
LEFT JOIN sales s ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email;

-- Create stored procedure for audit logging
DELIMITER //
CREATE PROCEDURE log_audit(
    p_table_name VARCHAR(255),
    p_operation VARCHAR(10),
    p_record_id INT,
    p_new_values JSON
)
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, new_values, changed_by)
    VALUES (p_table_name, p_operation, p_record_id, p_new_values, CURRENT_USER());
END //
DELIMITER ;

-- Create user for Debezium connector
CREATE USER IF NOT EXISTS 'debezium_user'@'%' IDENTIFIED BY 'debezium_password';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'debezium_user'@'%';
FLUSH PRIVILEGES;

-- Log successful initialization
SELECT 'MySQL database initialization completed successfully' AS status;
