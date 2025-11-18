# =============================================================================
# PipeZone Platform - Bash Configuration Additions
# =============================================================================
# This file is appended to ~/.bashrc to configure the shell environment
# =============================================================================

# Colors for better terminal experience
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# Environment variables
export VENV_PATH="/home/coder/.venv"
export REQUIREMENTS_FILE="/home/coder/workspace/requirements.txt"
export PYTHONPATH="/home/coder/workspace:/shared/libraries:$PYTHONPATH"
export PATH="$VENV_PATH/bin:/home/coder/.local/bin:$PATH"

# PipeZone configuration
export PIPEZONE_HOME="/home/coder"
export PIPEZONE_WORKSPACE="/home/coder/workspace"
export PIPEZONE_SHARED="/home/coder/shared"

# Aliases
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias python='python3'
alias pip='pip3'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# PipeZone specific aliases
alias pipezone-status='docker ps --filter "name=pipezone"'
alias pipezone-logs='docker-compose logs -f'
alias nb='jupyter notebook'
alias lab='jupyter lab'

# Custom prompt with git branch
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export PS1='\[\033[01;32m\]\u@pipezone\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '

# Auto-activate virtual environment
if [ -d "$VENV_PATH" ]; then
    source $VENV_PATH/bin/activate
fi

# Custom pip wrapper to auto-update requirements.txt
pip() {
    # Call the real pip
    command pip "$@"

    # If the command was 'install' or 'uninstall', update requirements.txt
    if [[ "$1" == "install" ]] || [[ "$1" == "uninstall" ]]; then
        if [ -d "$VENV_PATH" ]; then
            echo "Updating requirements.txt..."
            command pip freeze > $REQUIREMENTS_FILE

            # Backup to MinIO if configured
            if command -v mc &> /dev/null; then
                if mc alias list | grep -q "minio"; then
                    mc cp $REQUIREMENTS_FILE minio/user-workspaces/$(whoami)/requirements.txt 2>/dev/null || true
                fi
            fi
        fi
    fi
}

# Function to show cluster info
pipezone-cluster() {
    echo "Current Cluster: ${SELECTED_CLUSTER:-medium_cluster}"
    echo "Spark Master: ${SPARK_MASTER_URL:-k8s://https://kubernetes.default.svc}"
    echo "MinIO Endpoint: ${MINIO_ENDPOINT:-minio:9000}"
    echo "Airflow URL: ${AIRFLOW_URL:-http://airflow-webserver:8080}"
}

# Function to switch cluster
pipezone-switch-cluster() {
    if [ -z "$1" ]; then
        echo "Usage: pipezone-switch-cluster <small_cluster|medium_cluster|large_cluster>"
        return 1
    fi

    export SELECTED_CLUSTER=$1
    echo "Switched to cluster: $1"
    echo "Restart your Spark session for this to take effect"
}

# Function to sync workspace to MinIO
pipezone-sync() {
    if command -v mc &> /dev/null; then
        if mc alias list | grep -q "minio"; then
            echo "Syncing workspace to MinIO..."
            mc mirror --overwrite $PIPEZONE_WORKSPACE minio/user-workspaces/$(whoami)/workspace/
            echo "Sync complete!"
        else
            echo "MinIO not configured. Run: pipezone-setup-minio"
        fi
    else
        echo "MinIO client (mc) not installed"
    fi
}

# Function to restore workspace from MinIO
pipezone-restore() {
    if command -v mc &> /dev/null; then
        if mc alias list | grep -q "minio"; then
            echo "Restoring workspace from MinIO..."
            mc mirror --overwrite minio/user-workspaces/$(whoami)/workspace/ $PIPEZONE_WORKSPACE
            echo "Restore complete!"
        else
            echo "MinIO not configured. Run: pipezone-setup-minio"
        fi
    else
        echo "MinIO client (mc) not installed"
    fi
}

# Function to setup MinIO client
pipezone-setup-minio() {
    if [ -z "$MINIO_ENDPOINT" ] || [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
        echo "Error: MinIO environment variables not set"
        echo "Required: MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY"
        return 1
    fi

    mc alias set minio http://$MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
    echo "MinIO client configured successfully!"
}

# Welcome message
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██████╗ ██╗██████╗ ███████╗███████╗ ██████╗ ███╗   ██╗███████╗ ║
║   ██╔══██╗██║██╔══██╗██╔════╝╚══███╔╝██╔═══██╗████╗  ██║██╔════╝ ║
║   ██████╔╝██║██████╔╝█████╗    ███╔╝ ██║   ██║██╔██╗ ██║█████╗   ║
║   ██╔═══╝ ██║██╔═══╝ ██╔══╝   ███╔╝  ██║   ██║██║╚██╗██║██╔══╝   ║
║   ██║     ██║██║     ███████╗███████╗╚██████╔╝██║ ╚████║███████╗ ║
║   ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ║
║                                                               ║
║              Self-Hosted Data Platform                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Welcome to PipeZone! 🚀

Quick Commands:
  pipezone-cluster          - Show current cluster configuration
  pipezone-switch-cluster   - Switch Spark cluster
  pipezone-sync             - Sync workspace to MinIO
  pipezone-restore          - Restore workspace from MinIO
  pipezone-status           - Show running services

Documentation: /home/coder/shared/docs/
Examples: /home/coder/shared/notebooks/examples/

Happy coding! 💻
EOF

# Initialize virtual environment if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
    echo "First time setup: Creating virtual environment..."
    /home/coder/scripts/setup_venv.sh
fi
