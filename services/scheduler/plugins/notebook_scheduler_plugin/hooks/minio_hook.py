# =============================================================================
# MinIO Hook for Airflow
# =============================================================================

import os
from typing import Optional

from airflow.hooks.base import BaseHook
from minio import Minio
from minio.error import S3Error


class MinIOHook(BaseHook):
    """
    Hook for interacting with MinIO (S3-compatible) storage.
    """

    def __init__(
        self,
        minio_conn_id: str = 'minio_default',
        endpoint: Optional[str] = None,
        access_key: Optional[str] = None,
        secret_key: Optional[str] = None
    ):
        super().__init__()
        self.minio_conn_id = minio_conn_id
        self._endpoint = endpoint
        self._access_key = access_key
        self._secret_key = secret_key
        self._client = None

    def get_conn(self) -> Minio:
        """Get MinIO client connection."""

        if self._client is not None:
            return self._client

        # Try to get from connection first
        try:
            connection = self.get_connection(self.minio_conn_id)
            endpoint = connection.host
            access_key = connection.login
            secret_key = connection.password
            secure = connection.schema == 'https'
        except:
            # Fall back to environment variables or provided values
            endpoint = self._endpoint or os.getenv('MINIO_ENDPOINT', 'minio:9000')
            access_key = self._access_key or os.getenv('MINIO_ACCESS_KEY', 'admin')
            secret_key = self._secret_key or os.getenv('MINIO_SECRET_KEY', 'changeme123')
            secure = False

        # Remove protocol if present
        endpoint = endpoint.replace('http://', '').replace('https://', '')

        self.log.info(f"Connecting to MinIO at {endpoint}")

        self._client = Minio(
            endpoint=endpoint,
            access_key=access_key,
            secret_key=secret_key,
            secure=secure
        )

        return self._client

    def upload_file(
        self,
        bucket_name: str,
        object_name: str,
        file_path: str,
        content_type: str = 'application/octet-stream'
    ) -> bool:
        """
        Upload a file to MinIO.

        :param bucket_name: Name of the bucket
        :param object_name: Object key in the bucket
        :param file_path: Path to local file
        :param content_type: MIME type of the file
        :return: True if successful
        """

        try:
            client = self.get_conn()

            # Create bucket if it doesn't exist
            if not client.bucket_exists(bucket_name):
                self.log.info(f"Creating bucket: {bucket_name}")
                client.make_bucket(bucket_name)

            # Upload file
            client.fput_object(
                bucket_name=bucket_name,
                object_name=object_name,
                file_path=file_path,
                content_type=content_type
            )

            self.log.info(f"✓ Uploaded {file_path} to s3://{bucket_name}/{object_name}")
            return True

        except S3Error as e:
            self.log.error(f"MinIO upload error: {str(e)}")
            raise

    def download_file(
        self,
        bucket_name: str,
        object_name: str,
        file_path: str
    ) -> bool:
        """
        Download a file from MinIO.

        :param bucket_name: Name of the bucket
        :param object_name: Object key in the bucket
        :param file_path: Path to save the file locally
        :return: True if successful
        """

        try:
            client = self.get_conn()

            client.fget_object(
                bucket_name=bucket_name,
                object_name=object_name,
                file_path=file_path
            )

            self.log.info(f"✓ Downloaded s3://{bucket_name}/{object_name} to {file_path}")
            return True

        except S3Error as e:
            self.log.error(f"MinIO download error: {str(e)}")
            raise

    def list_objects(
        self,
        bucket_name: str,
        prefix: Optional[str] = None,
        recursive: bool = True
    ) -> list:
        """
        List objects in a MinIO bucket.

        :param bucket_name: Name of the bucket
        :param prefix: Filter by prefix
        :param recursive: List recursively
        :return: List of object names
        """

        try:
            client = self.get_conn()

            objects = client.list_objects(
                bucket_name=bucket_name,
                prefix=prefix or '',
                recursive=recursive
            )

            object_names = [obj.object_name for obj in objects]

            self.log.info(f"Found {len(object_names)} objects in {bucket_name}")
            return object_names

        except S3Error as e:
            self.log.error(f"MinIO list error: {str(e)}")
            raise

    def delete_object(
        self,
        bucket_name: str,
        object_name: str
    ) -> bool:
        """
        Delete an object from MinIO.

        :param bucket_name: Name of the bucket
        :param object_name: Object key in the bucket
        :return: True if successful
        """

        try:
            client = self.get_conn()

            client.remove_object(
                bucket_name=bucket_name,
                object_name=object_name
            )

            self.log.info(f"✓ Deleted s3://{bucket_name}/{object_name}")
            return True

        except S3Error as e:
            self.log.error(f"MinIO delete error: {str(e)}")
            raise
