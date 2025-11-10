@echo off
REM ==============================================
REM PipeZone - Start All Services (Windows CMD)
REM ==============================================

echo.
echo ========================================
echo PipeZone - Starting All Services
echo ========================================
echo.

REM Get script directory
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..
set DOCKER_DIR=%PROJECT_ROOT%\setup\docker

REM Check if .env exists
if not exist "%PROJECT_ROOT%\.env" (
    echo [ERROR] .env file not found!
    echo.
    echo Please copy .env.example to .env and configure it:
    echo   copy .env.example .env
    echo.
    pause
    exit /b 1
)

REM Load environment variables from .env
echo Loading environment variables...
for /f "usebackq tokens=*" %%a in ("%PROJECT_ROOT%\.env") do (
    echo %%a | findstr /v "^#" | findstr "=" >nul
    if not errorlevel 1 (
        set %%a
    )
)

cd /d "%DOCKER_DIR%"

REM Create Docker network if it doesn't exist
echo.
echo Creating Docker network...
docker network create pipezone_network 2>nul
if errorlevel 1 (
    echo Network already exists or created successfully
)

REM Step 1: Start Infrastructure
echo.
echo [1/3] Starting Infrastructure Services (MySQL, MinIO, Vault)...
docker-compose -f docker-compose.infra.yml up -d
if errorlevel 1 (
    echo [ERROR] Failed to start infrastructure services
    pause
    exit /b 1
)

echo Waiting for services to initialize...
timeout /t 15 /nobreak >nul

REM Step 2: Start Airflow
echo.
echo [2/3] Starting Airflow Services...
docker-compose -f docker-compose.airflow.yml up -d
if errorlevel 1 (
    echo [ERROR] Failed to start Airflow services
    pause
    exit /b 1
)

echo Waiting for Airflow to initialize...
timeout /t 20 /nobreak >nul

REM Step 3: Start Spark Cluster
echo.
echo [3/3] Starting Spark Cluster...
docker-compose -f docker-compose.spark.yml up -d
if errorlevel 1 (
    echo [ERROR] Failed to start Spark services
    pause
    exit /b 1
)

timeout /t 5 /nobreak >nul

echo.
echo ========================================
echo PipeZone Platform Started Successfully!
echo ========================================
echo.
echo Access URLs:
echo   - Airflow UI:        http://localhost:%AIRFLOW_WEBSERVER_PORT%
echo   - MinIO Console:     http://localhost:%MINIO_CONSOLE_PORT%
echo   - Vault UI:          http://localhost:8200
echo   - Spark Master UI:   http://localhost:%SPARK_MASTER_WEBUI_PORT%
echo   - Spark Worker UI:   http://localhost:%SPARK_WORKER_WEBUI_PORT%
echo.
echo Credentials:
echo   - Airflow:  %AIRFLOW_ADMIN_USERNAME% / %AIRFLOW_ADMIN_PASSWORD%
echo   - MinIO:    %MINIO_ROOT_USER% / %MINIO_ROOT_PASSWORD%
echo.
echo Press any key to exit...
pause >nul
