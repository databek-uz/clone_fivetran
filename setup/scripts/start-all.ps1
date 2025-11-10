# ==============================================
# PipeZone - Start All Services (Windows PowerShell)
# ==============================================

Write-Host "🚀 Starting PipeZone Platform..." -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Get project root directory
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$DockerDir = Join-Path $ProjectRoot "setup\docker"

# Load environment variables from .env file
if (Test-Path (Join-Path $ProjectRoot ".env")) {
    Write-Host "✓ Loading environment variables from .env" -ForegroundColor Green
    Get-Content (Join-Path $ProjectRoot ".env") | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }
} else {
    Write-Host "❌ Error: .env file not found!" -ForegroundColor Red
    Write-Host "Please copy .env.example to .env and configure it:" -ForegroundColor Yellow
    Write-Host "  cp .env.example .env" -ForegroundColor Yellow
    exit 1
}

Set-Location $DockerDir

# Create Docker network if it doesn't exist
Write-Host ""
Write-Host "Creating Docker network..." -ForegroundColor Cyan
docker network create pipezone_network 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Network already exists or created successfully" -ForegroundColor Gray
}

# Step 1: Start Infrastructure Services
Write-Host ""
Write-Host "📦 Step 1: Starting Infrastructure Services (MySQL, MinIO, Vault)..." -ForegroundColor Cyan
docker-compose -f docker-compose.infra.yml up -d

Write-Host "⏳ Waiting for infrastructure to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check MySQL health
Write-Host "   Checking MySQL..." -ForegroundColor Gray
$maxRetries = 30
$retries = 0
while ($retries -lt $maxRetries) {
    $result = docker exec pipezone_mysql mysqladmin ping -h localhost -u root -p"$env:MYSQL_ROOT_PASSWORD" --silent 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ MySQL is ready" -ForegroundColor Green
        break
    }
    Write-Host "   Waiting for MySQL..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
    $retries++
}

# Check MinIO health
Write-Host "   Checking MinIO..." -ForegroundColor Gray
$retries = 0
while ($retries -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$env:MINIO_PORT/minio/health/live" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "   ✓ MinIO is ready" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "   Waiting for MinIO..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        $retries++
    }
}

# Step 2: Start Airflow
Write-Host ""
Write-Host "✈️  Step 2: Starting Airflow Services..." -ForegroundColor Cyan
docker-compose -f docker-compose.airflow.yml up -d

Write-Host "⏳ Waiting for Airflow to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Step 3: Start Spark Cluster
Write-Host ""
Write-Host "⚡ Step 3: Starting Spark Cluster..." -ForegroundColor Cyan
docker-compose -f docker-compose.spark.yml up -d

Write-Host "⏳ Waiting for Spark to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ PipeZone Platform Started Successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Access URLs:" -ForegroundColor Cyan
Write-Host "   • Airflow UI:        http://localhost:$env:AIRFLOW_WEBSERVER_PORT" -ForegroundColor White
Write-Host "   • MinIO Console:     http://localhost:$env:MINIO_CONSOLE_PORT" -ForegroundColor White
Write-Host "   • Vault UI:          http://localhost:8200" -ForegroundColor White
Write-Host "   • Spark Master UI:   http://localhost:$env:SPARK_MASTER_WEBUI_PORT" -ForegroundColor White
Write-Host "   • Spark Worker UI:   http://localhost:$env:SPARK_WORKER_WEBUI_PORT" -ForegroundColor White
Write-Host ""
Write-Host "🔐 Credentials:" -ForegroundColor Cyan
Write-Host "   • Airflow:   username=$env:AIRFLOW_ADMIN_USERNAME, password=$env:AIRFLOW_ADMIN_PASSWORD" -ForegroundColor White
Write-Host "   • MinIO:     username=$env:MINIO_ROOT_USER, password=$env:MINIO_ROOT_PASSWORD" -ForegroundColor White
Write-Host "   • Vault:     token=$env:VAULT_TOKEN" -ForegroundColor White
Write-Host ""
Write-Host "📝 Check logs:" -ForegroundColor Cyan
Write-Host "   docker-compose -f setup\docker\docker-compose.infra.yml logs -f" -ForegroundColor Gray
Write-Host "   docker-compose -f setup\docker\docker-compose.airflow.yml logs -f" -ForegroundColor Gray
Write-Host "   docker-compose -f setup\docker\docker-compose.spark.yml logs -f" -ForegroundColor Gray
Write-Host ""
