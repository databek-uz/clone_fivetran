#!/bin/bash

# ==============================================
# PipeZone - Stop All Services
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/setup/docker"

echo "🛑 Stopping PipeZone Platform..."
echo "================================"

cd "${DOCKER_DIR}"

echo "📓 Stopping Jupyter + Spark..."
docker-compose -f docker-compose.notebooks.yml down

echo "✈️  Stopping Airflow..."
docker-compose -f docker-compose.airflow.yml down

echo "📦 Stopping Infrastructure Services..."
docker-compose -f docker-compose.infra.yml down

echo ""
echo "✅ All services stopped successfully!"
echo ""
