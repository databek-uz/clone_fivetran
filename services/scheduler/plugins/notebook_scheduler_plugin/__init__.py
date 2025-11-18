# =============================================================================
# PipeZone Notebook Scheduler Plugin for Airflow
# =============================================================================

from airflow.plugins_manager import AirflowPlugin

from .operators.papermill_operator import PapermillOperator
from .hooks.minio_hook import MinIOHook
from .hooks.spark_hook import SparkK8sHook


class NotebookSchedulerPlugin(AirflowPlugin):
    """
    Airflow plugin for scheduling and executing Jupyter notebooks
    with Papermill, integrated with Spark and MinIO.
    """

    name = "notebook_scheduler"
    operators = [PapermillOperator]
    hooks = [MinIOHook, SparkK8sHook]
    executors = []
    macros = []
    admin_views = []
    flask_blueprints = []
    menu_links = []
    appbuilder_views = []
    appbuilder_menu_items = []


__version__ = "1.0.0"
__all__ = ["NotebookSchedulerPlugin", "PapermillOperator", "MinIOHook", "SparkK8sHook"]
