#!/bin/bash
# =============================================================================
# PipeZone Platform Startup Script
# =============================================================================
# Starts all platform services in the correct order
# =============================================================================

set -e

echo "========================================="
echo "🚀 PipeZone Platform - Starting..."
echo "========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "✓ Created .env file"
    echo ""
    echo "⚠️  Please edit .env and update the following:"
    echo "  - MINIO_ROOT_PASSWORD"
    echo "  - POSTGRES_PASSWORD"
    echo "  - REDIS_PASSWORD"
    echo "  - AIRFLOW_ADMIN_PASSWORD"
    echo "  - VSCODE_PASSWORD"
    echo ""
    read -p "Press Enter to continue after editing .env..."
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p workspaces
mkdir -p shared/{notebooks/{templates,examples,production},libraries,data,reviews}
mkdir -p data/minio
mkdir -p data/postgres
mkdir -p data/redis
echo "✓ Directories created"
echo ""

# Generate Fernet key for Airflow if not set
if ! grep -q "^AIRFLOW__CORE__FERNET_KEY=.\+" .env; then
    echo "Generating Airflow Fernet key..."
    FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    sed -i "s/^AIRFLOW__CORE__FERNET_KEY=.*/AIRFLOW__CORE__FERNET_KEY=$FERNET_KEY/" .env
    echo "✓ Fernet key generated"
    echo ""
fi

# Start core services
echo "Starting core services (PostgreSQL, Redis, MinIO)..."
docker-compose up -d postgres redis minio minio-init
echo "✓ Core services started"
echo ""

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo "Checking service health..."

# PostgreSQL
until docker-compose exec -T postgres pg_isready -U airflow > /dev/null 2>&1; do
    echo "  Waiting for PostgreSQL..."
    sleep 2
done
echo "  ✓ PostgreSQL is ready"

# Redis
until docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; do
    echo "  Waiting for Redis..."
    sleep 2
done
echo "  ✓ Redis is ready"

# MinIO
until curl -sf http://localhost:9000/minio/health/live > /dev/null 2>&1; do
    echo "  Waiting for MinIO..."
    sleep 2
done
echo "  ✓ MinIO is ready"

echo ""

# Initialize Airflow database (only on first run)
if [ ! -f ".airflow_initialized" ]; then
    echo "First run detected - initializing Airflow database..."
    docker-compose run --rm airflow-webserver airflow db init
    docker-compose run --rm airflow-webserver airflow db upgrade
    touch .airflow_initialized
    echo "✓ Airflow database initialized"
else
    echo "Airflow database already initialized - skipping..."
    echo "Running database upgrade to apply any new migrations..."
    docker-compose run --rm airflow-webserver airflow db upgrade || true
    echo "✓ Airflow database ready"
fi
echo ""

# Start Airflow services
echo "Starting Airflow services..."

# Load worker count from .env (default: 1)
WORKER_COUNT=$(grep "^AIRFLOW_WORKER_COUNT=" .env 2>/dev/null | cut -d'=' -f2 || echo "1")
WORKER_COUNT=${WORKER_COUNT:-1}

# Build worker list dynamically
WORKERS=""
for i in $(seq 1 $WORKER_COUNT); do
    WORKERS="$WORKERS airflow-worker-$i"
done

echo "Configuring $WORKER_COUNT Airflow worker(s)..."
docker-compose up -d airflow-webserver airflow-scheduler $WORKERS airflow-flower
echo "✓ Airflow services started (workers: $WORKER_COUNT)"
echo ""

# Start monitoring services
echo "Starting monitoring services..."
docker-compose up -d prometheus grafana node-exporter cadvisor
echo "✓ Monitoring services started"
echo ""

# Start Spark History Server
echo "Starting Spark History Server..."
docker-compose up -d spark-history-server
echo "✓ Spark History Server started"
echo ""

# Wait for Airflow to be ready
echo "Waiting for Airflow to be ready..."
until curl -sf http://localhost:8081/health > /dev/null 2>&1; do
    echo "  Waiting for Airflow webserver..."
    sleep 5
done
echo "✓ Airflow is ready"
echo ""

# Display status
echo "========================================="
echo "✅ PipeZone Platform Started Successfully!"
echo "========================================="
echo ""
echo "Service URLs:"
echo "  📊 Airflow:          http://localhost:8081"
echo "  ☁️  MinIO Console:    http://localhost:9001"
echo "  📈 Grafana:          http://localhost:3000"
echo "  🔥 Spark History:    http://localhost:18080"
echo "  🌸 Flower (Celery):  http://localhost:5555"
echo "  📊 Prometheus:       http://localhost:9090"
echo ""
echo "Default Credentials:"
echo "  Airflow:  admin / admin123"
echo "  MinIO:    admin / changeme123"
echo "  Grafana:  admin / admin123"
echo ""
echo "Next Steps:"
echo "  1. Create a user: ./services/auth/create_user.sh <username> <password>"
echo "  2. Start VS Code Server for the user"
echo "  3. Access the platform via service URLs above"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop the platform:"
echo "  ./scripts/stop_platform.sh"
echo ""
echo "Happy data engineering! 🚀"
echo ""
