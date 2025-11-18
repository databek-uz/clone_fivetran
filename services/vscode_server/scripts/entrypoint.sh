#!/bin/bash
# =============================================================================
# VS Code Server Entrypoint Script
# =============================================================================
# This script runs on container startup and:
# 1. Initializes the virtual environment
# 2. Configures MinIO client
# 3. Restores user settings from backup
# 4. Starts code-server
# =============================================================================

set -e

echo "========================================="
echo "PipeZone VS Code Server - Starting..."
echo "========================================="

# Environment variables
export USER_ID=${USER_ID:-coder}
export VENV_PATH="/home/coder/.venv"
export REQUIREMENTS_FILE="/home/coder/workspace/requirements.txt"

# Configure MinIO client if credentials are provided
if [ -n "$MINIO_ENDPOINT" ] && [ -n "$MINIO_ACCESS_KEY" ] && [ -n "$MINIO_SECRET_KEY" ]; then
    echo "Configuring MinIO client..."
    mc alias set minio http://$MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY 2>/dev/null || true
    echo "✓ MinIO client configured"
fi

# Create user workspace bucket if it doesn't exist
if command -v mc &> /dev/null; then
    if mc alias list | grep -q "minio" 2>/dev/null; then
        mc mb --ignore-existing minio/user-workspaces/$USER_ID 2>/dev/null || true
    fi
fi

# Initialize virtual environment
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo "Initializing virtual environment..."
    /home/coder/scripts/setup_venv.sh
else
    echo "✓ Virtual environment exists"
fi

# Activate virtual environment
source $VENV_PATH/bin/activate

# Create workspace directories
mkdir -p /home/coder/workspace
mkdir -p /home/coder/.jupyter
mkdir -p /home/coder/.config

# Configure Jupyter if not already configured
if [ ! -f "/home/coder/.jupyter/jupyter_notebook_config.py" ]; then
    echo "Configuring Jupyter..."
    jupyter notebook --generate-config
    cat >> /home/coder/.jupyter/jupyter_notebook_config.py << 'EOF'
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.port = 8888
c.NotebookApp.open_browser = False
c.NotebookApp.allow_root = False
c.NotebookApp.token = ''
c.NotebookApp.password = ''
c.NotebookApp.notebook_dir = '/home/coder/workspace'
EOF
    echo "✓ Jupyter configured"
fi

# Set up kernel for Jupyter
python -m ipykernel install --user --name pipezone --display-name "PipeZone (Python 3.11)"

# Display startup information
echo "========================================="
echo "Environment Information:"
echo "  User: $USER_ID"
echo "  Python: $(python --version)"
echo "  Workspace: /home/coder/workspace"
echo "  Virtual Env: $VENV_PATH"
echo "  Cluster: ${SELECTED_CLUSTER:-medium_cluster}"
echo "  MinIO: ${MINIO_ENDPOINT:-not configured}"
echo "  Airflow: ${AIRFLOW_URL:-not configured}"
echo "========================================="

# Log startup event
echo "[$(date -Iseconds)] VS Code Server starting for user: $USER_ID" >> /home/coder/logs/startup.log 2>/dev/null || true

# Start code-server with the provided arguments
echo "Starting code-server..."
echo "========================================="

# Execute the CMD from Dockerfile (code-server)
exec "$@"
