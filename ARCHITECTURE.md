# 🏗️ PipeZone Architecture

## Overview

PipeZone - Fivetran-like data pipeline platform with **Airflow + Spark** integration.

## 🎯 Design Philosophy

1. **Airflow-Centric**: All orchestration and execution happens in Airflow
2. **Spark for Processing**: PySpark for distributed data processing
3. **MinIO Data Lake**: Raw → Bronze → Silver → Gold layers
4. **YAML-Defined**: No coding required for standard flows
5. **Production-Ready**: No Jupyter notebooks - pure Airflow DAGs

## 📊 Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                         PIPEZONE PLATFORM                           │
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐                                               │
│  │   Data Sources   │                                               │
│  │                  │                                               │
│  │  • PostgreSQL    │                                               │
│  │  • MySQL         │                                               │
│  │  • MongoDB       │                                               │
│  │  • APIs          │                                               │
│  └────────┬─────────┘                                               │
│           │                                                          │
│           │ JDBC/Native Connectors                                  │
│           ▼                                                          │
│  ┌────────────────────────────────────────────────────┐            │
│  │           AIRFLOW (Orchestration Layer)             │            │
│  │                                                      │            │
│  │  ┌──────────────────────────────────────────────┐  │            │
│  │  │  Custom Airflow Image                        │  │            │
│  │  │  • Python 3.11                               │  │            │
│  │  │  • PySpark 3.4.2                             │  │            │
│  │  │  • All Database Drivers (JDBC + Python)      │  │            │
│  │  │  • MinIO/S3 Libraries                        │  │            │
│  │  │  • Vault Integration                         │  │            │
│  │  └──────────────────────────────────────────────┘  │            │
│  │                                                      │            │
│  │  ┌──────────────────────────────────────────────┐  │            │
│  │  │  DAGs (Auto-generated from YAML)             │  │            │
│  │  │                                               │  │            │
│  │  │  read_from_source()                          │  │            │
│  │  │         ↓                                     │  │            │
│  │  │  write_to_raw()        ─────────────┐        │  │            │
│  │  │         ↓                            │        │  │            │
│  │  │  transform() [optional]              │        │  │            │
│  │  │         ↓                            │        │  │            │
│  │  │  write_to_target()                   │        │  │            │
│  │  │         ↓                            │        │  │            │
│  │  │  log_execution()                     │        │  │            │
│  │  └──────────────┬───────────────────────┘        │  │            │
│  │                 │                       │        │  │            │
│  └─────────────────┼───────────────────────┼────────┘  │            │
│                    │ SparkSession          │            │            │
│                    │ Connection            │            │            │
│                    ▼                       │            │            │
│  ┌─────────────────────────────────────┐  │            │            │
│  │      SPARK CLUSTER                   │  │            │            │
│  │                                      │  │            │            │
│  │  ┌──────────────┐  ┌──────────────┐│  │            │            │
│  │  │ Spark Master │  │ Spark Worker ││  │            │            │
│  │  │   port:7077  │  │              ││  │            │            │
│  │  └──────┬───────┘  └──────┬───────┘│  │            │            │
│  │         │                 │        │  │            │            │
│  │         └────────┬────────┘        │  │            │            │
│  │                  │                 │  │            │            │
│  └──────────────────┼─────────────────┘  │            │            │
│                     │ DataFrame Operations│            │            │
│                     │ (Lazy Evaluation)   │            │            │
│                     ▼                     │            │            │
│  ┌──────────────────────────────────────┐│            │            │
│  │         MINIO DATA LAKE               ││            │            │
│  │                                       ││            │            │
│  │  s3a://raw/     ← Source data        ││◄───────────┘            │
│  │  s3a://bronze/  ← Cleaned data       ││                         │
│  │  s3a://silver/  ← Enriched data      ││                         │
│  │  s3a://gold/    ← Analytics ready    ││                         │
│  │                                       ││                         │
│  └───────────────────────────────────────┘│                         │
│                                            │                         │
│  ┌─────────────────────────────────────┐  │                         │
│  │         MYSQL METADATA               │  │                         │
│  │                                      │  │                         │
│  │  • pipeline_execution_logs           │  │                         │
│  │  • incremental_state                 │  │                         │
│  │  • connections_registry              │  │                         │
│  │  • flows_registry                    │  │                         │
│  │  • data_quality_checks               │  │                         │
│  └──────────────────────────────────────┘  │                         │
│                                             │                         │
└─────────────────────────────────────────────┘                         │
```

## 🔄 Data Flow Pattern

### Pattern 1: Source → Raw

```python
# Airflow DAG (auto-generated from YAML)
def execute_spark_flow(flow_name):
    # 1. Create SparkSession with cluster connection
    spark = SparkSession.builder \
        .master("spark://spark-master:7077") \
        .appName(f"PipeZone-{flow_name}") \
        .getOrCreate()

    # 2. Read from source using JDBC/connector
    df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("dbtable", table) \
        .load()

    # 3. Write to MinIO raw layer (lazy evaluation triggers here)
    df.write \
        .format("parquet") \
        .mode("append") \
        .partitionBy("year", "month", "day") \
        .save("s3a://raw/postgres/users/")

    # 4. Update incremental state
    max_value = df.agg(F.max("updated_at")).collect()[0][0]
    update_state(flow_name, max_value)

    # 5. Log to MySQL
    log_execution(execution_id, flow_name, status="success")
```

### Pattern 2: Raw → Bronze (Transformation)

```python
def transform_raw_to_bronze(flow_name):
    spark = SparkSession.builder.getOrCreate()

    # Read from raw
    df = spark.read.parquet("s3a://raw/postgres/users/")

    # Apply transformations (still lazy)
    df = df.dropDuplicates(["id"]) \
           .withColumn("email", F.lower(F.trim("email"))) \
           .filter("email IS NOT NULL") \
           .withColumn("processed_at", F.current_timestamp()) \
           .withColumn("layer", F.lit("bronze"))

    # Write to bronze (execution happens here)
    df.write \
        .format("parquet") \
        .mode("append") \
        .partitionBy("country", "year", "month") \
        .save("s3a://bronze/users/")
```

## 🧩 Components

### 1. Infrastructure Layer

**MySQL** - Metadata Storage
- Airflow database
- Pipeline execution logs
- Incremental state tracking
- Connection/flow registry

**MinIO** - Object Storage (S3-compatible)
- Raw bucket - unprocessed source data
- Bronze bucket - cleaned/validated data
- Silver bucket - enriched/joined data
- Gold bucket - analytics-ready data

**Vault** - Secrets Management
- Database credentials
- API keys
- Connection strings

### 2. Orchestration Layer

**Airflow** (Custom Image)
- Base: `apache/airflow:2.8.1-python3.11`
- Added: PySpark 3.4.2
- Added: Java 17 (for Spark)
- Added: All database drivers (JDBC + Python)
- Added: MinIO/S3 libraries (boto3, s3fs, minio)
- Added: Data validation libraries

Components:
- **Webserver**: UI for monitoring
- **Scheduler**: Triggers DAGs based on schedule
- **Triggerer**: Handles async operations
- **Workers**: Execute tasks (LocalExecutor)

### 3. Processing Layer

**Spark Cluster**
- **Master**: Coordinates job execution
- **Workers**: Execute Spark jobs
- **Bitnami/Spark 3.4**: Stable, production-ready image

Connection:
- Airflow → `spark://spark-master:7077`
- Lazy evaluation until write operation
- DataFrame sharing across tasks

### 4. Application Layer

**Core** (`/opt/pipezone/core/`)
- `utils/`: Helper libraries
  - `connection_manager.py`: Database/MinIO connections
  - `flow_executor.py`: Deprecated (now in Airflow DAG)

**Metadata** (`/opt/pipezone/metadata/`)
- `connections/`: Connection YAML files
- `flows/`: Flow definition YAML files
- `schemas/`: Schema definitions

**DAGs** (`/opt/airflow/dags/`)
- `pipezone_spark_flow_dag.py`: Main DAG generator
  - Auto-creates DAG for each flow
  - Handles all source types
  - Manages incremental sync
  - Logs execution

## 📋 Data Flow Lifecycle

### 1. Flow Definition (YAML)

```yaml
name: extract_users
source:
  connection: postgres_prod
  table:
    schema: public
    name: users
  incremental:
    enabled: true
    column: updated_at

target:
  connection: minio_raw
  path: postgres/users/
  format: parquet
  partition_by: [year, month, day]

schedule:
  enabled: true
  cron: "0 */6 * * *"
```

### 2. DAG Generation (Automatic)

Airflow scanner:
1. Reads YAML from `/opt/pipezone/metadata/flows/`
2. Creates DAG: `pipezone_extract_users`
3. Registers in Airflow
4. Scheduler picks up based on cron

### 3. Execution (Airflow + Spark)

```
Airflow Scheduler
    ↓
Airflow Worker picks task
    ↓
Python function: execute_spark_flow()
    ↓
Create SparkSession (connects to cluster)
    ↓
Read from source (lazy - no data movement yet)
    ↓
Apply transformations (lazy - builds execution plan)
    ↓
Write to MinIO (triggers execution - data moves here)
    ↓
Update MySQL (incremental state + execution logs)
    ↓
SparkSession.stop()
```

### 4. Monitoring

- **Airflow UI**: DAG runs, task status, logs
- **Spark UI**: Job execution, stages, tasks
- **MySQL**: Execution history, incremental state
- **MinIO Console**: Data files, partitions

## 🔧 Technical Details

### Spark Configuration

```python
SparkSession.builder \
    .master("spark://spark-master:7077") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", minio_user) \
    .config("spark.hadoop.fs.s3a.secret.key", minio_password) \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .getOrCreate()
```

### JDBC Drivers (Pre-installed)

- PostgreSQL: `postgresql-42.7.1.jar`
- MySQL: `mysql-connector-j-8.2.0.jar`
- SQL Server: `mssql-jdbc-12.4.2.jre11.jar`
- Oracle: `ojdbc8-23.3.0.23.09.jar`
- ClickHouse: `clickhouse-jdbc-0.5.0-all.jar`
- Hadoop AWS (S3): `hadoop-aws-3.3.4.jar`

### Python Libraries (Pre-installed)

**Database Drivers:**
- psycopg2-binary, pymysql, mysqlclient
- pyodbc, pymssql (SQL Server)
- cx-Oracle, oracledb
- pymongo, motor (MongoDB)
- cassandra-driver, redis, elasticsearch

**Data Processing:**
- pyspark==3.4.2
- pandas, numpy, pyarrow
- fastparquet

**Storage:**
- boto3, minio, s3fs

**Utilities:**
- hvac (Vault), sqlalchemy, pyyaml

## 🎯 Benefits

### 1. Simplified Architecture
- ❌ No separate Jupyter environment
- ✅ Single orchestration layer (Airflow)
- ✅ Easier to maintain and deploy

### 2. Production-Ready
- ✅ All execution in Airflow DAGs
- ✅ Proper logging and monitoring
- ✅ Retry mechanisms built-in
- ✅ Easy CI/CD integration

### 3. Performance
- ✅ DataFrame sharing (lazy evaluation)
- ✅ Spark cluster for distributed processing
- ✅ Optimized for large datasets
- ✅ Adaptive query execution

### 4. Developer Experience
- ✅ YAML-based configuration (no code)
- ✅ Auto-generated DAGs
- ✅ Incremental sync out of the box
- ✅ Data quality checks built-in

## 🔒 Security

1. **Vault Integration**: All sensitive credentials in Vault
2. **Network Isolation**: Docker network for inter-service communication
3. **No Hardcoded Secrets**: Environment variables + Vault
4. **MySQL User Separation**: Different users for different services

## 📈 Scalability

1. **Horizontal Scaling**: Add more Spark workers
2. **Airflow Workers**: Increase LocalExecutor parallelism or use CeleryExecutor
3. **MinIO**: Distributed mode for production
4. **MySQL**: Read replicas for high availability

## 🚀 Deployment

```bash
# Development
bash setup/scripts/start-all.sh

# Production
docker-compose -f setup/docker/docker-compose.infra.yml up -d
docker-compose -f setup/docker/docker-compose.airflow.yml up -d
docker-compose -f setup/docker/docker-compose.spark.yml up -d
```

## 📊 Monitoring Stack

- **Airflow UI**: http://localhost:8080
- **Spark Master UI**: http://localhost:8081
- **Spark Worker UI**: http://localhost:8082
- **MinIO Console**: http://localhost:9001

## 🔄 Comparison with Jupyter Architecture

| Aspect | Old (Jupyter) | New (Airflow-only) |
|--------|---------------|-------------------|
| Orchestration | Airflow | Airflow |
| Development | Jupyter Notebooks | Airflow DAGs |
| Production | Convert notebook → script | Direct DAG execution |
| Spark Access | Via Jupyter kernel | Direct PySpark in DAG |
| Deployment | 2-step (notebook + Airflow) | 1-step (Airflow) |
| CI/CD | Complex | Simple |
| Monitoring | Multiple UIs | Unified in Airflow |
| Resource Usage | Higher | Lower |

---

**Architecture Version**: 2.0 (Airflow-centric)
**Last Updated**: 2025-11-09
