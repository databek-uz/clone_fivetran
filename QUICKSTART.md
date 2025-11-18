# 🚀 PipeZone - Quick Start Guide

## 📋 Prerequisites

- **Docker Desktop** 20.10+ (Windows/Mac) or **Docker** + **Docker Compose** (Linux)
- **Python 3.11+** (for password hashing)
- **Git** (optional, for version control)
- **8GB+ RAM** available
- **50GB+ disk** space

---

## 🪟 Windows Installation

### 1. Install Docker Desktop

Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)

### 2. Install Python

Download and install [Python 3.11+](https://www.python.org/downloads/)

During installation, check "Add Python to PATH"

### 3. Install required Python packages

```powershell
pip install bcrypt cryptography
```

### 4. Clone the repository

```powershell
git clone https://github.com/databek-uz/pipezone.git
cd pipezone
```

### 5. Create environment configuration

```powershell
Copy-Item .env.example .env
# Edit .env with your favorite text editor (notepad, VS Code, etc.)
notepad .env
```

**Important**: Update these passwords in `.env`:

- `MINIO_ROOT_PASSWORD`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `AIRFLOW_ADMIN_PASSWORD`
- `VSCODE_PASSWORD`

### 6. Start the platform

```powershell
.\scripts\start_platform.ps1
```

### 7. Create your first user

```powershell
.\services\auth\create_user.ps1 john mypassword123
```

### 8. Start VS Code Server for the user

```powershell
docker-compose -f docker-compose.yml -f docker-compose.john.yml up -d
```

### 9. Access the platform

- **VS Code Server**: http://localhost:8081 (or the port shown in terminal)
- **Airflow**: http://localhost:8081 (admin / admin123)
- **MinIO Console**: http://localhost:9001 (admin / changeme123)
- **Grafana**: http://localhost:3000 (admin / admin123)
- **Spark History**: http://localhost:18080

### 10. Stop the platform

```powershell
.\scripts\stop_platform.ps1
```

---

## 🐧 Linux Installation

### 1. Install Docker and Docker Compose

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose python3 python3-pip git

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (logout/login required)
sudo usermod -aG docker $USER
```

### 2. Install required Python packages

```bash
pip3 install bcrypt cryptography
```

### 3. Clone the repository

```bash
git clone https://github.com/databek-uz/pipezone.git
cd pipezone
```

### 4. Create environment configuration

```bash
cp .env.example .env
# Edit .env with your favorite editor
nano .env
# or
vim .env
```

**Important**: Update these passwords in `.env`:

- `MINIO_ROOT_PASSWORD`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `AIRFLOW_ADMIN_PASSWORD`
- `VSCODE_PASSWORD`

### 5. Start the platform

```bash
chmod +x scripts/*.sh services/auth/*.sh
./scripts/start_platform.sh
```

### 6. Create your first user

```bash
./services/auth/create_user.sh john mypassword123
```

### 7. Start VS Code Server for the user

```bash
docker-compose -f docker-compose.yml -f docker-compose.john.yml up -d
```

### 8. Access the platform

- **VS Code Server**: http://localhost:8081 (or the port shown in terminal)
- **Airflow**: http://localhost:8081 (admin / admin123)
- **MinIO Console**: http://localhost:9001 (admin / changeme123)
- **Grafana**: http://localhost:3000 (admin / admin123)
- **Spark History**: http://localhost:18080

### 9. Stop the platform

```bash
./scripts/stop_platform.sh
```

---

## 🍎 macOS Installation

### 1. Install Docker Desktop

Download and install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)

### 2. Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install Python and Git

```bash
brew install python@3.11 git
```

### 4. Install required Python packages

```bash
pip3 install bcrypt cryptography
```

### 5. Clone the repository

```bash
git clone https://github.com/databek-uz/pipezone.git
cd pipezone
```

### 6. Create environment configuration

```bash
cp .env.example .env
# Edit .env with your favorite editor
nano .env
```

**Important**: Update these passwords in `.env`:

- `MINIO_ROOT_PASSWORD`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `AIRFLOW_ADMIN_PASSWORD`
- `VSCODE_PASSWORD`

### 7. Start the platform

```bash
chmod +x scripts/*.sh services/auth/*.sh
./scripts/start_platform.sh
```

### 8. Create your first user

```bash
./services/auth/create_user.sh john mypassword123
```

### 9. Start VS Code Server for the user

```bash
docker-compose -f docker-compose.yml -f docker-compose.john.yml up -d
```

### 10. Access the platform

- **VS Code Server**: http://localhost:8081 (or the port shown in terminal)
- **Airflow**: http://localhost:8081 (admin / admin123)
- **MinIO Console**: http://localhost:9001 (admin / changeme123)
- **Grafana**: http://localhost:3000 (admin / admin123)
- **Spark History**: http://localhost:18080

### 11. Stop the platform

```bash
./scripts/stop_platform.sh
```

---

## 🔧 Common Commands

### View logs

**Windows:**

```powershell
docker-compose logs -f
```

**Linux/macOS:**

```bash
docker-compose logs -f
```

### View specific service logs

**Windows:**

```powershell
docker-compose logs -f airflow-webserver
```

**Linux/macOS:**

```bash
docker-compose logs -f airflow-webserver
```

### Restart a service

**Windows:**

```powershell
docker-compose restart airflow-webserver
```

**Linux/macOS:**

```bash
docker-compose restart airflow-webserver
```

### Check running containers

**Windows:**

```powershell
docker ps
```

**Linux/macOS:**

```bash
docker ps
```

### Remove all data (⚠️ WARNING - This deletes everything!)

**Windows:**

```powershell
docker-compose down -v
Remove-Item -Recurse -Force data, workspaces, .airflow_initialized
```

**Linux/macOS:**

```bash
docker-compose down -v
rm -rf data/ workspaces/ .airflow_initialized
```

### 💾 Data Persistence

**Your data is safe!** The platform uses Docker volumes and local directories to persist all data:

✅ **Preserved on restart:**

- ✅ Airflow database (DAGs, task history, connections)
- ✅ User workspaces and notebooks
- ✅ MinIO buckets and uploaded files
- ✅ PostgreSQL data
- ✅ Grafana dashboards and settings
- ✅ Prometheus metrics history

**How it works:**

- First run: Creates `.airflow_initialized` marker file and initializes database
- Subsequent runs: Skips initialization, only runs migrations to keep DB updated
- Your data stays in `data/`, `workspaces/`, and Docker volumes

**To reset everything:**
Delete the marker file and volumes as shown in "Remove all data" section above.

### ⚙️ Performance Tuning

**Airflow Worker Count** - Control how many tasks run in parallel:

Edit `.env` file:

```env
# Options: 1 (light), 2 (balanced), 3 (heavy)
AIRFLOW_WORKER_COUNT=1
```

**Recommendations:**

- 💻 **Development / 8GB RAM**: `AIRFLOW_WORKER_COUNT=1` (uses ~4GB total)
- 🖥️ **Production / 16GB RAM**: `AIRFLOW_WORKER_COUNT=2` (uses ~6GB total)
- 🚀 **Heavy Load / 32GB RAM**: `AIRFLOW_WORKER_COUNT=3` (uses ~8GB total)

**Impact:**

- More workers = More parallel tasks but higher RAM usage
- Each worker uses ~1.5-2GB RAM
- Scripts automatically start only the number of workers you specify

---

## 🎯 First Steps

1. **Open VS Code Server** at http://localhost:8081
2. **Create your first notebook**:
   - Click "New Notebook" in the dashboard
   - Or create a file in `workspace/notebooks/my_first_notebook.ipynb`
3. **Try a simple Spark example**:

   ```python
   # Spark is auto-configured!
   df = spark.createDataFrame([
       ("Alice", 25),
       ("Bob", 30),
       ("Charlie", 35)
   ], ["name", "age"])

   df.show()
   ```

4. **Schedule your notebook**:
   - Open Airflow UI at http://localhost:8081
   - Use the DAG generator script or UI
5. **Explore shared notebooks**:
   - Check `/shared/notebooks/examples/`

---

## ❓ Troubleshooting

### Docker not starting

- **Windows**: Make sure Docker Desktop is running
- **Linux**: Check `sudo systemctl status docker`
- **macOS**: Make sure Docker Desktop is running

### Port already in use

- Change the port in `.env` file
- Or stop the conflicting service

### Permission denied (Linux)

```bash
sudo chmod +x scripts/*.sh services/auth/*.sh
```

### Python not found

- Make sure Python is installed and in PATH
- Windows: Reinstall Python with "Add to PATH" checked
- Linux: `sudo apt install python3 python3-pip`
- macOS: `brew install python@3.11`

### bcrypt module not found

```bash
pip install bcrypt cryptography
```

---

## 📚 Next Steps

- Read the [User Guide](docs/USER_GUIDE.md)
- Explore [Example Notebooks](shared/notebooks/examples/)
- Check [API Reference](docs/API_REFERENCE.md)
- Join our community discussions

---

**Happy data engineering! 🚀**
