-- ==============================================
-- PIPEZONE - MySQL Initialization Script
-- ==============================================

-- Create PipeZone metadata database
CREATE DATABASE IF NOT EXISTS pipezone_metadata CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create Airflow database
CREATE DATABASE IF NOT EXISTS airflow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create users
CREATE USER IF NOT EXISTS 'pipezone'@'%' IDENTIFIED BY 'pipezone_secure_2024';
CREATE USER IF NOT EXISTS 'airflow'@'%' IDENTIFIED BY 'airflow_secure_2024';

-- Grant privileges
GRANT ALL PRIVILEGES ON pipezone_metadata.* TO 'pipezone'@'%';
GRANT ALL PRIVILEGES ON airflow.* TO 'airflow'@'%';

FLUSH PRIVILEGES;

-- Use pipezone_metadata database
USE pipezone_metadata;

-- Create pipeline execution logs table
CREATE TABLE IF NOT EXISTS pipeline_execution_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    execution_id VARCHAR(255) NOT NULL UNIQUE,
    flow_name VARCHAR(255) NOT NULL,
    source_connection VARCHAR(255) NOT NULL,
    target_connection VARCHAR(255) NOT NULL,
    status ENUM('running', 'success', 'failed', 'pending') DEFAULT 'pending',
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP NULL,
    duration_seconds INT NULL,
    records_read BIGINT DEFAULT 0,
    records_written BIGINT DEFAULT 0,
    error_message TEXT NULL,
    metadata JSON NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_execution_id (execution_id),
    INDEX idx_flow_name (flow_name),
    INDEX idx_status (status),
    INDEX idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create connections registry table
CREATE TABLE IF NOT EXISTS connections_registry (
    id INT AUTO_INCREMENT PRIMARY KEY,
    connection_name VARCHAR(255) NOT NULL UNIQUE,
    connection_type VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    config_path VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_connection_name (connection_name),
    INDEX idx_connection_type (connection_type),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create flows registry table
CREATE TABLE IF NOT EXISTS flows_registry (
    id INT AUTO_INCREMENT PRIMARY KEY,
    flow_name VARCHAR(255) NOT NULL UNIQUE,
    source_connection VARCHAR(255) NOT NULL,
    target_connection VARCHAR(255) NOT NULL,
    sync_mode ENUM('full', 'incremental', 'snapshot') DEFAULT 'full',
    schedule_interval VARCHAR(100) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    config_path VARCHAR(500) NOT NULL,
    last_execution_time TIMESTAMP NULL,
    last_execution_status VARCHAR(50) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_flow_name (flow_name),
    INDEX idx_source_connection (source_connection),
    INDEX idx_target_connection (target_connection),
    INDEX idx_is_active (is_active),
    FOREIGN KEY (source_connection) REFERENCES connections_registry(connection_name) ON DELETE RESTRICT,
    FOREIGN KEY (target_connection) REFERENCES connections_registry(connection_name) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create incremental state tracking table
CREATE TABLE IF NOT EXISTS incremental_state (
    id INT AUTO_INCREMENT PRIMARY KEY,
    flow_name VARCHAR(255) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    incremental_column VARCHAR(255) NOT NULL,
    last_value VARCHAR(500) NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_flow_table (flow_name, table_name),
    INDEX idx_flow_name (flow_name),
    FOREIGN KEY (flow_name) REFERENCES flows_registry(flow_name) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create data quality checks table
CREATE TABLE IF NOT EXISTS data_quality_checks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    execution_id VARCHAR(255) NOT NULL,
    flow_name VARCHAR(255) NOT NULL,
    check_name VARCHAR(255) NOT NULL,
    check_type VARCHAR(100) NOT NULL,
    status ENUM('passed', 'failed', 'warning') NOT NULL,
    expected_value VARCHAR(500) NULL,
    actual_value VARCHAR(500) NULL,
    error_message TEXT NULL,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_execution_id (execution_id),
    INDEX idx_flow_name (flow_name),
    INDEX idx_status (status),
    FOREIGN KEY (execution_id) REFERENCES pipeline_execution_logs(execution_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create schema versions table
CREATE TABLE IF NOT EXISTS schema_versions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    flow_name VARCHAR(255) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    schema_hash VARCHAR(64) NOT NULL,
    schema_definition JSON NOT NULL,
    version_number INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_flow_table (flow_name, table_name),
    INDEX idx_schema_hash (schema_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample connection
INSERT INTO connections_registry (connection_name, connection_type, config_path)
VALUES
    ('minio_raw', 'minio', '/opt/pipezone/metadata/connections/minio_raw.yml'),
    ('minio_bronze', 'minio', '/opt/pipezone/metadata/connections/minio_bronze.yml')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;
