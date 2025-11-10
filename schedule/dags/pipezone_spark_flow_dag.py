"""
PipeZone - Spark-based Data Flow DAG Generator
Automatically creates Airflow DAGs from YAML flow configurations using PySpark
"""

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta
import os
import yaml
import sys
from pathlib import Path

# Add core utils to Python path
sys.path.insert(0, '/opt/pipezone/core/utils')

# Default arguments for all DAGs
default_args = {
    'owner': 'pipezone',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


def execute_spark_flow(flow_name: str, **context):
    """
    Execute a PipeZone flow using PySpark

    Architecture:
    1. Read flow YAML configuration
    2. Create SparkSession with cluster connection
    3. Read from source using appropriate connector
    4. Write to MinIO raw layer
    5. If target specified, transform and write to target
    """
    import logging
    from pyspark.sql import SparkSession
    from pyspark.sql import functions as F
    import pymysql
    from minio import Minio
    from datetime import datetime
    import uuid

    logger = logging.getLogger(__name__)
    logger.info(f"🚀 Starting Spark flow execution: {flow_name}")

    execution_id = str(uuid.uuid4())
    start_time = datetime.now()

    try:
        # Load flow configuration
        flow_path = f'/opt/pipezone/metadata/flows/{flow_name}.yml'
        with open(flow_path, 'r') as f:
            flow_config = yaml.safe_load(f)

        logger.info(f"📋 Flow config loaded: {flow_config['name']}")

        # Initialize Spark Session with cluster connection
        spark = SparkSession.builder \
            .appName(f"PipeZone-{flow_name}") \
            .master(os.getenv('SPARK_MASTER', 'spark://spark-master:7077')) \
            .config("spark.sql.adaptive.enabled", "true") \
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
            .config("spark.hadoop.fs.s3a.endpoint", f"http://{os.getenv('MINIO_HOST', 'minio')}:{os.getenv('MINIO_PORT', '9000')}") \
            .config("spark.hadoop.fs.s3a.access.key", os.getenv('MINIO_ROOT_USER', '')) \
            .config("spark.hadoop.fs.s3a.secret.key", os.getenv('MINIO_ROOT_PASSWORD', '')) \
            .config("spark.hadoop.fs.s3a.path.style.access", "true") \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .config("spark.jars", "/opt/airflow/jars/hadoop-aws-3.3.4.jar,/opt/airflow/jars/aws-java-sdk-bundle-1.12.262.jar") \
            .getOrCreate()

        logger.info(f"✅ Spark session created: {spark.version}")

        # Step 1: Read from Source
        source = flow_config['source']
        source_connection = source['connection']

        logger.info(f"📥 Reading from source: {source_connection}")

        # Load connection config
        conn_path = f'/opt/pipezone/metadata/connections/{source_connection}.yml'
        with open(conn_path, 'r') as f:
            conn_config = yaml.safe_load(f)

        conn_type = conn_config['type']
        conn_params = conn_config['connection']

        # Read data based on connection type
        if conn_type in ['postgresql', 'mysql']:
            df = read_from_database(spark, source, conn_params, conn_type, flow_config)
        elif conn_type == 'minio':
            df = read_from_minio(spark, source, conn_params)
        else:
            raise ValueError(f"Unsupported source type: {conn_type}")

        initial_count = df.count()
        logger.info(f"📊 Read {initial_count} records from source")

        # Step 2: Write to RAW layer (MinIO)
        target = flow_config.get('target', {})
        target_connection = target.get('connection', 'minio_raw')

        logger.info(f"💾 Writing to RAW: {target_connection}")

        # Load target connection
        target_conn_path = f'/opt/pipezone/metadata/connections/{target_connection}.yml'
        with open(target_conn_path, 'r') as f:
            target_conn_config = yaml.safe_load(f)

        target_params = target_conn_config['connection']

        # Write to MinIO raw
        write_to_minio(spark, df, target, target_params, flow_config)

        final_count = df.count()

        # Update incremental state if needed
        if source.get('incremental', {}).get('enabled'):
            update_incremental_state(flow_name, source, df)

        # Log execution to MySQL
        log_execution(execution_id, flow_name, flow_config, 'success',
                     initial_count, final_count, start_time)

        spark.stop()

        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()

        logger.info(f"✅ Flow completed successfully in {duration}s")

        return {
            'execution_id': execution_id,
            'status': 'success',
            'records_read': initial_count,
            'records_written': final_count,
            'duration_seconds': duration
        }

    except Exception as e:
        logger.error(f"❌ Flow execution failed: {e}", exc_info=True)

        # Log failure
        log_execution(execution_id, flow_name, flow_config, 'failed',
                     0, 0, start_time, error_message=str(e))

        raise


def read_from_database(spark, source, conn_params, conn_type, flow_config):
    """Read data from database using Spark JDBC"""

    # Build JDBC URL
    if conn_type == 'postgresql':
        jdbc_url = f"jdbc:postgresql://{conn_params['host']}:{conn_params['port']}/{conn_params['database']}"
        driver = "org.postgresql.Driver"
    elif conn_type == 'mysql':
        jdbc_url = f"jdbc:mysql://{conn_params['host']}:{conn_params['port']}/{conn_params['database']}"
        driver = "com.mysql.cj.jdbc.Driver"
    else:
        raise ValueError(f"Unsupported database type: {conn_type}")

    # Build table/query
    table_config = source.get('table', {})
    table_full_name = f"{table_config['schema']}.{table_config['name']}"

    # Handle incremental sync
    incremental = source.get('incremental', {})
    if incremental.get('enabled'):
        last_value = get_incremental_state(flow_config['name'], table_config['name'])

        if last_value:
            query = f"""
            (SELECT * FROM {table_full_name}
             WHERE {incremental['column']} > '{last_value}') as incremental_data
            """
        else:
            # Initial load
            query = table_full_name
    else:
        query = table_full_name

    # Read using Spark JDBC
    df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("dbtable", query) \
        .option("user", conn_params['username']) \
        .option("password", conn_params['password']) \
        .option("driver", driver) \
        .option("fetchsize", source.get('fetch_size', 10000)) \
        .load()

    # Select specific columns if defined
    if 'columns' in source and source['columns']:
        df = df.select(*source['columns'])

    return df


def read_from_minio(spark, source, conn_params):
    """Read data from MinIO using Spark"""
    bucket = conn_params['bucket']
    path = source['path']
    format_type = source.get('format', 'parquet')

    s3_path = f"s3a://{bucket}/{path}"

    df = spark.read.format(format_type)

    if 'read_options' in source:
        for key, value in source['read_options'].items():
            df = df.option(key, value)

    return df.load(s3_path)


def write_to_minio(spark, df, target, conn_params, flow_config):
    """Write data to MinIO using Spark"""
    bucket = conn_params['bucket']
    path = target.get('path', f"{flow_config['name']}/")
    format_type = target.get('format', 'parquet')
    write_mode = target.get('write_mode', 'append')

    s3_path = f"s3a://{bucket}/{path}"

    writer = df.write.format(format_type).mode(write_mode)

    # Partitioning
    if 'partition_by' in target:
        writer = writer.partitionBy(*target['partition_by'])

    # Compression
    if 'compression' in target:
        writer = writer.option("compression", target['compression'])

    writer.save(s3_path)


def get_incremental_state(flow_name, table_name):
    """Get last incremental value from MySQL"""
    try:
        conn = pymysql.connect(
            host=os.getenv('MYSQL_HOST', 'mysql'),
            port=int(os.getenv('MYSQL_PORT', 3306)),
            user=os.getenv('MYSQL_USER', 'pipezone'),
            password=os.getenv('MYSQL_PASSWORD', ''),
            database=os.getenv('MYSQL_DATABASE', 'pipezone_metadata'),
            charset='utf8mb4'
        )

        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT last_value FROM incremental_state WHERE flow_name = %s AND table_name = %s",
                (flow_name, table_name)
            )
            result = cursor.fetchone()
            return result[0] if result else None
    except Exception as e:
        print(f"Failed to get incremental state: {e}")
        return None
    finally:
        if conn:
            conn.close()


def update_incremental_state(flow_name, source, df):
    """Update incremental state in MySQL"""
    from pyspark.sql import functions as F

    incremental_col = source['incremental']['column']
    max_value = df.agg(F.max(incremental_col)).collect()[0][0]

    if not max_value:
        return

    try:
        conn = pymysql.connect(
            host=os.getenv('MYSQL_HOST', 'mysql'),
            port=int(os.getenv('MYSQL_PORT', 3306)),
            user=os.getenv('MYSQL_USER', 'pipezone'),
            password=os.getenv('MYSQL_PASSWORD', ''),
            database=os.getenv('MYSQL_DATABASE', 'pipezone_metadata'),
            charset='utf8mb4'
        )

        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO incremental_state (flow_name, table_name, incremental_column, last_value)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE last_value = %s, last_updated = CURRENT_TIMESTAMP
                """,
                (flow_name, source['table']['name'], incremental_col, str(max_value), str(max_value))
            )
            conn.commit()
    except Exception as e:
        print(f"Failed to update incremental state: {e}")
    finally:
        if conn:
            conn.close()


def log_execution(execution_id, flow_name, flow_config, status, records_read,
                 records_written, start_time, error_message=None):
    """Log execution to MySQL"""
    from datetime import datetime

    try:
        conn = pymysql.connect(
            host=os.getenv('MYSQL_HOST', 'mysql'),
            port=int(os.getenv('MYSQL_PORT', 3306)),
            user=os.getenv('MYSQL_USER', 'pipezone'),
            password=os.getenv('MYSQL_PASSWORD', ''),
            database=os.getenv('MYSQL_DATABASE', 'pipezone_metadata'),
            charset='utf8mb4'
        )

        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()

        source_connection = flow_config['source']['connection']
        target_connection = flow_config.get('target', {}).get('connection', 'minio_raw')

        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO pipeline_execution_logs
                (execution_id, flow_name, source_connection, target_connection, status,
                 start_time, end_time, duration_seconds, records_read, records_written, error_message)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (execution_id, flow_name, source_connection, target_connection, status,
                 start_time, end_time, duration, records_read, records_written, error_message)
            )
            conn.commit()
    except Exception as e:
        print(f"Failed to log execution: {e}")
    finally:
        if conn:
            conn.close()


def create_dag_for_flow(flow_config: dict, flow_name: str):
    """Create an Airflow DAG from a flow configuration"""

    schedule = flow_config.get('schedule', {})

    if not schedule.get('enabled', False):
        return None

    cron_expression = schedule.get('cron', None)

    dag_id = f"pipezone_{flow_name}"

    dag = DAG(
        dag_id=dag_id,
        default_args=default_args,
        description=flow_config.get('description', f'PipeZone Spark flow: {flow_name}'),
        schedule_interval=cron_expression,
        start_date=days_ago(1),
        catchup=False,
        tags=['pipezone', 'spark', flow_config.get('source', {}).get('connection', 'unknown')],
    )

    with dag:
        spark_task = PythonOperator(
            task_id=f'spark_execute_{flow_name}',
            python_callable=execute_spark_flow,
            op_kwargs={'flow_name': flow_name},
            provide_context=True,
        )

    return dag


# Load all flow configurations and create DAGs
flows_path = os.getenv('FLOWS_PATH', '/opt/pipezone/metadata/flows')

if os.path.exists(flows_path):
    for flow_file in Path(flows_path).glob('*.yml'):
        flow_name = flow_file.stem

        try:
            with open(flow_file, 'r') as f:
                flow_config = yaml.safe_load(f)

            # Create DAG
            dag = create_dag_for_flow(flow_config, flow_name)

            if dag:
                # Register DAG in globals
                globals()[dag.dag_id] = dag
                print(f"✅ Created Spark DAG: {dag.dag_id}")

        except Exception as e:
            print(f"❌ Failed to create DAG for flow {flow_name}: {e}")
