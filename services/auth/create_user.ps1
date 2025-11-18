# =============================================================================
# User Creation Script for PipeZone (PowerShell - Windows)
# =============================================================================
# Creates a new user with workspace and MinIO folder
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Password
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Creating user: $Username" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$USERS_FILE = ".\users.txt"
$WORKSPACES_DIR = "..\..\workspaces"

# Check if user already exists
if (Test-Path $USERS_FILE) {
    $existingUsers = Get-Content $USERS_FILE
    if ($existingUsers | Select-String -Pattern "^${Username}:") {
        Write-Host "Error: User $Username already exists" -ForegroundColor Red
        exit 1
    }
}

# Generate password hash using Python
Write-Host "Generating password hash..." -ForegroundColor Yellow
$passwordHash = python -c "import bcrypt; print(bcrypt.hashpw('$Password'.encode(), bcrypt.gensalt()).decode())"

if (-not $passwordHash) {
    Write-Host "Error: Failed to generate password hash" -ForegroundColor Red
    Write-Host "Please install bcrypt: pip install bcrypt" -ForegroundColor Yellow
    exit 1
}

# Create workspace directory
$USER_WORKSPACE = Join-Path $WORKSPACES_DIR $Username
Write-Host "Creating workspace: $USER_WORKSPACE" -ForegroundColor Yellow

New-Item -ItemType Directory -Path $USER_WORKSPACE -Force | Out-Null
New-Item -ItemType Directory -Path "$USER_WORKSPACE\notebooks" -Force | Out-Null
New-Item -ItemType Directory -Path "$USER_WORKSPACE\data" -Force | Out-Null
New-Item -ItemType Directory -Path "$USER_WORKSPACE\scripts" -Force | Out-Null

Write-Host "✓ Created workspace: $USER_WORKSPACE" -ForegroundColor Green

# Initialize git repository in workspace
Set-Location $USER_WORKSPACE

git init
git config user.name $Username
git config user.email "${Username}@pipezone.local"

# Create README
$readmeContent = @"
# ${Username}'s PipeZone Workspace

Welcome to your PipeZone workspace!

## Directory Structure

- ``notebooks/`` - Your Jupyter notebooks
- ``data/`` - Local data files
- ``scripts/`` - Python scripts and utilities

## Quick Start

1. Create a new notebook in the ``notebooks/`` directory
2. Access shared resources at ``/shared/``
3. Schedule notebook jobs via Airflow UI

## Resources

- [User Guide](../shared/docs/USER_GUIDE.md)
- [Examples](../shared/notebooks/examples/)
- [API Reference](../shared/docs/API_REFERENCE.md)

Happy coding! 🚀
"@

$readmeContent | Out-File -FilePath "README.md" -Encoding UTF8

git add README.md
git commit -m "Initial commit"

Set-Location -

Write-Host "✓ Initialized git repository" -ForegroundColor Green

# Add user to users file
$userEntry = "${Username}:${passwordHash}:${USER_WORKSPACE}"
Add-Content -Path $USERS_FILE -Value $userEntry
Write-Host "✓ Added user to users.txt" -ForegroundColor Green

# Create MinIO user bucket
Write-Host "Creating MinIO user bucket..." -ForegroundColor Yellow
docker-compose exec -T minio mc alias set minio http://localhost:9000 $env:MINIO_ROOT_USER $env:MINIO_ROOT_PASSWORD 2>&1 | Out-Null
docker-compose exec -T minio mc mb --ignore-existing minio/user-workspaces/$Username 2>&1 | Out-Null
Write-Host "✓ Created MinIO bucket: user-workspaces/$Username" -ForegroundColor Green

# Create user's docker-compose override (for VS Code Server instance)
$userCount = (Get-Content $USERS_FILE).Count
$VSCODE_PORT = 8080 + $userCount

$composeContent = @"
version: '3.8'

services:
  vscode-${Username}:
    build: ./services/vscode_server
    container_name: pipezone-vscode-${Username}
    environment:
      - PASSWORD=`${VSCODE_PASSWORD}
      - USER_ID=${Username}
      - SELECTED_CLUSTER=medium_cluster
      - MINIO_ENDPOINT=`${MINIO_ENDPOINT}
      - MINIO_ACCESS_KEY=`${MINIO_ROOT_USER}
      - MINIO_SECRET_KEY=`${MINIO_ROOT_PASSWORD}
      - AIRFLOW_URL=http://airflow-webserver:8080
      - SPARK_MASTER_URL=`${SPARK_MASTER_URL}
    volumes:
      - ./workspaces/${Username}:/home/coder/workspace
      - ./shared:/home/coder/shared:ro
      - vscode_extensions_${Username}:/home/coder/.local
    ports:
      - "${VSCODE_PORT}:8080"
    networks:
      - pipezone-network
    restart: unless-stopped

volumes:
  vscode_extensions_${Username}:

networks:
  pipezone-network:
    external: true
"@

$composeContent | Out-File -FilePath "..\..\docker-compose.${Username}.yml" -Encoding UTF8
Write-Host "✓ Created docker-compose override for VS Code Server" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "User created successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Username: $Username" -ForegroundColor Cyan
Write-Host "Workspace: $USER_WORKSPACE" -ForegroundColor Cyan
Write-Host "VS Code Port: $VSCODE_PORT" -ForegroundColor Cyan
Write-Host "MinIO Bucket: user-workspaces/$Username" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start VS Code Server for this user:" -ForegroundColor Yellow
Write-Host "  docker-compose -f docker-compose.yml -f docker-compose.${Username}.yml up -d" -ForegroundColor White
Write-Host ""
Write-Host "Access URL: http://localhost:$VSCODE_PORT" -ForegroundColor Cyan
Write-Host ""
