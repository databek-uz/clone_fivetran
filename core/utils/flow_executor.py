"""
PipeZone Flow Executor
Executes data flows defined in YAML configurations
"""

import os
import yaml
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import uuid
from pathlib import Path
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql import functions as F
from connection_manager import ConnectionManager

logger = logging.getLogger(__name__)


class FlowExecutor:
    """Executes data pipeline flows defined in YAML"""

    def __init__(self, spark: Optional[SparkSession] = None, metadata_path: Optional[str] = None):
        self.metadata_path = metadata_path or os.getenv('METADATA_PATH', '/opt/pipezone/metadata')
        self.flows_path = os.path.join(self.metadata_path, 'flows')
        self.connection_manager = ConnectionManager(metadata_path)
        self.spark = spark or self._init_spark()
        self.mysql_conn = self._init_mysql()

    def _init_spark(self) -> SparkSession:
        """Initialize Spark session"""
        spark_master = os.getenv('SPARK_MASTER', 'local[*]')

        builder = SparkSession.builder \
            .appName("PipeZone Flow Executor") \
            .master(spark_master) \
            .config("spark.sql.adaptive.enabled", "true") \
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true")

        # Add S3/MinIO configuration
        minio_endpoint = f"http://{os.getenv('MINIO_HOST', 'minio')}:{os.getenv('MINIO_PORT', '9000')}"
        builder = builder \
            .config("spark.hadoop.fs.s3a.endpoint", minio_endpoint) \
            .config("spark.hadoop.fs.s3a.access.key", os.getenv('MINIO_ROOT_USER', '')) \
            .config("spark.hadoop.fs.s3a.secret.key", os.getenv('MINIO_ROOT_PASSWORD', '')) \
            .config("spark.hadoop.fs.s3a.path.style.access", "true") \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

        return builder.getOrCreate()

    def _init_mysql(self):
        """Initialize MySQL connection for metadata"""
        try:
            import pymysql
            return pymysql.connect(
                host=os.getenv('MYSQL_HOST', 'mysql'),
                port=int(os.getenv('MYSQL_PORT', 3306)),
                user=os.getenv('MYSQL_USER', 'pipezone'),
                password=os.getenv('MYSQL_PASSWORD', ''),
                database=os.getenv('MYSQL_DATABASE', 'pipezone_metadata'),
                charset='utf8mb4'
            )
        except Exception as e:
            logger.error(f"Failed to connect to MySQL: {e}")
            return None

    def load_flow_config(self, flow_name: str) -> Dict[str, Any]:
        """Load flow configuration from YAML"""
        config_file = os.path.join(self.flows_path, f"{flow_name}.yml")

        if not os.path.exists(config_file):
            raise FileNotFoundError(f"Flow config not found: {config_file}")

        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)

        return config

    def get_incremental_state(self, flow_name: str, table_name: str) -> Optional[str]:
        """Get last incremental value from MySQL"""
        if not self.mysql_conn:
            return None

        try:
            with self.mysql_conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT last_value FROM incremental_state
                    WHERE flow_name = %s AND table_name = %s
                    """,
                    (flow_name, table_name)
                )
                result = cursor.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Failed to get incremental state: {e}")
            return None

    def update_incremental_state(self, flow_name: str, table_name: str, last_value: str):
        """Update incremental state in MySQL"""
        if not self.mysql_conn:
            return

        try:
            with self.mysql_conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO incremental_state (flow_name, table_name, incremental_column, last_value)
                    VALUES (%s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE last_value = %s, last_updated = CURRENT_TIMESTAMP
                    """,
                    (flow_name, table_name, 'updated_at', last_value, last_value)
                )
                self.mysql_conn.commit()
        except Exception as e:
            logger.error(f"Failed to update incremental state: {e}")

    def read_from_source(self, flow_config: Dict[str, Any]) -> DataFrame:
        """Read data from source based on flow configuration"""
        source = flow_config['source']
        connection_name = source['connection']
        connection_config = self.connection_manager.load_connection_config(connection_name)

        # Handle database sources
        if connection_config['type'] in ['postgresql', 'mysql']:
            return self._read_from_database(source, connection_config, flow_config)

        # Handle object storage sources
        elif connection_config['type'] == 'minio':
            return self._read_from_object_storage(source, connection_config)

        else:
            raise ValueError(f"Unsupported source type: {connection_config['type']}")

    def _read_from_database(self, source: Dict[str, Any], connection_config: Dict[str, Any],
                            flow_config: Dict[str, Any]) -> DataFrame:
        """Read from database source"""
        conn_params = connection_config['connection']
        jdbc_url = self.connection_manager.get_connection_string(connection_config['name'])

        # Build query
        if 'query' in source and source['query']:
            query = source['query']
        else:
            table_config = source['table']
            table_full_name = f"{table_config['schema']}.{table_config['name']}"

            # Handle incremental sync
            incremental = source.get('incremental', {})
            if incremental.get('enabled'):
                last_value = self.get_incremental_state(
                    flow_config['name'],
                    table_config['name']
                )

                if last_value:
                    query = f"""
                    (SELECT * FROM {table_full_name}
                     WHERE {incremental['column']} > '{last_value}') as incremental_data
                    """
                else:
                    # Initial load
                    initial_query = incremental.get('initial_load', {}).get('query')
                    if initial_query:
                        query = f"({initial_query}) as initial_data"
                    else:
                        query = table_full_name
            else:
                query = table_full_name

        # Read from database
        df = self.spark.read \
            .format("jdbc") \
            .option("url", jdbc_url) \
            .option("dbtable", query) \
            .option("user", conn_params['username']) \
            .option("password", conn_params['password']) \
            .option("fetchsize", source.get('query', {}).get('fetch_size', 10000)) \
            .load()

        # Select specific columns if defined
        if 'columns' in source and source['columns']:
            df = df.select(*source['columns'])

        return df

    def _read_from_object_storage(self, source: Dict[str, Any],
                                   connection_config: Dict[str, Any]) -> DataFrame:
        """Read from object storage (MinIO/S3)"""
        conn_params = connection_config['connection']
        bucket = conn_params['bucket']
        path = source['path']
        format_type = source.get('format', 'parquet')

        # Build S3 path
        s3_path = f"s3a://{bucket}/{path}"

        df = self.spark.read.format(format_type)

        # Add read options if specified
        if 'read_options' in source:
            for key, value in source['read_options'].items():
                df = df.option(key, value)

        return df.load(s3_path)

    def write_to_target(self, df: DataFrame, flow_config: Dict[str, Any]):
        """Write data to target based on flow configuration"""
        target = flow_config['target']
        connection_name = target['connection']
        connection_config = self.connection_manager.load_connection_config(connection_name)

        if connection_config['type'] == 'minio':
            self._write_to_object_storage(df, target, connection_config, flow_config)
        else:
            raise ValueError(f"Unsupported target type: {connection_config['type']}")

    def _write_to_object_storage(self, df: DataFrame, target: Dict[str, Any],
                                  connection_config: Dict[str, Any], flow_config: Dict[str, Any]):
        """Write to object storage"""
        conn_params = connection_config['connection']
        bucket = conn_params['bucket']
        path = target['path']
        format_type = target.get('format', 'parquet')
        write_mode = target.get('write_mode', 'append')

        # Build S3 path
        s3_path = f"s3a://{bucket}/{path}"

        writer = df.write.format(format_type).mode(write_mode)

        # Add partitioning
        if 'partition_by' in target:
            writer = writer.partitionBy(*target['partition_by'])

        # Add compression
        if 'compression' in target:
            writer = writer.option("compression", target['compression'])

        writer.save(s3_path)

    def execute_flow(self, flow_name: str) -> Dict[str, Any]:
        """Execute a complete data flow"""
        execution_id = str(uuid.uuid4())
        start_time = datetime.now()

        logger.info(f"Starting flow execution: {flow_name} (ID: {execution_id})")

        try:
            # Load flow configuration
            flow_config = self.load_flow_config(flow_name)

            # Read from source
            logger.info("Reading from source...")
            df = self.read_from_source(flow_config)

            initial_count = df.count()
            logger.info(f"Read {initial_count} records from source")

            # Apply transformations if configured
            if flow_config.get('transformation', {}).get('enabled'):
                logger.info("Applying transformations...")
                df = self.apply_transformations(df, flow_config)

            # Write to target
            logger.info("Writing to target...")
            self.write_to_target(df, flow_config)

            final_count = df.count()

            # Update incremental state if applicable
            source = flow_config['source']
            if source.get('incremental', {}).get('enabled'):
                incremental_col = source['incremental']['column']
                max_value = df.agg(F.max(incremental_col)).collect()[0][0]
                if max_value:
                    self.update_incremental_state(
                        flow_name,
                        source['table']['name'],
                        str(max_value)
                    )

            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()

            result = {
                'execution_id': execution_id,
                'flow_name': flow_name,
                'status': 'success',
                'records_read': initial_count,
                'records_written': final_count,
                'duration_seconds': duration,
                'start_time': start_time,
                'end_time': end_time
            }

            logger.info(f"Flow completed successfully: {flow_name}")
            return result

        except Exception as e:
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()

            logger.error(f"Flow execution failed: {e}", exc_info=True)

            return {
                'execution_id': execution_id,
                'flow_name': flow_name,
                'status': 'failed',
                'error_message': str(e),
                'duration_seconds': duration,
                'start_time': start_time,
                'end_time': end_time
            }

    def apply_transformations(self, df: DataFrame, flow_config: Dict[str, Any]) -> DataFrame:
        """Apply transformations defined in flow config"""
        transformation = flow_config.get('transformation', {})

        if not transformation.get('enabled'):
            return df

        steps = transformation.get('steps', [])

        for step in steps:
            step_type = step['type']
            logger.info(f"Applying transformation step: {step['name']} ({step_type})")

            if step_type == 'deduplicate':
                df = df.dropDuplicates(step['columns'])

            elif step_type == 'filter':
                df = df.filter(step['condition'])

            elif step_type == 'transform':
                df = df.withColumn(step['column'], F.expr(step['expression']))

            elif step_type == 'add_columns':
                for col_name, expression in step['columns'].items():
                    df = df.withColumn(col_name, F.expr(expression))

        return df


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    executor = FlowExecutor()

    # List available flows
    flows = [f.replace('.yml', '') for f in os.listdir(executor.flows_path) if f.endswith('.yml')]
    print(f"Available flows: {flows}")

    # Execute a flow
    if flows:
        result = executor.execute_flow(flows[0])
        print(f"\nExecution result: {result}")
