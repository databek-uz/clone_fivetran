# =============================================================================
# Spark on Kubernetes Hook for Airflow
# =============================================================================

import os
from typing import Dict, Any, Optional

from airflow.hooks.base import BaseHook


class SparkK8sHook(BaseHook):
    """
    Hook for managing Spark applications on Kubernetes.
    """

    def __init__(
        self,
        namespace: str = 'spark-jobs',
        service_account: str = 'spark'
    ):
        super().__init__()
        self.namespace = namespace
        self.service_account = service_account

    def get_cluster_config(self, cluster_size: str = 'medium_cluster') -> Dict[str, Any]:
        """
        Get Spark cluster configuration based on size.

        :param cluster_size: small_cluster, medium_cluster, or large_cluster
        :return: Dictionary with cluster configuration
        """

        configs = {
            'small_cluster': {
                'driver_cores': 1,
                'driver_memory': '2g',
                'executor_instances': 2,
                'executor_cores': 1,
                'executor_memory': '2g',
                'dynamic_allocation': False
            },
            'medium_cluster': {
                'driver_cores': 2,
                'driver_memory': '4g',
                'executor_instances': 4,
                'executor_cores': 2,
                'executor_memory': '4g',
                'dynamic_allocation': True,
                'min_executors': 2,
                'max_executors': 6
            },
            'large_cluster': {
                'driver_cores': 4,
                'driver_memory': '8g',
                'executor_instances': 8,
                'executor_cores': 4,
                'executor_memory': '8g',
                'dynamic_allocation': True,
                'min_executors': 4,
                'max_executors': 12
            }
        }

        return configs.get(cluster_size, configs['medium_cluster'])

    def get_spark_conf(self, cluster_size: str = 'medium_cluster') -> Dict[str, str]:
        """
        Get Spark configuration for notebook execution.

        :param cluster_size: Cluster size identifier
        :return: Dictionary of Spark configuration properties
        """

        config = self.get_cluster_config(cluster_size)

        spark_conf = {
            # Kubernetes
            'spark.kubernetes.namespace': self.namespace,
            'spark.kubernetes.authenticate.driver.serviceAccountName': self.service_account,
            'spark.kubernetes.container.image': 'apache/spark-py:v3.5.0',

            # Driver
            'spark.driver.cores': str(config['driver_cores']),
            'spark.driver.memory': config['driver_memory'],

            # Executor
            'spark.executor.instances': str(config['executor_instances']),
            'spark.executor.cores': str(config['executor_cores']),
            'spark.executor.memory': config['executor_memory'],

            # Dynamic Allocation
            'spark.dynamicAllocation.enabled': str(config.get('dynamic_allocation', False)).lower(),

            # Memory
            'spark.memory.fraction': '0.8',
            'spark.memory.storageFraction': '0.3',

            # Shuffle
            'spark.sql.shuffle.partitions': '100',
            'spark.sql.adaptive.enabled': 'true',

            # S3/MinIO
            'spark.hadoop.fs.s3a.endpoint': os.getenv('MINIO_ENDPOINT', 'http://minio:9000'),
            'spark.hadoop.fs.s3a.access.key': os.getenv('MINIO_ACCESS_KEY', 'admin'),
            'spark.hadoop.fs.s3a.secret.key': os.getenv('MINIO_SECRET_KEY', 'changeme123'),
            'spark.hadoop.fs.s3a.path.style.access': 'true',
            'spark.hadoop.fs.s3a.impl': 'org.apache.hadoop.fs.s3a.S3AFileSystem',

            # Event Logging
            'spark.eventLog.enabled': 'true',
            'spark.eventLog.dir': 's3a://spark-logs/',
        }

        # Add dynamic allocation config if enabled
        if config.get('dynamic_allocation'):
            spark_conf.update({
                'spark.dynamicAllocation.shuffleTracking.enabled': 'true',
                'spark.dynamicAllocation.minExecutors': str(config.get('min_executors', 2)),
                'spark.dynamicAllocation.maxExecutors': str(config.get('max_executors', 6)),
            })

        return spark_conf

    def get_spark_session_code(self, cluster_size: str = 'medium_cluster') -> str:
        """
        Generate Python code to create a Spark session with the specified configuration.

        :param cluster_size: Cluster size identifier
        :return: Python code as string
        """

        config = self.get_cluster_config(cluster_size)
        spark_conf = self.get_spark_conf(cluster_size)

        # Generate configuration lines
        conf_lines = [f'        .config("{k}", "{v}")' for k, v in spark_conf.items()]
        conf_str = ' \\\n'.join(conf_lines)

        code = f'''
import os
from pyspark.sql import SparkSession

# Create Spark session with {cluster_size} configuration
spark = SparkSession.builder \\
        .appName("PipeZone-Notebook") \\
{conf_str} \\
        .getOrCreate()

print(f"✓ Spark session created with {cluster_size}")
print(f"  Driver: {config['driver_cores']} cores, {config['driver_memory']}")
print(f"  Executors: {config['executor_instances']} x {config['executor_cores']} cores, {config['executor_memory']}")
'''

        return code
