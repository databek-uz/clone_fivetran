# =============================================================================
# PipeZone Platform - Windows Shutdown Script (PowerShell)
# =============================================================================
# Gracefully stops all platform services
# =============================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "🛑 PipeZone Platform - Stopping..." -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Stop all services
Write-Host "Stopping all services..." -ForegroundColor Yellow
docker-compose down

# Stop any user VS Code Server instances
Get-ChildItem -Path "." -Filter "docker-compose.*.yml" | Where-Object {
    $_.Name -ne "docker-compose.yml"
} | ForEach-Object {
    Write-Host "Stopping services from $($_.Name)..." -ForegroundColor Yellow
    docker-compose -f "docker-compose.yml" -f $_.Name down
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ PipeZone Platform Stopped" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To start again:" -ForegroundColor Cyan
Write-Host "  .\scripts\start_platform.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To remove all data (⚠️  WARNING - This deletes everything!):" -ForegroundColor Yellow
Write-Host "  docker-compose down -v" -ForegroundColor White
Write-Host "  Remove-Item -Recurse -Force data" -ForegroundColor White
Write-Host ""
