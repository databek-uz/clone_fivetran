@echo off
REM ==============================================
REM PipeZone - Stop All Services (Windows CMD)
REM ==============================================

echo.
echo ========================================
echo PipeZone - Stopping All Services
echo ========================================
echo.

REM Get script directory
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..
set DOCKER_DIR=%PROJECT_ROOT%\setup\docker

cd /d "%DOCKER_DIR%"

echo Stopping Jupyter + Spark...
docker-compose -f docker-compose.notebooks.yml down

echo Stopping Airflow...
docker-compose -f docker-compose.airflow.yml down

echo Stopping Infrastructure Services...
docker-compose -f docker-compose.infra.yml down

echo.
echo ========================================
echo All services stopped successfully!
echo ========================================
echo.
pause
