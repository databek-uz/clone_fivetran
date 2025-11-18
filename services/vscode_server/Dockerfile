# =============================================================================
# VS Code Server Dockerfile for PipeZone Platform
# =============================================================================
# This container provides a fully-configured VS Code Server environment with:
# - Pre-installed Python, Jupyter, and Spark extensions
# - Persistent virtual environment for library installations
# - Custom home page with service access
# - Integration with MinIO, Airflow, and Spark
# =============================================================================

FROM codercom/code-server:latest

# Metadata
LABEL maintainer="PipeZone Team"
LABEL description="VS Code Server for PipeZone Platform"
LABEL version="1.0.0"

# Switch to root for installation
USER root

# =============================================================================
# Install System Dependencies
# =============================================================================
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    gcc \
    g++ \
    make \
    # Python development
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    # Database clients
    postgresql-client \
    default-mysql-client \
    # Utilities
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    jq \
    # MinIO client
    && curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc \
    && chmod +x /usr/local/bin/mc \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Set Python 3.11 as default
# =============================================================================
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# =============================================================================
# Install Python Base Libraries
# =============================================================================
COPY config/requirements_base.txt /tmp/requirements_base.txt
RUN pip install --no-cache-dir --break-system-packages --upgrade pip setuptools wheel pip-tools \
    && pip install --no-cache-dir --break-system-packages -r /tmp/requirements_base.txt \
    && rm /tmp/requirements_base.txt

# =============================================================================
# Install VS Code Extensions
# =============================================================================
COPY config/extensions.txt /tmp/extensions.txt
RUN sed -i 's/\r$//' /tmp/extensions.txt \
    && while IFS= read -r ext || [ -n "$ext" ]; do \
        if [ -n "$ext" ]; then \
            echo "Installing extension: $ext"; \
            code-server --install-extension "$ext" || echo "Failed to install $ext"; \
        fi \
    done < /tmp/extensions.txt \
    && rm /tmp/extensions.txt

# =============================================================================
# Configure VS Code Settings
# =============================================================================
RUN mkdir -p /home/coder/.local/share/code-server/User
COPY config/settings.json /home/coder/.local/share/code-server/User/settings.json

# =============================================================================
# Copy Custom Home Page
# =============================================================================
COPY home_page /home/coder/home_page

# =============================================================================
# Copy Setup Scripts
# =============================================================================
COPY scripts /home/coder/scripts
RUN chmod +x /home/coder/scripts/*.sh

# =============================================================================
# Configure Bash Environment
# =============================================================================
COPY config/bashrc_additions.sh /tmp/bashrc_additions.sh
RUN cat /tmp/bashrc_additions.sh >> /home/coder/.bashrc \
    && rm /tmp/bashrc_additions.sh

# =============================================================================
# Create Required Directories
# =============================================================================
RUN mkdir -p \
    /home/coder/workspace \
    /home/coder/shared \
    /home/coder/reviews \
    /home/coder/.venv \
    /home/coder/.cache \
    /home/coder/.config \
    /home/coder/.jupyter \
    /home/coder/.mc

# =============================================================================
# Set Ownership
# =============================================================================
RUN chown -R coder:coder /home/coder

# Switch back to coder user
USER coder

# =============================================================================
# Working Directory
# =============================================================================
WORKDIR /home/coder/workspace

# =============================================================================
# Environment Variables
# =============================================================================
ENV PYTHONPATH=/home/coder/workspace:/shared/libraries:$PYTHONPATH
ENV PATH=/home/coder/.venv/bin:/home/coder/.local/bin:$PATH
ENV SHELL=/bin/bash

# =============================================================================
# Health Check
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

# =============================================================================
# Startup Command
# =============================================================================
# The startup script will:
# 1. Initialize virtual environment if not exists
# 2. Configure MinIO client
# 3. Restore user's requirements.txt from MinIO
# 4. Start code-server
# =============================================================================
COPY scripts/entrypoint.sh /home/coder/entrypoint.sh
USER root
RUN chmod +x /home/coder/entrypoint.sh
USER coder

ENTRYPOINT ["/home/coder/entrypoint.sh"]
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password", "/home/coder/workspace"]
