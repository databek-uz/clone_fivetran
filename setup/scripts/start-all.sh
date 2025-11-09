#!/bin/bash

# ==============================================
# PipeZone - Start All Services
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/setup/docker"

echo "🚀 Starting PipeZone Platform..."
echo "================================"

# Load environment variables
if [ -f "${PROJECT_ROOT}/.env" ]; then
    echo "✓ Loading environment variables from .env"
    export $(cat "${PROJECT_ROOT}/.env" | grep -v '^#' | xargs)
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

cd "${DOCKER_DIR}"

# Step 1: Start Infrastructure Services
echo ""
echo "📦 Step 1: Starting Infrastructure Services (MySQL, MinIO, Vault)..."
docker-compose -f docker-compose.infra.yml up -d

echo "⏳ Waiting for infrastructure to be ready..."
sleep 15

# Check MySQL health
echo "   Checking MySQL..."
until docker exec pipezone_mysql mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} --silent; do
    echo "   Waiting for MySQL..."
    sleep 2
done
echo "   ✓ MySQL is ready"

# Check MinIO health
echo "   Checking MinIO..."
until curl -sf http://localhost:${MINIO_PORT}/minio/health/live > /dev/null 2>&1; do
    echo "   Waiting for MinIO..."
    sleep 2
done
echo "   ✓ MinIO is ready"

# Step 2: Start Airflow
echo ""
echo "✈️  Step 2: Starting Airflow Services..."
docker-compose -f docker-compose.airflow.yml up -d

echo "⏳ Waiting for Airflow to initialize..."
sleep 20

# Step 3: Start Jupyter + Spark
echo ""
echo "📓 Step 3: Starting Jupyter Notebook + Spark..."
docker-compose -f docker-compose.notebooks.yml up -d

echo "⏳ Waiting for services to start..."
sleep 10

echo ""
echo "================================"
echo "✅ PipeZone Platform Started Successfully!"
echo ""
echo "📊 Access URLs:"
echo "   • Airflow UI:        http://localhost:${AIRFLOW_WEBSERVER_PORT}"
echo "   • MinIO Console:     http://localhost:${MINIO_CONSOLE_PORT}"
echo "   • Vault UI:          http://localhost:8200"
echo "   • Jupyter Notebook:  http://localhost:${JUPYTER_PORT}"
echo "   • Spark Master UI:   http://localhost:${SPARK_MASTER_WEBUI_PORT}"
echo "   • Spark Worker UI:   http://localhost:${SPARK_WORKER_WEBUI_PORT}"
echo ""
echo "🔐 Credentials:"
echo "   • Airflow:   username=${AIRFLOW_ADMIN_USERNAME}, password=${AIRFLOW_ADMIN_PASSWORD}"
echo "   • MinIO:     username=${MINIO_ROOT_USER}, password=${MINIO_ROOT_PASSWORD}"
echo "   • Jupyter:   token=${JUPYTER_TOKEN}"
echo "   • Vault:     token=${VAULT_TOKEN}"
echo ""
echo "📝 Check logs:"
echo "   docker-compose -f setup/docker/docker-compose.infra.yml logs -f"
echo "   docker-compose -f setup/docker/docker-compose.airflow.yml logs -f"
echo "   docker-compose -f setup/docker/docker-compose.notebooks.yml logs -f"
echo ""
