# ==============================================
# PipeZone - Stop All Services (Windows PowerShell)
# ==============================================

Write-Host "🛑 Stopping PipeZone Platform..." -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow

# Get project root directory
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$DockerDir = Join-Path $ProjectRoot "setup\docker"

Set-Location $DockerDir

Write-Host "⚡ Stopping Spark Cluster..." -ForegroundColor Gray
docker-compose -f docker-compose.spark.yml down

Write-Host "✈️  Stopping Airflow..." -ForegroundColor Gray
docker-compose -f docker-compose.airflow.yml down

Write-Host "📦 Stopping Infrastructure Services..." -ForegroundColor Gray
docker-compose -f docker-compose.infra.yml down

Write-Host ""
Write-Host "✅ All services stopped successfully!" -ForegroundColor Green
Write-Host ""
