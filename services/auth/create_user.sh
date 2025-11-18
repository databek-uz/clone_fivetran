#!/bin/bash
# =============================================================================
# User Creation Script for PipeZone
# =============================================================================
# Creates a new user with workspace and MinIO folder
# =============================================================================

set -e

# Detect script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to project root directory
cd "$PROJECT_ROOT"

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo ""
    echo "Example: $0 john mypassword123"
    exit 1
fi

USERNAME=$1
PASSWORD=$2
USERS_FILE="$PROJECT_ROOT/services/auth/users.txt"
WORKSPACES_DIR="$PROJECT_ROOT/workspaces"

echo "========================================="
echo "Creating user: $USERNAME"
echo "========================================="

# Create users file directory if it doesn't exist
mkdir -p "$(dirname "$USERS_FILE")"
touch "$USERS_FILE"

# Check if user already exists
if grep -q "^$USERNAME:" "$USERS_FILE" 2>/dev/null; then
    echo "Error: User $USERNAME already exists"
    exit 1
fi

# Check for bcrypt and install if needed
echo "Checking dependencies..."
if ! python3 -c "import bcrypt" 2>/dev/null; then
    echo "Installing bcrypt..."
    pip3 install bcrypt --quiet || {
        echo "Error: Failed to install bcrypt. Please install it manually:"
        echo "  pip3 install bcrypt"
        exit 1
    }
fi

# Generate password hash using Python
echo "Generating password hash..."
PASSWORD_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$PASSWORD'.encode(), bcrypt.gensalt()).decode())")

# Create workspace directory
USER_WORKSPACE="$WORKSPACES_DIR/$USERNAME"
mkdir -p "$USER_WORKSPACE"
mkdir -p "$USER_WORKSPACE/notebooks"
mkdir -p "$USER_WORKSPACE/data"
mkdir -p "$USER_WORKSPACE/scripts"

echo "✓ Created workspace: $USER_WORKSPACE"

# Initialize git repository in workspace
cd "$USER_WORKSPACE"
git init

# Configure git for this repository (local config, no global changes needed)
git config user.name "$USERNAME" 2>/dev/null || true
git config user.email "${USERNAME}@pipezone.local" 2>/dev/null || true

# Create README
cat > README.md << EOF
# $USERNAME's PipeZone Workspace

Welcome to your PipeZone workspace!

## Directory Structure

- \`notebooks/\` - Your Jupyter notebooks
- \`data/\` - Local data files
- \`scripts/\` - Python scripts and utilities

## Quick Start

1. Create a new notebook in the \`notebooks/\` directory
2. Access shared resources at \`/shared/\`
3. Schedule notebook jobs via Airflow UI

## Resources

- [User Guide](../shared/docs/USER_GUIDE.md)
- [Examples](../shared/notebooks/examples/)
- [API Reference](../shared/docs/API_REFERENCE.md)

Happy coding! 🚀
EOF

git add README.md
git commit -m "Initial commit"

cd "$PROJECT_ROOT" > /dev/null

echo "✓ Initialized git repository"

# Add user to users file
echo "$USERNAME:$PASSWORD_HASH:$USER_WORKSPACE" >> "$USERS_FILE"
echo "✓ Added user to users.txt"

# Create user's docker-compose override (for VS Code Server instance)
VSCODE_PORT=$((8080 + $(wc -l < "$USERS_FILE")))

cat > "$PROJECT_ROOT/docker-compose.$USERNAME.yml" << EOF
version: '3.8'

services:
  vscode-$USERNAME:
    build: ./services/vscode_server
    container_name: pipezone-vscode-$USERNAME
    environment:
      - PASSWORD=\${VSCODE_PASSWORD}
      - USER_ID=$USERNAME
      - SELECTED_CLUSTER=medium_cluster
      - MINIO_ENDPOINT=\${MINIO_ENDPOINT}
      - MINIO_ACCESS_KEY=\${MINIO_ROOT_USER}
      - MINIO_SECRET_KEY=\${MINIO_ROOT_PASSWORD}
      - AIRFLOW_URL=http://airflow-webserver:8080
      - SPARK_MASTER_URL=\${SPARK_MASTER_URL}
    volumes:
      - ./workspaces/$USERNAME:/home/coder/workspace
      - ./shared:/home/coder/shared:ro
      - vscode_extensions_$USERNAME:/home/coder/.local
    ports:
      - "$VSCODE_PORT:8080"
    networks:
      - pipezone-network
    restart: unless-stopped

volumes:
  vscode_extensions_$USERNAME:

networks:
  pipezone-network:
    external: true
EOF

echo "✓ Created docker-compose override for VS Code Server"

echo ""
echo "========================================="
echo "User created successfully!"
echo "========================================="
echo ""
echo "Username: $USERNAME"
echo "Workspace: $USER_WORKSPACE"
echo "VS Code Port: $VSCODE_PORT"
echo ""
echo "To start VS Code Server for this user:"
echo "  cd $PROJECT_ROOT"
echo "  docker-compose -f docker-compose.yml -f docker-compose.$USERNAME.yml up -d"
echo ""
echo "Access URL: http://localhost:$VSCODE_PORT"
echo ""
