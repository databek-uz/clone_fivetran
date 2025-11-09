# 🚀 PipeZone

**Open-source Fivetran-like data pipeline framework — fully YAML-defined**

PipeZone is a modern data integration platform that allows you to build, schedule, and monitor data pipelines using simple YAML configurations. Extract data from various sources, transform it with Spark, and load it into your data lake with zero coding required.

## ✨ Features

- 🔌 **Multiple Source Connectors**: PostgreSQL, MySQL, SQL Server, Oracle, MongoDB, and more
- 📦 **Data Lake Architecture**: MinIO-based object storage with Raw → Bronze → Silver → Gold layers
- 🔄 **Smart Incremental Sync**: Automatic state management for incremental data loads
- ⚡ **Spark Processing**: Distributed data processing with PySpark
- 📊 **Airflow Orchestration**: Automatic DAG generation from YAML flows
- 🔐 **Secrets Management**: HashiCorp Vault integration for secure credential storage
- 📓 **Jupyter Integration**: Interactive development environment with all database drivers
- 🐳 **Docker-based**: Easy deployment with Docker Compose
- 📝 **YAML-Defined**: No coding required - define everything in YAML

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     PipeZone Platform                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Sources    │───▶│  Spark Jobs  │───▶│  Data Lake   │  │
│  │              │    │              │    │              │  │
│  │ • PostgreSQL │    │ • Transform  │    │ • Raw        │  │
│  │ • MySQL      │    │ • Validate   │    │ • Bronze     │  │
│  │ • MongoDB    │    │ • Enrich     │    │ • Silver     │  │
│  │ • APIs       │    │              │    │ • Gold       │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                    │                    │          │
│         └────────────────────┼────────────────────┘          │
│                              │                               │
│                    ┌─────────▼─────────┐                     │
│                    │  Airflow Scheduler │                     │
│                    │  (Auto-generated)  │                     │
│                    └────────────────────┘                     │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure: MySQL • MinIO • Vault • Spark • Jupyter    │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
pipezone/
├── core/                       # Core processing logic
│   ├── notebooks/             # Jupyter notebooks for development
│   ├── jobs/                  # Production Spark jobs
│   ├── transformations/       # Data transformation logic
│   ├── utils/                 # Utility modules
│   │   ├── connection_manager.py  # Connection management
│   │   └── flow_executor.py       # Flow execution engine
│   └── drivers/               # Database drivers
│
├── schedule/                   # Orchestration
│   └── airflow/
│       ├── dags/              # Airflow DAGs (auto-generated)
│       ├── plugins/           # Custom plugins
│       └── logs/              # Airflow logs
│
├── metadata/                   # YAML configurations
│   ├── connections/           # Connection definitions
│   │   ├── postgres_source.yml
│   │   ├── mysql_source.yml
│   │   ├── minio_raw.yml
│   │   └── minio_bronze.yml
│   ├── flows/                 # Data flow definitions
│   │   ├── postgres_users_to_raw.yml
│   │   ├── mysql_orders_to_raw.yml
│   │   └── raw_to_bronze_users.yml
│   └── schemas/               # Schema definitions
│
├── setup/                      # Setup & deployment
│   ├── docker/
│   │   ├── docker-compose.infra.yml     # MySQL, MinIO, Vault
│   │   ├── docker-compose.airflow.yml   # Airflow services
│   │   ├── docker-compose.notebooks.yml # Jupyter + Spark
│   │   ├── Dockerfile.jupyter           # Custom Jupyter image
│   │   └── init-scripts/                # Initialization scripts
│   └── scripts/
│       ├── start-all.sh       # Start all services
│       └── stop-all.sh        # Stop all services
│
├── data/                       # Docker volumes (gitignored)
│   ├── mysql/                 # MySQL data
│   ├── minio/                 # MinIO data
│   ├── vault/                 # Vault data
│   └── notebooks/             # Jupyter data
│
└── .env                        # Environment configuration
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- At least 8GB RAM available
- Ports available: 3306, 8080, 8888, 9000, 9001, 8200, 7077, 8081, 8082

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/pipezone.git
cd pipezone
```

### 2. Configure Environment

The `.env` file is already configured with default values. Review and update as needed:

```bash
# Review the .env file
cat .env

# Update credentials if needed
nano .env
```

### 3. Start All Services

```bash
bash setup/scripts/start-all.sh
```

This will start:
- ✅ MySQL (metadata storage)
- ✅ MinIO (object storage with raw/bronze/silver/gold buckets)
- ✅ Vault (secrets management)
- ✅ Airflow (scheduler + webserver)
- ✅ Spark (master + worker)
- ✅ Jupyter (with PySpark + all database drivers)

### 4. Access the Platform

| Service | URL | Credentials |
|---------|-----|-------------|
| Airflow UI | http://localhost:8080 | admin / admin |
| MinIO Console | http://localhost:9001 | pipezone_admin / pipezone_minio_2024 |
| Jupyter Lab | http://localhost:8888 | token: pipezone2024 |
| Vault UI | http://localhost:8200 | token: pipezone-dev-token-2024 |
| Spark Master | http://localhost:8081 | - |
| Spark Worker | http://localhost:8082 | - |

## 📝 Creating Your First Pipeline

### Step 1: Define a Connection

Create a connection YAML in `metadata/connections/`:

```yaml
# metadata/connections/postgres_production.yml
name: postgres_production
type: postgresql
description: Production PostgreSQL database

connection:
  host: ${POSTGRES_HOST}
  port: 5432
  database: ${POSTGRES_DATABASE}
  username: ${POSTGRES_USER}
  password: ${POSTGRES_PASSWORD}

vault:
  enabled: true
  path: secret/data/postgres/production
  keys:
    username: username
    password: password

metadata:
  owner: data_engineering
  tags:
    - production
    - postgresql
```

### Step 2: Define a Data Flow

Create a flow YAML in `metadata/flows/`:

```yaml
# metadata/flows/extract_customers.yml
name: extract_customers
description: Extract customers from PostgreSQL to MinIO raw layer

source:
  connection: postgres_production
  type: table
  table:
    schema: public
    name: customers
  incremental:
    enabled: true
    column: updated_at
    strategy: max_value

target:
  connection: minio_raw
  type: object_storage
  path: postgres/customers/
  format: parquet
  partition_by:
    - country
    - year
    - month
  write_mode: append
  compression: snappy

data_quality:
  enabled: true
  checks:
    - name: unique_customer_id
      type: unique
      columns: [customer_id]

    - name: email_valid
      type: regex
      column: email
      pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

schedule:
  enabled: true
  cron: "0 */6 * * *"  # Every 6 hours
  timezone: Asia/Tashkent

metadata:
  owner: data_engineering
  sla: 6h
  priority: high
  tags:
    - customers
    - incremental
```

### Step 3: Run the Pipeline

**Option A: Via Airflow (Automatic)**

1. Go to Airflow UI: http://localhost:8080
2. Find your DAG: `pipezone_extract_customers`
3. Enable it and trigger manually, or wait for scheduled run

**Option B: Via Jupyter Notebook**

```python
from flow_executor import FlowExecutor

# Initialize executor
executor = FlowExecutor()

# Execute flow
result = executor.execute_flow('extract_customers')

print(f"Status: {result['status']}")
print(f"Records: {result['records_written']}")
print(f"Duration: {result['duration_seconds']}s")
```

**Option C: Via Python Script**

```bash
docker exec pipezone_jupyter python -c "
from sys import path
path.insert(0, '/home/pipezone/utils')
from flow_executor import FlowExecutor
result = FlowExecutor().execute_flow('extract_customers')
print(result)
"
```

## 🔄 Data Flow Patterns

### Pattern 1: Incremental Sync

Automatically track the last loaded value and only extract new/updated records:

```yaml
incremental:
  enabled: true
  column: updated_at
  strategy: max_value
```

### Pattern 2: Full Refresh

Complete reload of the source data:

```yaml
incremental:
  enabled: false

target:
  write_mode: overwrite
```

### Pattern 3: Raw → Bronze Transformation

Clean and standardize raw data:

```yaml
# metadata/flows/raw_to_bronze_customers.yml
source:
  connection: minio_raw
  path: postgres/customers/
  format: parquet

target:
  connection: minio_bronze
  path: customers/
  format: parquet

transformation:
  enabled: true
  steps:
    - name: remove_duplicates
      type: deduplicate
      columns: [customer_id]

    - name: clean_email
      type: transform
      column: email
      expression: "lower(trim(email))"

    - name: add_metadata
      type: add_columns
      columns:
        processed_at: "current_timestamp()"
        layer: "'bronze'"
```

## 🗄️ Supported Data Sources

### Databases
- ✅ PostgreSQL
- ✅ MySQL / MariaDB
- ✅ SQL Server
- ✅ Oracle
- ✅ MongoDB
- ✅ Cassandra
- ✅ Redis
- ✅ Elasticsearch
- ✅ ClickHouse
- ✅ Snowflake

### File Systems
- ✅ MinIO / S3
- ✅ Local filesystem
- ✅ HDFS

All JDBC drivers and Python connectors are pre-installed in the Jupyter container!

## 📊 Monitoring & Logs

### Execution Logs

All pipeline executions are logged to MySQL:

```sql
SELECT * FROM pipezone_metadata.pipeline_execution_logs
ORDER BY start_time DESC
LIMIT 10;
```

### Incremental State

Check the current incremental state:

```sql
SELECT * FROM pipezone_metadata.incremental_state;
```

### Airflow Logs

```bash
docker-compose -f setup/docker/docker-compose.airflow.yml logs -f airflow-scheduler
```

### Spark Logs

```bash
docker-compose -f setup/docker/docker-compose.notebooks.yml logs -f spark-master
```

## 🛠️ Development Workflow

### 1. Develop in Jupyter

Access Jupyter at http://localhost:8888 (token: `pipezone2024`)

```python
# Load your data
from connection_manager import ConnectionManager

cm = ConnectionManager()
config = cm.load_connection_config('postgres_production')

# Test connection
cm.test_connection('postgres_production')

# Use with Spark
from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()

df = spark.read \
    .format("jdbc") \
    .option("url", cm.get_connection_string('postgres_production')) \
    .option("dbtable", "public.customers") \
    .load()

df.show()
```

### 2. Test Flow Locally

```python
from flow_executor import FlowExecutor

executor = FlowExecutor()
result = executor.execute_flow('your_flow_name')
```

### 3. Deploy to Airflow

Simply enable the schedule in your flow YAML:

```yaml
schedule:
  enabled: true
  cron: "0 */6 * * *"
```

Airflow will automatically pick up the flow and create a DAG!

## 🔐 Security Best Practices

### Use Vault for Secrets

1. Store secrets in Vault:

```bash
docker exec -it pipezone_vault sh

vault kv put secret/postgres/production \
  username=myuser \
  password=mypassword
```

2. Reference in connection YAML:

```yaml
vault:
  enabled: true
  path: secret/data/postgres/production
  keys:
    username: username
    password: password
```

### Environment Variables

Never commit `.env` to git! Use `.env.example` as a template.

## 🧪 Testing

### Test Connections

```python
from connection_manager import ConnectionManager

cm = ConnectionManager()

# List all connections
connections = cm.list_connections()

# Test each connection
for conn in connections:
    status = "✓" if cm.test_connection(conn) else "✗"
    print(f"{status} {conn}")
```

### Validate Flow Config

```python
from flow_executor import FlowExecutor

executor = FlowExecutor()
config = executor.load_flow_config('your_flow_name')
print(config)
```

## 📦 Data Quality

Built-in data quality checks:

```yaml
data_quality:
  enabled: true
  checks:
    - name: row_count
      type: not_null
      threshold: 0

    - name: unique_id
      type: unique
      columns: [id]

    - name: email_format
      type: regex
      column: email
      pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

    - name: amount_range
      type: range
      column: amount
      min: 0
      max: 1000000
```

Results are stored in `data_quality_checks` table.

## 🐳 Docker Commands

```bash
# Start all services
bash setup/scripts/start-all.sh

# Stop all services
bash setup/scripts/stop-all.sh

# View logs
docker-compose -f setup/docker/docker-compose.infra.yml logs -f

# Restart a specific service
docker-compose -f setup/docker/docker-compose.airflow.yml restart airflow-scheduler

# Access container shell
docker exec -it pipezone_jupyter bash
docker exec -it pipezone_mysql mysql -u root -p
```

## 🔧 Troubleshooting

### Services won't start

```bash
# Check Docker resources
docker system df

# Clean up
docker system prune -a

# Restart Docker daemon
sudo systemctl restart docker
```

### Airflow DAGs not appearing

```bash
# Check logs
docker-compose -f setup/docker/docker-compose.airflow.yml logs -f airflow-scheduler

# Verify metadata path is mounted
docker exec pipezone_airflow_scheduler ls -la /opt/pipezone/metadata/flows
```

### Spark connection issues

```bash
# Check Spark master is running
curl http://localhost:8081

# Verify network
docker network inspect pipezone_network
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Inspired by:
- Fivetran
- Airbyte
- Apache Airflow
- Delta Lake

---

**Built with ❤️ for the data engineering community**

For questions and support, please open an issue on GitHub.
