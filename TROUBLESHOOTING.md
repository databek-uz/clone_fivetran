# 🔧 Troubleshooting Guide - PipeZone

Windows va Linux da uchraydigan muammolar va yechimlar.

## ✅ Error Hal Qilindi

### ❌ Error: "service depends on undefined service mysql"

**Muammo:**
```
service "airflow-init" depends on undefined service "mysql": invalid compose project
```

**Sabab:**
- Airflow docker-compose.yml MySQL servicega depend qilmoqchi
- MySQL boshqa file (docker-compose.infra.yml) da joylashgan
- Docker Compose turli filelardagi servicelar o'rtasida dependency qo'llab-quvvatlamaydi

**Yechim:** ✅ HAL QILINDI
1. `version` field o'chirildi (obsolete warning)
2. `depends_on: mysql` o'chirildi
3. Network birinchi yaratiladi
4. Health check scriptlarda amalga oshiriladi

**Endi ishlaydi:**
```powershell
# Network avtomatik yaratiladi
.\setup\scripts\start-all.ps1
```

---

## 🪟 Windows Muammolar

### 1. Docker Desktop ishlamayapti

**Belgilar:**
- `docker: command not found`
- `Cannot connect to Docker daemon`

**Yechim:**
```powershell
# Docker Desktop ishga tushiring
# Start menu → Docker Desktop

# Statusni tekshiring
docker ps

# Agar ishlamasa - restart qiling
# Settings → Restart Docker Desktop
```

### 2. Port band

**Error:**
```
Error response from daemon: Ports are not available: exposing port TCP 0.0.0.0:8080
```

**Yechim:**

**.env da portni o'zgartiring:**
```bash
# Default
AIRFLOW_WEBSERVER_PORT=8080

# O'zgartirish
AIRFLOW_WEBSERVER_PORT=8081
```

**Qaysi port band ekanini tekshirish:**
```powershell
# PowerShell
netstat -ano | findstr :8080

# Processni to'xtatish (PID bilan)
taskkill /PID <process_id> /F
```

### 3. WSL Error

**Error:**
```
ERROR: CreateProcessCommon:735: execvpe(/bin/bash) failed
```

**Yechim:**
✅ PowerShell yoki CMD scriptlarni ishlating:
```powershell
# Bash o'rniga
.\setup\scripts\start-all.ps1

# yoki
setup\scripts\start-all.bat
```

### 4. Permission Denied

**Error:**
```
PermissionError: [Errno 13] Permission denied
```

**Yechim:**
```powershell
# PowerShell ni Administrator sifatida oching
# Windows tugmasi → PowerShell → Right-click → Run as administrator

.\setup\scripts\start-all.ps1
```

### 5. .env file topilmayapti

**Error:**
```
Error: .env file not found!
```

**Yechim:**
```powershell
# Project root ga o'ting
cd C:\Users\YourName\Projects\pipezone

# .env yarating
Copy-Item .env.example .env

# Tahrirlang
notepad .env
```

### 6. Docker volumes yo'q

**Error:**
```
Error response from daemon: invalid mount config
```

**Yechim:**
```powershell
# data folderlarni yarating
New-Item -ItemType Directory -Force -Path data\mysql
New-Item -ItemType Directory -Force -Path data\minio
New-Item -ItemType Directory -Force -Path data\vault
New-Item -ItemType Directory -Force -Path data\notebooks
```

---

## 🐧 Linux/Mac Muammolar

### 1. Permission denied (bash script)

**Error:**
```
bash: ./setup/scripts/start-all.sh: Permission denied
```

**Yechim:**
```bash
# Executable qiling
chmod +x setup/scripts/start-all.sh
chmod +x setup/scripts/stop-all.sh

# Ishga tushiring
bash setup/scripts/start-all.sh
```

### 2. Port band (Linux)

**Tekshirish:**
```bash
# Port band ekanini tekshiring
sudo lsof -i :8080

# Processni to'xtatish
sudo kill -9 <PID>
```

### 3. Docker daemon ishlamayapti

**Yechim:**
```bash
# Ubuntu/Debian
sudo systemctl start docker
sudo systemctl enable docker

# Status
sudo systemctl status docker
```

---

## 🐳 Docker Muammolar

### 1. Container ishlamayapti

**Tekshirish:**
```bash
# Barcha containerlarni ko'rish
docker ps -a

# Loglarni ko'rish
docker logs pipezone_mysql
docker logs pipezone_airflow_webserver
docker logs pipezone_jupyter
```

**Restart:**
```bash
# Bitta containerni restart
docker restart pipezone_mysql

# Barchasini restart
cd setup/docker
docker-compose -f docker-compose.infra.yml restart
```

### 2. Network muammolari

**Tekshirish:**
```bash
# Network borligini tekshirish
docker network ls | grep pipezone

# Network inspect
docker network inspect pipezone_network

# Network yaratish (agar yo'q bo'lsa)
docker network create pipezone_network
```

### 3. Volume muammolari

**Tozalash (DIQQAT: Ma'lumotlar o'chadi!):**
```bash
# Barcha servicelarni to'xtatish
bash setup/scripts/stop-all.sh

# Volumelarni o'chirish
docker volume prune -f

# Qayta ishga tushirish
bash setup/scripts/start-all.sh
```

### 4. Image pull muammolari

**Error:**
```
Error response from daemon: Get https://registry-1.docker.io/v2/: net/http: TLS handshake timeout
```

**Yechim:**
```bash
# Internetni tekshiring
ping google.com

# Docker daemon restart
sudo systemctl restart docker

# Proxy ishlatish (agar kerak bo'lsa)
# ~/.docker/config.json ga qo'shing:
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.example.com:8080",
      "httpsProxy": "http://proxy.example.com:8080"
    }
  }
}
```

---

## 🗄️ MySQL Muammolar

### 1. Connection refused

**Error:**
```
Can't connect to MySQL server on 'mysql' (111)
```

**Yechim:**
```bash
# MySQL tayyor ekanini tekshiring
docker exec pipezone_mysql mysqladmin ping -h localhost -u root -p

# Parol: .env dagi MYSQL_ROOT_PASSWORD

# Loglarni tekshiring
docker logs pipezone_mysql
```

### 2. Access denied

**Error:**
```
Access denied for user 'pipezone'@'%'
```

**Yechim:**
```bash
# Root orqali kiring
docker exec -it pipezone_mysql mysql -u root -p

# User permissions tekshiring
SHOW GRANTS FOR 'pipezone'@'%';

# Agar kerak bo'lsa, permission bering
GRANT ALL PRIVILEGES ON pipezone_metadata.* TO 'pipezone'@'%';
FLUSH PRIVILEGES;
```

### 3. Database yo'q

**Error:**
```
Unknown database 'pipezone_metadata'
```

**Yechim:**
```bash
# Database yarating
docker exec -it pipezone_mysql mysql -u root -p

CREATE DATABASE IF NOT EXISTS pipezone_metadata;
CREATE DATABASE IF NOT EXISTS airflow;
```

---

## ✈️ Airflow Muammolar

### 1. DAG ko'rinmayapti

**Tekshirish:**
```bash
# Airflow scheduler loglarini ko'ring
docker logs pipezone_airflow_scheduler -f

# DAG folder tekshiring
docker exec pipezone_airflow_scheduler ls -la /opt/airflow/dags

# Metadata folder tekshiring
docker exec pipezone_airflow_scheduler ls -la /opt/pipezone/metadata/flows
```

**Yechim:**
```bash
# Scheduler restart
docker restart pipezone_airflow_scheduler

# Airflow DAGlarni reload qilish
docker exec pipezone_airflow_scheduler airflow dags reserialize
```

### 2. Webserver ishlamayapti

**Tekshirish:**
```bash
# Webserver logs
docker logs pipezone_airflow_webserver -f

# Health check
curl http://localhost:8080/health
```

**Yechim:**
```bash
# Restart
docker restart pipezone_airflow_webserver

# Agar ishlamasa, qayta yaratish
docker-compose -f setup/docker/docker-compose.airflow.yml up -d --force-recreate airflow-webserver
```

### 3. Database initialization failed

**Error:**
```
airflow.exceptions.AirflowException: Can not migrate database
```

**Yechim:**
```bash
# Airflow init qayta ishga tushirish
docker-compose -f setup/docker/docker-compose.airflow.yml up airflow-init

# Agar ishlamasa, databaseni reset qiling (DIQQAT!)
docker exec -it pipezone_mysql mysql -u root -p
DROP DATABASE airflow;
CREATE DATABASE airflow;
```

---

## 📓 Jupyter/Spark Muammolar

### 1. Jupyter token xato

**Error:**
```
Invalid credentials
```

**Yechim:**
```bash
# Token olish
docker exec pipezone_jupyter jupyter notebook list

# yoki .env dan
cat .env | grep JUPYTER_TOKEN
```

### 2. Spark connection failed

**Error:**
```
Py4JNetworkError: An error occurred while trying to connect to the Java server
```

**Yechim:**
```bash
# Spark master statusini tekshiring
curl http://localhost:8081

# Spark worker statusini tekshiring
docker logs pipezone_spark_worker

# Restart
docker restart pipezone_spark_master
docker restart pipezone_spark_worker
```

### 3. Kernel died

**Error:**
```
The kernel appears to have died. It will restart automatically.
```

**Yechim:**
```bash
# Memory ko'paytiring
# Docker Desktop → Settings → Resources → Memory: 8GB+

# Jupyter restart
docker restart pipezone_jupyter
```

---

## 📦 MinIO Muammolar

### 1. Bucket yaratilmagan

**Tekshirish:**
```bash
# MinIO logs
docker logs pipezone_minio

# mc client orqali tekshirish
docker exec pipezone_minio mc ls local/
```

**Yechim:**
```bash
# Manual bucket yaratish
docker exec pipezone_minio mc mb local/raw
docker exec pipezone_minio mc mb local/bronze
docker exec pipezone_minio mc mb local/silver
docker exec pipezone_minio mc mb local/gold
```

### 2. Access denied

**Error:**
```
Access Denied
```

**Yechim:**
```bash
# .env da credentials tekshiring
cat .env | grep MINIO

# MinIO Console orqali login qiling
# http://localhost:9001
# Username: .env dagi MINIO_ROOT_USER
# Password: .env dagi MINIO_ROOT_PASSWORD
```

---

## 🔍 Diagnostics

### To'liq diagnostic script

**PowerShell:**
```powershell
# System info
Write-Host "=== System Info ==="
docker --version
docker-compose --version
docker ps

Write-Host "`n=== Networks ==="
docker network ls

Write-Host "`n=== Volumes ==="
docker volume ls

Write-Host "`n=== Container Health ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

Write-Host "`n=== Logs (last 10 lines) ==="
docker logs pipezone_mysql --tail 10
docker logs pipezone_airflow_webserver --tail 10
docker logs pipezone_jupyter --tail 10
```

**Bash:**
```bash
#!/bin/bash
echo "=== System Info ==="
docker --version
docker-compose --version
docker ps

echo -e "\n=== Networks ==="
docker network ls

echo -e "\n=== Volumes ==="
docker volume ls

echo -e "\n=== Container Health ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n=== Logs (last 10 lines) ==="
docker logs pipezone_mysql --tail 10
docker logs pipezone_airflow_webserver --tail 10
docker logs pipezone_jupyter --tail 10
```

---

## 🆘 Oxirgi Chora

Agar hech narsa ishlamasa:

### 1. To'liq Reset (Barcha datani o'chiradi!)

```bash
# Barcha containerlarni to'xtatish
bash setup/scripts/stop-all.sh  # Linux/Mac
.\setup\scripts\stop-all.ps1    # Windows

# Containerlar, volumelar, networkni o'chirish
docker-compose -f setup/docker/docker-compose.notebooks.yml down -v
docker-compose -f setup/docker/docker-compose.airflow.yml down -v
docker-compose -f setup/docker/docker-compose.infra.yml down -v

# Networkni o'chirish
docker network rm pipezone_network

# data folderini tozalash (DIQQAT!)
rm -rf data/*  # Linux/Mac
Remove-Item -Recurse -Force data\*  # Windows

# Qayta ishga tushirish
bash setup/scripts/start-all.sh  # Linux/Mac
.\setup\scripts\start-all.ps1    # Windows
```

### 2. Clean slate

```bash
# Barcha Docker resourcelarni o'chirish (DIQQAT!)
docker system prune -a --volumes

# Docker restart
sudo systemctl restart docker  # Linux
# Docker Desktop restart        # Windows/Mac

# Repositoryni qayta clone qilish
cd ..
rm -rf pipezone
git clone <repo-url>
cd pipezone
cp .env.example .env
# .env ni configure qiling
bash setup/scripts/start-all.sh
```

---

## 📞 Yordam

Agar muammo hal qilinmasa:

1. **GitHub Issue oching:** Issues tabda muammoni describe qiling
2. **Loglarni attach qiling:** Docker logs, error messages
3. **System info bering:** OS, Docker version, RAM, etc.

**Diagnostics to'plash:**
```bash
# Diagnostics export qilish
docker ps -a > diagnostic.txt
docker logs pipezone_mysql >> diagnostic.txt
docker logs pipezone_airflow_webserver >> diagnostic.txt
cat .env.example >> diagnostic.txt  # .env ni HECH QACHON share qilmang!
```

---

**Muvaffaqiyatlar!** 🚀
