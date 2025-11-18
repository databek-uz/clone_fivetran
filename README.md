# 🚀 PipeZone - Self-Hosted Databricks Clone

<div align="center">

**Open-source data platform with VS Code Server, Spark on Kubernetes, and Airflow orchestration**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)

[Features](#-features) •
[Quick Start](#-quick-start) •
[Architecture](#-architecture) •
[Documentation](#-documentation) •
[Contributing](#-contributing)

</div>

---

## 📖 Overview

PipeZone is a comprehensive self-hosted data platform that brings Databricks-like functionality to your infrastructure. It combines VS Code Server as an IDE, Apache Spark on Kubernetes for distributed computing, Apache Airflow for orchestration, and MinIO for S3-compatible storage.

### ✨ Features

#### 🎨 **Modern IDE Experience**
- VS Code Server with pre-configured extensions for data engineering
- Custom dashboard showing service status and quick actions
- Jupyter notebook support with Papermill execution
- Persistent virtual environments per user
- Integrated terminal with Spark, MinIO, and Airflow access

#### ⚡ **Distributed Computing**
- Apache Spark 3.5.0 on Kubernetes
- Three cluster profiles: Small (2 executors), Medium (4 executors), Large (8 executors)
- Dynamic resource allocation
- S3-compatible storage (MinIO) integration
- Spark History Server for job monitoring

#### 📅 **Workflow Orchestration**
- Apache Airflow with CeleryExecutor
- Papermill operator for notebook scheduling
- Auto-generated DAGs from notebooks
- Multi-worker setup for parallel execution
- Flower UI for Celery monitoring

#### 👥 **Multi-User Support**
- Isolated workspaces per user
- Shared folders for collaboration
- Code review system
- Per-user MinIO buckets
- Git-initialized workspaces

#### 📊 **Monitoring & Observability**
- Prometheus for metrics collection
- Grafana dashboards for visualization
- Service health monitoring
- Resource usage tracking
- Audit logging

#### ☁️ **S3-Compatible Storage**
- MinIO with versioning enabled
- Automatic bucket creation
- Lifecycle policies for cleanup
- Pre-signed URL generation
- Direct integration with Spark

---

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (Windows/Mac) or **Docker + Docker Compose** (Linux)
- **Python 3.11+** (for password hashing)
- **8GB+ RAM** available
- **50GB+ disk** space
- (Optional) Kubernetes cluster for Spark

> **📖 Detailed Installation Guide**: See [QUICKSTART.md](QUICKSTART.md) for platform-specific instructions (Windows/Linux/macOS)

### Installation

#### 🪟 Windows (PowerShell)

```powershell
# 1. Clone the repository
git clone https://github.com/databek-uz/pipezone.git
cd pipezone

# 2. Install Python dependencies
pip install bcrypt cryptography

# 3. Create environment configuration
Copy-Item .env.example .env
# Edit .env and update passwords

# 4. Start the platform
.\scripts\start_platform.ps1

# 5. Create your first user
.\services\auth\create_user.ps1 john mypassword123

# 6. Start VS Code Server for the user
docker-compose -f docker-compose.yml -f docker-compose.john.yml up -d
```

#### 🐧 Linux / 🍎 macOS (Bash)

```bash
# 1. Clone the repository
git clone https://github.com/databek-uz/pipezone.git
cd pipezone

# 2. Install Python dependencies
pip install bcrypt cryptography

# 3. Create environment configuration
cp .env.example .env
# Edit .env and update passwords

# 4. Start the platform
chmod +x scripts/*.sh services/auth/*.sh
./scripts/start_platform.sh

# 5. Create your first user
./services/auth/create_user.sh john mypassword123

# 6. Start VS Code Server for the user
docker-compose -f docker-compose.yml -f docker-compose.john.yml up -d
```

### Access the Platform

- **VS Code Server**: http://localhost:8081 (or assigned port)
- **Airflow**: http://localhost:8081 (admin / admin123)
- **MinIO Console**: http://localhost:9001 (admin / changeme123)
- **Grafana**: http://localhost:3000 (admin / admin123)
- **Spark History**: http://localhost:18080

### First Steps

1. Open VS Code Server and create a new notebook
2. Try the example notebooks in `/shared/notebooks/examples/`
3. Schedule a notebook job via Airflow
4. Monitor your Spark jobs in the History Server

### Stop the Platform

**Windows:**
```powershell
.\scripts\stop_platform.ps1
```

**Linux/macOS:**
```bash
./scripts/stop_platform.sh
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Users                                │
└────────────────┬────────────────────────────────────────────┘
                 │
    ┌────────────┼─────────────┬──────────────┐
    │            │             │              │
┌───▼────┐  ┌───▼────┐   ┌───▼─────┐   ┌───▼──────┐
│ VS Code│  │Airflow │   │  MinIO  │   │ Grafana  │
│ Server │  │   UI   │   │ Console │   │          │
└───┬────┘  └───┬────┘   └───┬─────┘   └───┬──────┘
    │           │            │             │
    │      ┌────▼────────────▼─────────────▼──┐
    │      │    PipeZone Network              │
    │      │  ┌──────────────────────────┐    │
    │      │  │  Airflow Orchestration   │    │
    │      │  │  - Scheduler             │    │
    │      │  │  - Workers (x3)          │    │
    │      │  │  - Flower                │    │
    │      │  └──────────────────────────┘    │
    │      │                                   │
    │      │  ┌──────────────────────────┐    │
    └──────┼──►  Spark on Kubernetes     │    │
           │  │  - Driver                │    │
           │  │  - Executors (2-12)      │    │
           │  │  - History Server        │    │
           │  └──────────────────────────┘    │
           │                                   │
           │  ┌──────────────────────────┐    │
           │  │  Storage Layer           │    │
           │  │  - MinIO (S3)            │    │
           │  │  - PostgreSQL            │    │
           │  │  - Redis                 │    │
           │  └──────────────────────────┘    │
           │                                   │
           │  ┌──────────────────────────┐    │
           │  │  Monitoring              │    │
           │  │  - Prometheus            │    │
           │  │  - Grafana               │    │
           │  │  - Node Exporter         │    │
           │  └──────────────────────────┘    │
           └───────────────────────────────────┘
```

### Component Overview

| Component | Purpose | Technology |
|-----------|---------|------------|
| **VS Code Server** | Development IDE | code-server |
| **Spark** | Distributed computing | Apache Spark 3.5.0 |
| **Airflow** | Workflow orchestration | Apache Airflow 2.8.1 |
| **MinIO** | S3-compatible storage | MinIO |
| **PostgreSQL** | Metadata database | PostgreSQL 15 |
| **Redis** | Message broker | Redis 7 |
| **Prometheus** | Metrics collection | Prometheus |
| **Grafana** | Visualization | Grafana |

---

## 📁 Project Structure

```
pipezone/
├── docker-compose.yml          # Main compose configuration
├── .env.example                # Environment template
├── README.md                   # This file
│
├── services/                   # Service configurations
│   ├── vscode_server/         # VS Code Server setup
│   │   ├── Dockerfile
│   │   ├── config/            # Extensions, settings
│   │   ├── home_page/         # Custom dashboard
│   │   └── scripts/           # Setup scripts
│   │
│   ├── spark_k8s/             # Spark on Kubernetes
│   │   ├── cluster_configs/   # Small/Medium/Large
│   │   └── spark_operator/    # RBAC, ServiceAccounts
│   │
│   ├── scheduler/             # Airflow configuration
│   │   ├── dags/              # DAG definitions
│   │   ├── plugins/           # Custom operators
│   │   └── scripts/           # DAG generators
│   │
│   ├── minio/                 # MinIO configuration
│   │   └── policies/          # Bucket policies
│   │
│   └── auth/                  # User management
│       └── create_user.sh     # User creation script
│
├── shared/                    # Shared resources
│   ├── notebooks/             # Shared notebooks
│   │   ├── templates/
│   │   ├── examples/
│   │   └── production/
│   ├── libraries/             # Shared Python libraries
│   ├── data/                  # Shared datasets
│   └── reviews/               # Code reviews
│
├── workspaces/           # Per-user workspaces
│   ├── user1/
│   └── user2/
│
├── monitoring/                # Monitoring configs
│   ├── prometheus/
│   └── grafana/
│
├── scripts/                   # Management scripts
│   ├── start_platform.sh
│   ├── stop_platform.sh
│   └── health_check.sh
│
└── docs/                      # Documentation
    ├── INSTALLATION.md
    ├── USER_GUIDE.md
    └── API_REFERENCE.md
```

---

## 🎯 Use Cases

### 1. **ETL Pipelines**
```python
# Schedule a daily ETL job
from datetime import datetime
from airflow import DAG
from notebook_scheduler_plugin.operators.papermill_operator import PapermillOperator

with DAG('daily_etl', schedule_interval='@daily') as dag:
    etl_task = PapermillOperator(
        task_id='run_etl',
        notebook_path='/shared/notebooks/etl_pipeline.ipynb',
        cluster_config='medium_cluster'
    )
```

### 2. **ML Model Training**
```python
# Train models on Spark cluster
import pyspark
from pyspark.ml import Pipeline
from pyspark.ml.classification import RandomForestClassifier

# Spark session auto-configured with selected cluster
df = spark.read.parquet('s3a://shared-data/training_data/')
model = RandomForestClassifier().fit(df)
model.save('s3a://model-registry/random_forest_v1/')
```

### 3. **Data Analysis**
- Create notebooks in VS Code Server
- Access shared datasets from MinIO
- Collaborate via shared folders
- Schedule recurring analysis jobs

---

## 🔧 Configuration

### Cluster Profiles

| Profile | Driver | Executors | Use Case |
|---------|--------|-----------|----------|
| **Small** | 1 CPU, 2GB | 2 x (1 CPU, 2GB) | Development, testing |
| **Medium** | 2 CPU, 4GB | 4 x (2 CPU, 4GB) | Production workloads |
| **Large** | 4 CPU, 8GB | 8 x (4 CPU, 8GB) | Heavy processing |

### Environment Variables

Key configuration in `.env`:

```env
# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=changeme123

# Airflow
AIRFLOW_ADMIN_USERNAME=admin
AIRFLOW_ADMIN_PASSWORD=admin123

# VS Code
VSCODE_PASSWORD=changeme123

# Spark
SPARK_MASTER_URL=k8s://https://kubernetes.default.svc
```

---

## 📊 Monitoring

### Grafana Dashboards

1. **System Overview** - CPU, memory, disk usage
2. **Spark Jobs** - Active jobs, executors, task failures
3. **Airflow Performance** - DAG runs, task duration
4. **User Activity** - Login frequency, resource usage

### Prometheus Metrics

- Container metrics via cAdvisor
- System metrics via Node Exporter
- MinIO metrics
- Custom application metrics

---

## 🗺️ Roadmap

- [ ] VS Code Extension for cluster management
- [ ] Built-in code review UI
- [ ] Auto-scaling based on workload
- [ ] Multi-tenancy with RBAC
- [ ] Delta Lake integration
- [ ] MLflow integration
- [ ] Kubernetes Helm chart
- [ ] Cloud deployment templates (AWS, GCP, Azure)

---

<div align="center">

**Built with ❤️ for the data engineering community**

[⭐ Star this repo](https://github.com/databek-uz/pipezone) if you find it useful!

</div>
