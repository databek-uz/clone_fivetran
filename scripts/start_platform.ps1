# =============================================================================
# PipeZone Platform - Windows Startup Script (PowerShell)
# =============================================================================
# Starts all platform services in the correct order
# =============================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "🚀 PipeZone Platform - Starting..." -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
try {
    docker info | Out-Null
}
catch {
    Write-Host "Error: Docker is not running" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again" -ForegroundColor Red
    exit 1
}

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "Creating .env file from template..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "✓ Created .env file" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  Please edit .env and update the following:" -ForegroundColor Yellow
    Write-Host "  - MINIO_ROOT_PASSWORD" -ForegroundColor Yellow
    Write-Host "  - POSTGRES_PASSWORD" -ForegroundColor Yellow
    Write-Host "  - REDIS_PASSWORD" -ForegroundColor Yellow
    Write-Host "  - AIRFLOW_ADMIN_PASSWORD" -ForegroundColor Yellow
    Write-Host "  - VSCODE_PASSWORD" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue after editing .env"
}

# Create necessary directories
Write-Host "Creating directories..." -ForegroundColor Yellow
$directories = @(
    "workspaces",
    "shared\notebooks\templates",
    "shared\notebooks\examples",
    "shared\notebooks\production",
    "shared\libraries",
    "shared\data",
    "shared\reviews",
    "data\minio",
    "data\postgres",
    "data\redis"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Host "✓ Directories created" -ForegroundColor Green
Write-Host ""

# Generate Fernet key for Airflow if not set
$envContent = Get-Content ".env" -Raw
if ($envContent -notmatch "AIRFLOW__CORE__FERNET_KEY=.+") {
    Write-Host "Generating Airflow Fernet key..." -ForegroundColor Yellow

    # Generate Fernet key using Python
    $fernetKey = python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

    if ($fernetKey) {
        $envContent = $envContent -replace "AIRFLOW__CORE__FERNET_KEY=.*", "AIRFLOW__CORE__FERNET_KEY=$fernetKey"
        $envContent | Set-Content ".env"
        Write-Host "✓ Fernet key generated" -ForegroundColor Green
        Write-Host ""
    }
}

# Start core services
Write-Host "Starting core services (PostgreSQL, Redis, MinIO)..." -ForegroundColor Yellow
docker-compose up -d postgres redis minio minio-init
Write-Host "✓ Core services started" -ForegroundColor Green
Write-Host ""

# Wait for services to be ready
Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check service health
Write-Host "Checking service health..." -ForegroundColor Yellow

# PostgreSQL
$pgReady = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        docker-compose exec -T postgres pg_isready -U airflow 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $pgReady = $true
            break
        }
    }
    catch {}
    Write-Host "  Waiting for PostgreSQL..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

if ($pgReady) {
    Write-Host "  ✓ PostgreSQL is ready" -ForegroundColor Green
}
else {
    Write-Host "  ✗ PostgreSQL failed to start" -ForegroundColor Red
    exit 1
}

# Redis
$redisReady = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        docker-compose exec -T redis redis-cli ping 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $redisReady = $true
            break
        }
    }
    catch {}
    Write-Host "  Waiting for Redis..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

if ($redisReady) {
    Write-Host "  ✓ Redis is ready" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Redis failed to start" -ForegroundColor Red
    exit 1
}

# MinIO
$minioReady = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/minio/health/live" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $minioReady = $true
            break
        }
    }
    catch {}
    Write-Host "  Waiting for MinIO..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

if ($minioReady) {
    Write-Host "  ✓ MinIO is ready" -ForegroundColor Green
}
else {
    Write-Host "  ✗ MinIO failed to start" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Initialize Airflow database (only on first run)
if (-not (Test-Path ".airflow_initialized")) {
    Write-Host "First run detected - initializing Airflow database..." -ForegroundColor Yellow
    docker-compose run --rm airflow-webserver airflow db init 2>&1 | Out-Null
    docker-compose run --rm airflow-webserver airflow db upgrade 2>&1 | Out-Null
    New-Item -ItemType File -Path ".airflow_initialized" -Force | Out-Null
    Write-Host "✓ Airflow database initialized" -ForegroundColor Green
}
else {
    Write-Host "Airflow database already initialized - skipping..." -ForegroundColor Gray
    Write-Host "Running database upgrade to apply any new migrations..." -ForegroundColor Yellow
    docker-compose run --rm airflow-webserver airflow db upgrade 2>&1 | Out-Null
    Write-Host "✓ Airflow database ready" -ForegroundColor Green
}
Write-Host ""

# Start Airflow services
Write-Host "Starting Airflow services..." -ForegroundColor Yellow

# Load worker count from .env (default: 1)
$workerCount = 1
if (Test-Path ".env") {
    $envContent = Get-Content ".env" | Where-Object { $_ -match "^AIRFLOW_WORKER_COUNT=" }
    if ($envContent) {
        $workerCount = [int]($envContent -replace "AIRFLOW_WORKER_COUNT=", "")
    }
}

# Build worker list dynamically
$workers = @()
for ($i = 1; $i -le $workerCount; $i++) {
    $workers += "airflow-worker-$i"
}

Write-Host "Configuring $workerCount Airflow worker(s)..." -ForegroundColor Gray
$workerList = $workers -join " "
Invoke-Expression "docker-compose up -d airflow-webserver airflow-scheduler $workerList airflow-flower"
Write-Host "✓ Airflow services started (workers: $workerCount)" -ForegroundColor Green
Write-Host ""

# Start monitoring services
Write-Host "Starting monitoring services..." -ForegroundColor Yellow
docker-compose up -d prometheus grafana node-exporter cadvisor
Write-Host "✓ Monitoring services started" -ForegroundColor Green
Write-Host ""

# Start Spark History Server
Write-Host "Starting Spark History Server..." -ForegroundColor Yellow
docker-compose up -d spark-history-server
Write-Host "✓ Spark History Server started" -ForegroundColor Green
Write-Host ""

# Wait for Airflow to be ready
Write-Host "Waiting for Airflow to be ready..." -ForegroundColor Yellow
$airflowReady = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8081/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $airflowReady = $true
            break
        }
    }
    catch {}
    Write-Host "  Waiting for Airflow webserver..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

if ($airflowReady) {
    Write-Host "✓ Airflow is ready" -ForegroundColor Green
}
else {
    Write-Host "⚠ Airflow may still be starting..." -ForegroundColor Yellow
}
Write-Host ""

# Display status
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ PipeZone Platform Started Successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Cyan
Write-Host "  📊 Airflow:          http://localhost:8081" -ForegroundColor White
Write-Host "  ☁️  MinIO Console:    http://localhost:9001" -ForegroundColor White
Write-Host "  📈 Grafana:          http://localhost:3000" -ForegroundColor White
Write-Host "  🔥 Spark History:    http://localhost:18080" -ForegroundColor White
Write-Host "  🌸 Flower (Celery):  http://localhost:5555" -ForegroundColor White
Write-Host "  📊 Prometheus:       http://localhost:9090" -ForegroundColor White
Write-Host ""
Write-Host "Default Credentials:" -ForegroundColor Cyan
Write-Host "  Airflow:  admin / admin123" -ForegroundColor White
Write-Host "  MinIO:    admin / changeme123" -ForegroundColor White
Write-Host "  Grafana:  admin / admin123" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Create a user: .\services\auth\create_user.ps1 <username> <password>" -ForegroundColor White
Write-Host "  2. Start VS Code Server for the user" -ForegroundColor White
Write-Host "  3. Access the platform via service URLs above" -ForegroundColor White
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Cyan
Write-Host "  docker-compose logs -f" -ForegroundColor White
Write-Host ""
Write-Host "To stop the platform:" -ForegroundColor Cyan
Write-Host "  .\scripts\stop_platform.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Happy data engineering! 🚀" -ForegroundColor Green
Write-Host ""
