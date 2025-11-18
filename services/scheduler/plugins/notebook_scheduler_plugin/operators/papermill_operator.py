# =============================================================================
# Papermill Operator for Airflow
# =============================================================================

import os
from datetime import datetime
from typing import Dict, Any, Optional

from airflow.models import BaseOperator
from airflow.utils.decorators import apply_defaults
import papermill as pm


class PapermillOperator(BaseOperator):
    """
    Executes a Jupyter notebook using Papermill and uploads results to MinIO.

    :param notebook_path: Path to input notebook
    :param output_path: Path for output notebook (optional, auto-generated if not provided)
    :param parameters: Dictionary of parameters to pass to notebook
    :param cluster_config: Spark cluster configuration (small/medium/large)
    :param output_bucket: MinIO bucket for output storage
    :param kernel_name: Jupyter kernel to use
    :param minio_enabled: Whether to upload output to MinIO
    """

    template_fields = ('notebook_path', 'output_path', 'parameters')
    template_ext = ('.ipynb',)
    ui_color = '#f4a460'

    @apply_defaults
    def __init__(
        self,
        notebook_path: str,
        output_path: Optional[str] = None,
        parameters: Optional[Dict[str, Any]] = None,
        cluster_config: str = 'medium_cluster',
        output_bucket: str = 'notebook-outputs',
        kernel_name: str = 'python3',
        minio_enabled: bool = True,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.notebook_path = notebook_path
        self.output_path = output_path
        self.parameters = parameters or {}
        self.cluster_config = cluster_config
        self.output_bucket = output_bucket
        self.kernel_name = kernel_name
        self.minio_enabled = minio_enabled

    def execute(self, context):
        """Execute the notebook with Papermill."""

        # Generate output path if not provided
        if not self.output_path:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            notebook_name = os.path.basename(self.notebook_path)
            output_filename = f"{timestamp}_{notebook_name}"
            self.output_path = f"/tmp/{output_filename}"

        # Set environment variable for cluster selection
        os.environ['SELECTED_CLUSTER'] = self.cluster_config

        # Add execution context to parameters
        exec_params = {
            **self.parameters,
            'execution_date': context['ds'],
            'dag_id': context['dag'].dag_id,
            'task_id': context['task'].task_id,
            'run_id': context['run_id']
        }

        self.log.info(f"Executing notebook: {self.notebook_path}")
        self.log.info(f"Output path: {self.output_path}")
        self.log.info(f"Parameters: {exec_params}")
        self.log.info(f"Cluster: {self.cluster_config}")

        try:
            # Execute notebook
            pm.execute_notebook(
                input_path=self.notebook_path,
                output_path=self.output_path,
                parameters=exec_params,
                kernel_name=self.kernel_name,
                progress_bar=False,
                report_mode=True
            )

            self.log.info("✓ Notebook executed successfully")

            # Upload to MinIO if enabled
            if self.minio_enabled:
                self._upload_to_minio(context)

            return self.output_path

        except Exception as e:
            self.log.error(f"Failed to execute notebook: {str(e)}")
            raise

    def _upload_to_minio(self, context):
        """Upload output notebook to MinIO."""

        try:
            from ..hooks.minio_hook import MinIOHook

            minio_hook = MinIOHook()

            # Generate S3 key
            dag_id = context['dag'].dag_id
            task_id = context['task'].task_id
            execution_date = context['ds_nodash']
            filename = os.path.basename(self.output_path)

            s3_key = f"{dag_id}/{task_id}/{execution_date}/{filename}"

            self.log.info(f"Uploading to MinIO: s3://{self.output_bucket}/{s3_key}")

            # Upload file
            minio_hook.upload_file(
                bucket_name=self.output_bucket,
                object_name=s3_key,
                file_path=self.output_path
            )

            self.log.info("✓ Output uploaded to MinIO")

            # Store S3 path in XCom for downstream tasks
            context['task_instance'].xcom_push(
                key='output_s3_path',
                value=f"s3://{self.output_bucket}/{s3_key}"
            )

        except Exception as e:
            self.log.error(f"Failed to upload to MinIO: {str(e)}")
            # Don't fail the task if upload fails
            pass
