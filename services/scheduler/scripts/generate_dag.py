#!/usr/bin/env python3
# =============================================================================
# DAG Generator Script
# =============================================================================
# Generates Airflow DAGs for scheduled notebook execution
# =============================================================================

import os
import json
import argparse
from datetime import datetime
from pathlib import Path


def generate_dag(
    notebook_path: str,
    dag_id: str,
    schedule: str = '@daily',
    cluster_config: str = 'medium_cluster',
    parameters: dict = None,
    output_bucket: str = 'notebook-outputs',
    user: str = 'default',
    description: str = None
) -> str:
    """
    Generate an Airflow DAG file for notebook execution.

    Args:
        notebook_path: Path to the notebook file
        dag_id: Unique identifier for the DAG
        schedule: Cron expression or preset (@daily, @hourly, etc.)
        cluster_config: Spark cluster size (small/medium/large_cluster)
        parameters: Dictionary of parameters to pass to notebook
        output_bucket: MinIO bucket for output storage
        user: Username who created this DAG
        description: DAG description

    Returns:
        Path to the generated DAG file
    """

    parameters = parameters or {}
    notebook_name = os.path.basename(notebook_path)

    if not description:
        description = f"Scheduled execution of {notebook_name}"

    # Generate DAG content
    dag_content = f'''# =============================================================================
# Auto-Generated Notebook DAG
# =============================================================================
# Generated at: {datetime.now().isoformat()}
# Notebook: {notebook_name}
# User: {user}
# Cluster: {cluster_config}
# =============================================================================

from datetime import datetime, timedelta
from airflow import DAG
from notebook_scheduler_plugin.operators.papermill_operator import PapermillOperator

# DAG Configuration
DAG_ID = '{dag_id}'
NOTEBOOK_PATH = '{notebook_path}'
CLUSTER_CONFIG = '{cluster_config}'
OUTPUT_BUCKET = '{output_bucket}'
USER = '{user}'

# Default arguments
default_args = {{
    'owner': USER,
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(hours=2),
}}

# Create DAG
with DAG(
    dag_id=DAG_ID,
    default_args=default_args,
    description='{description}',
    schedule_interval='{schedule}',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['notebook', 'pipezone', 'user:{user}', 'cluster:{cluster_config}'],
    max_active_runs=1,
) as dag:

    # Execute notebook with Papermill
    execute_notebook = PapermillOperator(
        task_id='execute_notebook',
        notebook_path=NOTEBOOK_PATH,
        output_path='/tmp/{{{{ dag.dag_id }}}}_{{{{ ds_nodash }}}}.ipynb',
        parameters={{
            **{json.dumps(parameters)},
            'execution_date': '{{{{ ds }}}}',
            'run_id': '{{{{ run_id }}}}',
            'dag_id': '{{{{ dag.dag_id }}}}',
        }},
        cluster_config=CLUSTER_CONFIG,
        output_bucket=OUTPUT_BUCKET,
        kernel_name='python3',
        minio_enabled=True,
    )

    # Task dependencies
    execute_notebook
'''

    # Save DAG file
    dags_dir = Path(__file__).parent.parent / 'dags' / 'generated'
    dags_dir.mkdir(parents=True, exist_ok=True)

    dag_file_path = dags_dir / f'{dag_id}.py'

    with open(dag_file_path, 'w') as f:
        f.write(dag_content)

    print(f"✓ Generated DAG: {dag_file_path}")
    return str(dag_file_path)


def delete_dag(dag_id: str) -> bool:
    """
    Delete a generated DAG file.

    Args:
        dag_id: ID of the DAG to delete

    Returns:
        True if successful
    """

    dags_dir = Path(__file__).parent.parent / 'dags' / 'generated'
    dag_file_path = dags_dir / f'{dag_id}.py'

    if dag_file_path.exists():
        dag_file_path.unlink()
        print(f"✓ Deleted DAG: {dag_file_path}")
        return True
    else:
        print(f"DAG not found: {dag_id}")
        return False


def list_generated_dags() -> list:
    """
    List all generated DAGs.

    Returns:
        List of DAG IDs
    """

    dags_dir = Path(__file__).parent.parent / 'dags' / 'generated'

    if not dags_dir.exists():
        return []

    dag_files = dags_dir.glob('*.py')
    return [f.stem for f in dag_files]


def main():
    """Command-line interface for DAG generation."""

    parser = argparse.ArgumentParser(description='Generate Airflow DAGs for notebooks')

    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Create command
    create_parser = subparsers.add_parser('create', help='Create a new DAG')
    create_parser.add_argument('notebook_path', help='Path to notebook file')
    create_parser.add_argument('--dag-id', required=True, help='Unique DAG identifier')
    create_parser.add_argument('--schedule', default='@daily', help='Schedule interval')
    create_parser.add_argument('--cluster', default='medium_cluster', help='Cluster size')
    create_parser.add_argument('--parameters', type=json.loads, default={}, help='JSON parameters')
    create_parser.add_argument('--user', default='default', help='Username')
    create_parser.add_argument('--description', help='DAG description')

    # Delete command
    delete_parser = subparsers.add_parser('delete', help='Delete a DAG')
    delete_parser.add_argument('dag_id', help='DAG ID to delete')

    # List command
    subparsers.add_parser('list', help='List generated DAGs')

    args = parser.parse_args()

    if args.command == 'create':
        generate_dag(
            notebook_path=args.notebook_path,
            dag_id=args.dag_id,
            schedule=args.schedule,
            cluster_config=args.cluster,
            parameters=args.parameters,
            user=args.user,
            description=args.description
        )

    elif args.command == 'delete':
        delete_dag(args.dag_id)

    elif args.command == 'list':
        dags = list_generated_dags()
        print(f"Generated DAGs ({len(dags)}):")
        for dag_id in dags:
            print(f"  - {dag_id}")

    else:
        parser.print_help()


if __name__ == '__main__':
    main()
