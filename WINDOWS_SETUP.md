# 🪟 PipeZone - Windows Setup Guide

Windows da PipeZone platformasini ishga tushirish uchun qo'llanma.

## 📋 Prerequisites (Talablar)

### 1. Docker Desktop for Windows

**Download va Install:**
1. [Docker Desktop](https://www.docker.com/products/docker-desktop/) dan yuklab oling
2. Install qiling va kompyuterni restart qiling
3. Docker Desktop ni ishga tushiring
4. Settings → Resources → Advanced da:
   - **Memory**: Kamida 8GB
   - **CPUs**: Kamida 4 cores
   - **Disk**: Kamida 50GB

**Docker tekshirish:**
```powershell
docker --version
docker-compose --version
```

### 2. Git for Windows (agar yo'q bo'lsa)

[Git for Windows](https://git-scm.com/download/win) dan yuklab oling va install qiling.

## 🚀 Quick Start

### 1️⃣ Repository Clone qiling

**PowerShell yoki CMD da:**
```powershell
cd C:\Users\YourUsername\Projects
git clone https://github.com/yourusername/pipezone.git
cd pipezone
```

### 2️⃣ Environment Setup

**PowerShell da:**
```powershell
# .env.example dan .env yaratish
Copy-Item .env.example .env

# .env ni tahrirlash (Notepad yoki VS Code bilan)
notepad .env
```

**yoki CMD da:**
```cmd
copy .env.example .env
notepad .env
```

**Majburiy o'zgartirish kerak:**
```bash
MYSQL_ROOT_PASSWORD=your_strong_password
MYSQL_PASSWORD=pipezone_password
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=minio_password
AIRFLOW_ADMIN_PASSWORD=airflow_password
AIRFLOW_DATABASE_PASSWORD=airflow_db_password
JUPYTER_TOKEN=jupyter_token
VAULT_TOKEN=vault_token
```

### 3️⃣ Platformani Ishga Tushirish

**3 xil usul:**

#### Option A: PowerShell Script (Tavsiya etiladi)

```powershell
# PowerShell ni Administrator sifatida oching
.\setup\scripts\start-all.ps1
```

#### Option B: CMD/Batch Script

```cmd
REM CMD ni Administrator sifatida oching
setup\scripts\start-all.bat
```

#### Option C: Manual (Docker Compose bilan)

```powershell
cd setup\docker

# 1. Infrastructure
docker-compose -f docker-compose.infra.yml up -d

# 2. Airflow (15 sekund kutish kerak)
Start-Sleep -Seconds 15
docker-compose -f docker-compose.airflow.yml up -d

# 3. Jupyter + Spark (20 sekund kutish kerak)
Start-Sleep -Seconds 20
docker-compose -f docker-compose.notebooks.yml up -d
```

### 4️⃣ Platformaga Kirish

Browser da quyidagi manzillarni oching:

| Service | URL | Login | Parol |
|---------|-----|-------|-------|
| **Airflow** | http://localhost:8080 | admin | `.env` dagi parol |
| **MinIO** | http://localhost:9001 | `.env` dagi username | `.env` dagi parol |
| **Jupyter** | http://localhost:8888 | - | `.env` dagi token |
| **Vault** | http://localhost:8200 | - | `.env` dagi token |
| **Spark** | http://localhost:8081 | - | - |

## 🛑 Platformani To'xtatish

**PowerShell:**
```powershell
.\setup\scripts\stop-all.ps1
```

**CMD:**
```cmd
setup\scripts\stop-all.bat
```

**Manual:**
```powershell
cd setup\docker
docker-compose -f docker-compose.notebooks.yml down
docker-compose -f docker-compose.airflow.yml down
docker-compose -f docker-compose.infra.yml down
```

## 📝 Database Connection Qo'shish

### PostgreSQL Source Ulash

**.env ga qo'shing:**
```bash
POSTGRES_SOURCE_HOST=192.168.1.100
POSTGRES_SOURCE_PORT=5432
POSTGRES_SOURCE_DATABASE=mydb
POSTGRES_SOURCE_USER=readonly
POSTGRES_SOURCE_PASSWORD=mypassword
```

**Connection file yarating** - `metadata\connections\my_postgres.yml`:
```yaml
name: my_postgres
type: postgresql
description: Production PostgreSQL database

connection:
  host: ${POSTGRES_SOURCE_HOST}
  port: ${POSTGRES_SOURCE_PORT}
  database: ${POSTGRES_SOURCE_DATABASE}
  username: ${POSTGRES_SOURCE_USER}
  password: ${POSTGRES_SOURCE_PASSWORD}
```

### MySQL Source Ulash

**.env ga qo'shing:**
```bash
MYSQL_SOURCE_HOST=mysql.company.com
MYSQL_SOURCE_PORT=3306
MYSQL_SOURCE_DATABASE=ecommerce
MYSQL_SOURCE_USER=etl_user
MYSQL_SOURCE_PASSWORD=mysql_password
```

**Connection file** - `metadata\connections\my_mysql.yml`:
```yaml
name: my_mysql
type: mysql
description: MySQL ecommerce database

connection:
  host: ${MYSQL_SOURCE_HOST}
  port: ${MYSQL_SOURCE_PORT}
  database: ${MYSQL_SOURCE_DATABASE}
  username: ${MYSQL_SOURCE_USER}
  password: ${MYSQL_SOURCE_PASSWORD}
```

## 📊 Pipeline Yaratish

### Flow File - `metadata\flows\extract_users.yml`

```yaml
name: extract_users
description: Extract users from PostgreSQL to MinIO

source:
  connection: my_postgres
  type: table
  table:
    schema: public
    name: users
  incremental:
    enabled: true
    column: updated_at

target:
  connection: minio_raw
  type: object_storage
  path: postgres/users/
  format: parquet
  partition_by:
    - year
    - month
  write_mode: append

data_quality:
  enabled: true
  checks:
    - name: unique_id
      type: unique
      columns: [id]

schedule:
  enabled: true
  cron: "0 */6 * * *"
  timezone: Asia/Tashkent
```

### Pipeline Run qilish

**Airflow orqali:**
1. http://localhost:8080 ga kiring
2. DAG `pipezone_extract_users` ni toping
3. Enable va Trigger qiling

**Jupyter orqali:**
1. http://localhost:8888 ga kiring
2. New → Python 3 Notebook
3. Code yozing:

```python
import sys
sys.path.insert(0, '/home/pipezone/utils')

from flow_executor import FlowExecutor

executor = FlowExecutor()
result = executor.execute_flow('extract_users')

print(f"Status: {result['status']}")
print(f"Records: {result['records_written']}")
```

## 🔍 Monitoring va Logs

### Docker Logs Ko'rish

**PowerShell:**
```powershell
# Barcha containerlarni ko'rish
docker ps

# Infrastructure logs
docker-compose -f setup\docker\docker-compose.infra.yml logs -f

# Airflow logs
docker-compose -f setup\docker\docker-compose.airflow.yml logs -f airflow-scheduler

# Jupyter logs
docker-compose -f setup\docker\docker-compose.notebooks.yml logs -f jupyter
```

### MySQL Metadata Ko'rish

**PowerShell:**
```powershell
docker exec -it pipezone_mysql mysql -u pipezone -p
```

Parol: `.env` dagi `MYSQL_PASSWORD`

```sql
USE pipezone_metadata;

-- Execution logs
SELECT * FROM pipeline_execution_logs
ORDER BY start_time DESC LIMIT 10;

-- Incremental state
SELECT * FROM incremental_state;
```

### MinIO Buckets Ko'rish

1. http://localhost:9001 ga kiring
2. Login: `.env` dagi `MINIO_ROOT_USER` va `MINIO_ROOT_PASSWORD`
3. Buckets → raw/bronze/silver/gold

## 🔧 Troubleshooting

### Docker Desktop ishlamayapti

1. Docker Desktop ni restart qiling
2. Windows Task Manager → Services → Docker Desktop Service → Restart
3. Agar ishlamasa, kompyuterni restart qiling

### Port band

Agar port band bo'lsa, `.env` da portlarni o'zgartiring:

```bash
AIRFLOW_WEBSERVER_PORT=8081  # default: 8080
JUPYTER_PORT=8889             # default: 8888
MINIO_CONSOLE_PORT=9002       # default: 9001
```

### Container ishga tushmayapti

```powershell
# Barcha containerlarni to'xtatish va o'chirish
docker-compose -f setup\docker\docker-compose.infra.yml down
docker-compose -f setup\docker\docker-compose.airflow.yml down
docker-compose -f setup\docker\docker-compose.notebooks.yml down

# Docker volumelarni tozalash (DIQQAT: data o'chadi!)
docker volume prune

# Qayta ishga tushirish
.\setup\scripts\start-all.ps1
```

### Permission denied errors

PowerShell yoki CMD ni **Administrator** sifatida oching:
1. Windows tugmasini bosing
2. "PowerShell" yoki "CMD" ni qidiring
3. Right-click → Run as administrator

### WSL errors

Agar WSL error chiqsa:
1. Docker Desktop → Settings → General
2. "Use the WSL 2 based engine" ni tekshiring
3. Apply & Restart

## 📂 Windows Paths

Windows da file pathlar:

```powershell
# Project root
C:\Users\YourUsername\Projects\pipezone

# Metadata
C:\Users\YourUsername\Projects\pipezone\metadata\connections
C:\Users\YourUsername\Projects\pipezone\metadata\flows

# Scripts
C:\Users\YourUsername\Projects\pipezone\setup\scripts

# Logs
C:\Users\YourUsername\Projects\pipezone\schedule\airflow\logs
```

## 💡 Tips

### 1. VS Code ishlatish

VS Code da ochish:
```powershell
cd pipezone
code .
```

### 2. Git Bash ishlatish

Git Bash da bash scriptlarni ishlatish mumkin:
```bash
bash setup/scripts/start-all.sh
```

### 3. Docker Desktop Memory

Agar slow ishlasa, Docker Desktop → Settings → Resources da RAM ko'paytiring (8GB → 12GB).

### 4. Windows Defender

Docker volumelar uchun Windows Defender exceptionga qo'shing:
- Settings → Windows Security → Virus & threat protection
- Exclusions → Add folder
- `C:\Users\YourUsername\Projects\pipezone\data` ni qo'shing

## 🚀 Production Deploy

Production uchun Windows Server da:

1. Windows Server 2019+ yoki Windows 10/11 Pro
2. Docker Desktop Enterprise yoki Docker Engine
3. Firewall rules qo'shish
4. SSL/TLS setup
5. Backup strategy

**Security checklist:**
- [ ] `.env` faylni secure joyda saqlash
- [ ] Strong passwordlar ishlatish
- [ ] Firewall configure qilish
- [ ] Regular backuplar
- [ ] Vault ishlatib secretlar saqlash

## 📚 Qo'shimcha Resurslar

- [Docker Desktop Documentation](https://docs.docker.com/desktop/windows/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- `README.md` - To'liq dokumentatsiya
- `QUICK_START.md` - O'zbek tilida qo'llanma
- `.env.example` - Environment template

---

**Muammolar bo'lsa?** GitHub da issue oching yoki README.md ga qarang.

**Muvaffaqiyatlar!** 🚀
