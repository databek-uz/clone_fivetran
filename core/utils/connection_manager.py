"""
PipeZone Connection Manager
Manages database connections using YAML configurations and Vault secrets
"""

import os
import yaml
import hvac
from typing import Dict, Any, Optional
from pathlib import Path
import logging
from string import Template

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages connections defined in YAML files with Vault integration"""

    def __init__(self, metadata_path: Optional[str] = None):
        self.metadata_path = metadata_path or os.getenv('METADATA_PATH', '/opt/pipezone/metadata')
        self.connections_path = os.path.join(self.metadata_path, 'connections')
        self.vault_client = self._init_vault()
        self._connection_cache = {}

    def _init_vault(self) -> Optional[hvac.Client]:
        """Initialize Vault client if configured"""
        vault_addr = os.getenv('VAULT_ADDR')
        vault_token = os.getenv('VAULT_TOKEN')

        if not vault_addr or not vault_token:
            logger.warning("Vault not configured, secrets management disabled")
            return None

        try:
            client = hvac.Client(url=vault_addr, token=vault_token)
            if client.is_authenticated():
                logger.info("Vault client initialized successfully")
                return client
            else:
                logger.error("Vault authentication failed")
                return None
        except Exception as e:
            logger.error(f"Failed to initialize Vault: {e}")
            return None

    def _substitute_env_vars(self, config: Any) -> Any:
        """Recursively substitute environment variables in config"""
        if isinstance(config, dict):
            return {k: self._substitute_env_vars(v) for k, v in config.items()}
        elif isinstance(config, list):
            return [self._substitute_env_vars(item) for item in config]
        elif isinstance(config, str):
            # Use Template for safe substitution
            try:
                template = Template(config)
                return template.safe_substitute(os.environ)
            except Exception:
                return config
        return config

    def _get_vault_secrets(self, vault_config: Dict[str, Any]) -> Dict[str, Any]:
        """Retrieve secrets from Vault"""
        if not self.vault_client or not vault_config.get('enabled'):
            return {}

        try:
            path = vault_config.get('path')
            keys_mapping = vault_config.get('keys', {})

            # Read secret from Vault
            secret = self.vault_client.secrets.kv.v2.read_secret_version(path=path)
            secret_data = secret['data']['data']

            # Map Vault keys to connection config keys
            mapped_secrets = {}
            for config_key, vault_key in keys_mapping.items():
                if vault_key in secret_data:
                    mapped_secrets[config_key] = secret_data[vault_key]

            return mapped_secrets
        except Exception as e:
            logger.error(f"Failed to retrieve secrets from Vault: {e}")
            return {}

    def load_connection_config(self, connection_name: str) -> Dict[str, Any]:
        """Load connection configuration from YAML file"""
        if connection_name in self._connection_cache:
            return self._connection_cache[connection_name]

        config_file = os.path.join(self.connections_path, f"{connection_name}.yml")

        if not os.path.exists(config_file):
            raise FileNotFoundError(f"Connection config not found: {config_file}")

        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)

        # Substitute environment variables
        config = self._substitute_env_vars(config)

        # Get secrets from Vault if configured
        if 'vault' in config:
            vault_secrets = self._get_vault_secrets(config['vault'])
            # Merge secrets into connection config
            if 'connection' in config:
                config['connection'].update(vault_secrets)

        self._connection_cache[connection_name] = config
        return config

    def get_connection_string(self, connection_name: str) -> str:
        """Generate connection string for a given connection"""
        config = self.load_connection_config(connection_name)
        conn_type = config.get('type')
        conn = config.get('connection', {})

        if conn_type == 'postgresql':
            return (
                f"postgresql://{conn['username']}:{conn['password']}@"
                f"{conn['host']}:{conn['port']}/{conn['database']}"
            )
        elif conn_type == 'mysql':
            return (
                f"mysql+pymysql://{conn['username']}:{conn['password']}@"
                f"{conn['host']}:{conn['port']}/{conn['database']}"
            )
        elif conn_type == 'minio':
            return conn['endpoint']
        else:
            raise ValueError(f"Unsupported connection type: {conn_type}")

    def get_connection_params(self, connection_name: str) -> Dict[str, Any]:
        """Get connection parameters as dictionary"""
        config = self.load_connection_config(connection_name)
        return config.get('connection', {})

    def test_connection(self, connection_name: str) -> bool:
        """Test if connection is working"""
        config = self.load_connection_config(connection_name)
        conn_type = config.get('type')

        try:
            if conn_type in ['postgresql', 'mysql']:
                from sqlalchemy import create_engine
                engine = create_engine(self.get_connection_string(connection_name))
                with engine.connect() as conn:
                    conn.execute("SELECT 1")
                return True
            elif conn_type == 'minio':
                from minio import Minio
                params = self.get_connection_params(connection_name)
                client = Minio(
                    params['endpoint'],
                    access_key=params['access_key'],
                    secret_key=params['secret_key'],
                    secure=params.get('secure', False)
                )
                # Test by listing buckets
                list(client.list_buckets())
                return True
            else:
                logger.warning(f"Connection test not implemented for type: {conn_type}")
                return False
        except Exception as e:
            logger.error(f"Connection test failed for {connection_name}: {e}")
            return False

    def list_connections(self) -> list:
        """List all available connections"""
        if not os.path.exists(self.connections_path):
            return []

        connections = []
        for file in os.listdir(self.connections_path):
            if file.endswith('.yml') or file.endswith('.yaml'):
                connections.append(file.replace('.yml', '').replace('.yaml', ''))
        return connections


if __name__ == "__main__":
    # Example usage
    logging.basicConfig(level=logging.INFO)

    manager = ConnectionManager()

    print("Available connections:")
    for conn in manager.list_connections():
        print(f"  - {conn}")

    # Test a connection
    if manager.list_connections():
        conn_name = manager.list_connections()[0]
        print(f"\nTesting connection: {conn_name}")
        config = manager.load_connection_config(conn_name)
        print(f"Connection type: {config.get('type')}")
        print(f"Connection test: {'✓ PASSED' if manager.test_connection(conn_name) else '✗ FAILED'}")
