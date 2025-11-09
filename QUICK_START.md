# ⚡ PipeZone - Quick Start Guide

O'zbek tilida tezkor boshlash uchun qo'llanma.

## 📋 Tezkor Sozlash

### 1️⃣ Environment Setup

```bash
# .env.example dan .env yarating
cp .env.example .env

# .env faylni tahrirlang
nano .env
```

### Majburiy o'zgartirish kerak bo'lgan qiymatlar:

```bash
# MySQL parollari
MYSQL_ROOT_PASSWORD=kuchli_parol_123
MYSQL_PASSWORD=pipezone_parol_456

# MinIO (Object Storage) uchun
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=minio_parol_789

# Airflow admin
AIRFLOW_ADMIN_PASSWORD=airflow_parol_012
AIRFLOW_DATABASE_PASSWORD=airflow_db_parol_345

# Jupyter Notebook
JUPYTER_TOKEN=jupyter_token_678

# Vault (Secrets)
VAULT_TOKEN=vault_token_901
```

### 2️⃣ Platformani Ishga Tushirish

```bash
# Barcha servicelarni ishga tushirish
bash setup/scripts/start-all.sh

# Platformani to'xtatish
bash setup/scripts/stop-all.sh
```

### 3️⃣ Kirish Manzillari

| Service | URL | Login | Parol |
|---------|-----|-------|-------|
| **Airflow** | http://localhost:8080 | admin | `.env` dagi `AIRFLOW_ADMIN_PASSWORD` |
| **MinIO** | http://localhost:9001 | `.env` dagi `MINIO_ROOT_USER` | `.env` dagi `MINIO_ROOT_PASSWORD` |
| **Jupyter** | http://localhost:8888 | - | `.env` dagi `JUPYTER_TOKEN` |
| **Vault** | http://localhost:8200 | - | `.env` dagi `VAULT_TOKEN` |
| **Spark** | http://localhost:8081 | - | - |

## 🔌 O'z Ma'lumotlar Bazangizni Ulash

### PostgreSQL Ulash

**.env faylga qo'shing:**

```bash
POSTGRES_SOURCE_HOST=192.168.1.100
POSTGRES_SOURCE_PORT=5432
POSTGRES_SOURCE_DATABASE=production_db
POSTGRES_SOURCE_USER=readonly_user
POSTGRES_SOURCE_PASSWORD=secure_password_here
```

**Connection file yarating** - `metadata/connections/my_postgres.yml`:

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

vault:
  enabled: true
  path: secret/data/postgres/production
  keys:
    username: username
    password: password

metadata:
  owner: data_engineering
  tags:
    - production
    - postgresql
```

### MySQL Ulash

**.env ga qo'shing:**

```bash
MYSQL_SOURCE_HOST=mysql.company.com
MYSQL_SOURCE_PORT=3306
MYSQL_SOURCE_DATABASE=ecommerce
MYSQL_SOURCE_USER=etl_user
MYSQL_SOURCE_PASSWORD=mysql_password_here
```

**Connection file** - `metadata/connections/my_mysql.yml`:

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

vault:
  enabled: true
  path: secret/data/mysql/ecommerce
```

## 📊 Birinchi Pipeline Yaratish

### 1. Flow File Yaratish

`metadata/flows/extract_users.yml` yarating:

```yaml
name: extract_users
description: Extract users from PostgreSQL to MinIO

# Manba (Source)
source:
  connection: my_postgres
  type: table
  table:
    schema: public
    name: users

  # Faqat yangi/o'zgargan datalarni yuklab olish (incremental)
  incremental:
    enabled: true
    column: updated_at
    strategy: max_value

# Nishon (Target)
target:
  connection: minio_raw
  type: object_storage
  path: postgres/users/
  format: parquet
  partition_by:
    - year
    - month
  write_mode: append
  compression: snappy

# Data quality tekshiruvlar
data_quality:
  enabled: true
  checks:
    - name: unique_id
      type: unique
      columns: [id]

    - name: email_not_null
      type: not_null
      column: email

# Schedule - har 6 soatda
schedule:
  enabled: true
  cron: "0 */6 * * *"
  timezone: Asia/Tashkent

metadata:
  owner: data_engineering
  priority: high
```

### 2. Pipeline Ishga Tushirish

**Option A: Airflow orqali (avtomatik)**

1. http://localhost:8080 ga kiring
2. `pipezone_extract_users` DAG ni toping
3. Enable qiling va trigger bosing

**Option B: Jupyter Notebook orqali**

http://localhost:8888 ga kiring va yangi notebook yarating:

```python
from flow_executor import FlowExecutor

# Flow ni ishga tushirish
executor = FlowExecutor()
result = executor.execute_flow('extract_users')

print(f"Status: {result['status']}")
print(f"Records: {result['records_written']}")
print(f"Duration: {result['duration_seconds']}s")
```

**Option C: Python script orqali**

```bash
docker exec pipezone_jupyter python -c "
from sys import path
path.insert(0, '/home/pipezone/utils')
from flow_executor import FlowExecutor
result = FlowExecutor().execute_flow('extract_users')
print(result)
"
```

## 🔄 Pipeline Pattern'lar

### Full Sync (To'liq yuklab olish)

```yaml
source:
  incremental:
    enabled: false

target:
  write_mode: overwrite  # Har safar qaytadan yozadi
```

### Incremental Sync (Faqat yangi data)

```yaml
source:
  incremental:
    enabled: true
    column: updated_at  # yoki created_at, id, etc.
    strategy: max_value
```

### Raw → Bronze Transformation

```yaml
name: clean_users
description: Raw datani tozalash

source:
  connection: minio_raw
  path: postgres/users/
  format: parquet

target:
  connection: minio_bronze
  path: users/
  format: parquet

transformation:
  enabled: true
  steps:
    - name: remove_duplicates
      type: deduplicate
      columns: [id]

    - name: clean_email
      type: transform
      column: email
      expression: "lower(trim(email))"

    - name: add_metadata
      type: add_columns
      columns:
        processed_at: "current_timestamp()"
        layer: "'bronze'"
```

## 📈 Monitoring

### MySQL orqali loglarni ko'rish

```bash
docker exec -it pipezone_mysql mysql -u pipezone -p

# Parol: .env dagi MYSQL_PASSWORD
```

```sql
USE pipezone_metadata;

-- Oxirgi 10 ta execution
SELECT
    flow_name,
    status,
    records_read,
    records_written,
    duration_seconds,
    start_time,
    error_message
FROM pipeline_execution_logs
ORDER BY start_time DESC
LIMIT 10;

-- Incremental state
SELECT * FROM incremental_state;

-- Active flowlar
SELECT * FROM flows_registry WHERE is_active = TRUE;
```

### MinIO da datalarni ko'rish

1. http://localhost:9001 ga kiring
2. Buckets → raw/bronze/silver/gold
3. Fayllaringizni browse qiling

## 🛠️ Muammolarni Hal Qilish

### Service ishlamayapti?

```bash
# Statusni tekshirish
docker ps

# Loglarni ko'rish
docker-compose -f setup/docker/docker-compose.infra.yml logs -f mysql
docker-compose -f setup/docker/docker-compose.airflow.yml logs -f airflow-scheduler
docker-compose -f setup/docker/docker-compose.notebooks.yml logs -f jupyter

# Qayta ishga tushirish
bash setup/scripts/stop-all.sh
bash setup/scripts/start-all.sh
```

### Airflow DAG ko'rinmayapti?

```bash
# Airflow scheduler loglarini tekshiring
docker logs pipezone_airflow_scheduler -f

# Metadata folder mount bo'lganini tekshiring
docker exec pipezone_airflow_scheduler ls -la /opt/pipezone/metadata/flows
```

### Connection test qilish

```python
from connection_manager import ConnectionManager

cm = ConnectionManager()

# Barcha connectionlarni test qilish
for conn in cm.list_connections():
    try:
        status = "✅" if cm.test_connection(conn) else "❌"
        print(f"{status} {conn}")
    except Exception as e:
        print(f"⚠️  {conn}: {e}")
```

## 📚 Qo'shimcha Resurslar

- **To'liq dokumentatsiya**: `README.md`
- **Connection examples**: `metadata/connections/` folder
- **Flow examples**: `metadata/flows/` folder
- **Jupyter notebook**: `core/notebooks/01_Getting_Started.ipynb`

## 💡 Maslahatlar

1. **.env faylni hech qachon git ga commit qilmang!** (`.gitignore` da bor)
2. Production uchun **Vault ishlatib secretlarni saqlang**
3. **Incremental sync** ishlatib network traffic kamaytiring
4. **Data quality checks** qo'shing data integrity uchun
5. **Partition by** ishlatib katta datasetlarni tez query qilish uchun

---

**Savollar?** README.md ga qarang yoki issue oching GitHub da.

**Muvaffaqiyatlar!** 🚀
