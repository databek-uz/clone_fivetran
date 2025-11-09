"""
PipeZone Dynamic DAG Generator
Automatically creates Airflow DAGs from YAML flow configurations
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

from flow_executor import FlowExecutor

# Default arguments for all DAGs
default_args = {
    'owner': 'pipezone',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


def execute_flow_task(flow_name: str, **context):
    """Task function to execute a PipeZone flow"""
    import logging
    logger = logging.getLogger(__name__)

    logger.info(f"Executing flow: {flow_name}")

    try:
        executor = FlowExecutor()
        result = executor.execute_flow(flow_name)

        logger.info(f"Flow execution result: {result}")

        if result['status'] != 'success':
            raise Exception(f"Flow execution failed: {result.get('error_message')}")

        return result
    except Exception as e:
        logger.error(f"Flow execution error: {e}")
        raise


def create_dag_for_flow(flow_config: dict, flow_name: str):
    """Create an Airflow DAG from a flow configuration"""

    schedule = flow_config.get('schedule', {})

    if not schedule.get('enabled', False):
        return None

    cron_expression = schedule.get('cron', None)
    timezone = schedule.get('timezone', 'UTC')

    dag_id = f"pipezone_{flow_name}"

    dag = DAG(
        dag_id=dag_id,
        default_args=default_args,
        description=flow_config.get('description', f'PipeZone flow: {flow_name}'),
        schedule_interval=cron_expression,
        start_date=days_ago(1),
        catchup=False,
        tags=['pipezone', flow_config.get('metadata', {}).get('layer', 'unknown')],
    )

    with dag:
        flow_task = PythonOperator(
            task_id=f'execute_{flow_name}',
            python_callable=execute_flow_task,
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
                print(f"Created DAG: {dag.dag_id}")

        except Exception as e:
            print(f"Failed to create DAG for flow {flow_name}: {e}")
