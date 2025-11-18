#!/bin/bash
# =============================================================================
# Virtual Environment Setup Script
# =============================================================================
# This script creates and configures a persistent Python virtual environment
# for the user's workspace
# =============================================================================

set -e

VENV_PATH="/home/coder/.venv"
REQUIREMENTS_FILE="/home/coder/workspace/requirements.txt"
BACKUP_REQUIREMENTS="/home/coder/workspace/requirements_backup.txt"

echo "========================================="
echo "PipeZone - Virtual Environment Setup"
echo "========================================="

# Remove incomplete venv if exists
if [ -d "$VENV_PATH" ] && [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo "Removing incomplete virtual environment..."
    rm -rf "$VENV_PATH"
fi

# Create virtual environment if it doesn't exist
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo "Creating virtual environment at $VENV_PATH..."
    python3.11 -m venv $VENV_PATH
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
source $VENV_PATH/bin/activate

# Upgrade pip, setuptools, and wheel
echo "Upgrading pip, setuptools, and wheel..."
pip install --quiet --upgrade pip setuptools wheel pip-tools

# Check if requirements.txt exists in workspace
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "Found existing requirements.txt, installing packages..."
    pip install --quiet -r $REQUIREMENTS_FILE
    echo "✓ Packages installed from requirements.txt"
else
    echo "No requirements.txt found, creating new one..."
    pip freeze > $REQUIREMENTS_FILE
    echo "✓ Created requirements.txt"
fi

# Try to restore from MinIO backup if available
if command -v mc &> /dev/null; then
    if mc alias list | grep -q "minio" 2>/dev/null; then
        USERNAME=$(whoami)
        MINIO_REQUIREMENTS="minio/user-workspaces/$USERNAME/requirements.txt"

        if mc stat $MINIO_REQUIREMENTS &>/dev/null; then
            echo "Found requirements.txt backup in MinIO..."
            mc cp $MINIO_REQUIREMENTS $BACKUP_REQUIREMENTS

            # Ask user if they want to restore
            echo "Do you want to restore packages from MinIO backup? (y/n)"
            read -t 10 -n 1 RESTORE_CHOICE || RESTORE_CHOICE="n"
            echo

            if [ "$RESTORE_CHOICE" = "y" ]; then
                echo "Restoring packages from MinIO backup..."
                pip install --quiet -r $BACKUP_REQUIREMENTS
                cp $BACKUP_REQUIREMENTS $REQUIREMENTS_FILE
                echo "✓ Packages restored from MinIO backup"
            fi
        fi
    fi
fi

# Save current requirements
pip freeze > $REQUIREMENTS_FILE

echo "========================================="
echo "Virtual environment setup complete!"
echo "Location: $VENV_PATH"
echo "Requirements: $REQUIREMENTS_FILE"
echo "========================================="
echo ""
echo "To activate manually: source $VENV_PATH/bin/activate"
echo "To install packages: pip install <package>"
echo "Your requirements.txt will be auto-updated!"
echo ""
