"""
Configuration Loader for QuantumTrader-Pro
Loads and validates configuration from YAML with environment variable substitution.
"""

import os
import re
import logging
from pathlib import Path
from typing import Any, Dict, Optional
import yaml

logger = logging.getLogger(__name__)


class ConfigError(Exception):
    """Configuration error"""
    pass


class Config:
    """Application configuration with environment variable substitution"""

    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize configuration loader.

        Args:
            config_file: Path to config.yaml (default: configs/config.yaml)
        """
        if config_file is None:
            # Default to configs/config.yaml relative to project root
            project_root = Path(__file__).parent.parent
            config_file = project_root / "configs" / "config.yaml"

        self.config_file = Path(config_file)
        self._config: Dict[str, Any] = {}
        self._load_config()

    def _load_config(self):
        """Load configuration from YAML file"""
        if not self.config_file.exists():
            raise ConfigError(f"Configuration file not found: {self.config_file}")

        try:
            with open(self.config_file, 'r') as f:
                raw_config = yaml.safe_load(f)

            if not raw_config:
                raise ConfigError("Configuration file is empty")

            # Substitute environment variables
            self._config = self._substitute_env_vars(raw_config)

            logger.info(f"Configuration loaded from {self.config_file}")
            logger.info(f"Environment: {self.get('ENV', 'unknown')}")
            logger.info(f"Broker: {self.get_broker_provider()}")
            logger.info(f"Synthetic data: {self.is_synthetic_data_enabled()}")

        except yaml.YAMLError as e:
            raise ConfigError(f"Failed to parse YAML configuration: {e}")
        except Exception as e:
            raise ConfigError(f"Failed to load configuration: {e}")

    def _substitute_env_vars(self, data: Any) -> Any:
        """
        Recursively substitute ${env:VAR_NAME} with environment variables.

        Args:
            data: Configuration data (dict, list, or primitive)

        Returns:
            Data with substituted environment variables
        """
        if isinstance(data, dict):
            return {k: self._substitute_env_vars(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._substitute_env_vars(item) for item in data]
        elif isinstance(data, str):
            # Match ${env:VAR_NAME} or ${env:VAR_NAME:default_value}
            pattern = r'\$\{env:([A-Z_][A-Z0-9_]*):?([^}]*)}\s*'

            def replacer(match):
                var_name = match.group(1)
                default_value = match.group(2) if match.group(2) else None
                value = os.getenv(var_name, default_value)

                if value is None:
                    logger.warning(f"Environment variable {var_name} not set and no default provided")
                    return ""

                return value

            return re.sub(pattern, replacer, data)
        else:
            return data

    def get(self, key: str, default: Any = None) -> Any:
        """
        Get configuration value by dot-notation key.

        Args:
            key: Dot-separated key path (e.g., "BROKER_CONFIG.api_url")
            default: Default value if key not found

        Returns:
            Configuration value
        """
        keys = key.split('.')
        value = self._config

        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
                if value is None:
                    return default
            else:
                return default

        return value

    def get_env(self) -> str:
        """Get current environment (production, staging, demo, development)"""
        return self.get('ENV', 'development')

    def is_production(self) -> bool:
        """Check if running in production mode"""
        return self.get_env() == 'production'

    def is_development(self) -> bool:
        """Check if running in development mode"""
        return self.get_env() == 'development'

    def is_demo(self) -> bool:
        """Check if running in demo mode"""
        return self.get_env() == 'demo'

    def is_synthetic_data_enabled(self) -> bool:
        """Check if synthetic data is allowed"""
        use_synthetic = self.get('USE_SYNTHETIC_DATA', False)

        # In production, NEVER use synthetic data
        if self.is_production():
            if use_synthetic:
                logger.critical(
                    "CRITICAL: USE_SYNTHETIC_DATA=true in production mode! "
                    "Forcing to false."
                )
            return False

        # In demo, check if explicitly allowed
        if self.is_demo():
            return use_synthetic and self.get('ALLOW_SYNTHETIC_IN_DEMO', False)

        # In development, respect the setting
        return use_synthetic

    def get_broker_provider(self) -> str:
        """Get configured broker provider"""
        return self.get('BROKER_PROVIDER', 'generic')

    def get_broker_config(self) -> Dict[str, Any]:
        """Get broker configuration"""
        return self.get('BROKER_CONFIG', {})

    def get_symbol_map(self) -> Dict[str, str]:
        """Get broker symbol mapping"""
        return self.get('BROKER_SYMBOL_MAP', {})

    def get_ml_config(self) -> Dict[str, Any]:
        """Get ML engine configuration"""
        return self.get('ML_CONFIG', {})

    def get_api_config(self) -> Dict[str, Any]:
        """Get API server configuration"""
        return self.get('API_CONFIG', {})

    def get_trading_config(self) -> Dict[str, Any]:
        """Get trading configuration"""
        return self.get('TRADING_CONFIG', {})

    def should_fail_on_data_error(self) -> bool:
        """Check if system should fail when broker data is unavailable"""
        return self.get('DATA_FALLBACK.fail_on_data_error', True)

    def is_strict_validation_enabled(self) -> bool:
        """Check if strict schema validation is enabled"""
        return self.get('API_CONFIG.strict_schema_validation', True)

    def validate(self):
        """
        Validate critical configuration settings.

        Raises:
            ConfigError: If configuration is invalid
        """
        # Check environment
        env = self.get_env()
        valid_envs = ['production', 'staging', 'demo', 'development']
        if env not in valid_envs:
            raise ConfigError(f"Invalid ENV: {env}. Must be one of {valid_envs}")

        # In production, ensure critical settings
        if self.is_production():
            # Must not use synthetic data
            if self.get('USE_SYNTHETIC_DATA', False):
                raise ConfigError(
                    "CRITICAL: USE_SYNTHETIC_DATA cannot be true in production"
                )

            # Must have broker configuration
            broker_config = self.get_broker_config()
            if not broker_config:
                raise ConfigError(
                    "CRITICAL: BROKER_CONFIG is required in production mode"
                )

            # Check for required environment variables
            required_env_vars = [
                'BROKER_API_URL',
                'JWT_SECRET'
            ]

            missing_vars = [var for var in required_env_vars if not os.getenv(var)]
            if missing_vars:
                logger.warning(
                    f"Missing environment variables in production: {missing_vars}"
                )

        logger.info("Configuration validation passed")

    def reload(self):
        """Reload configuration from file"""
        self._load_config()
        self.validate()

    def to_dict(self) -> Dict[str, Any]:
        """Get full configuration as dictionary"""
        return self._config.copy()


# Global configuration instance
_config: Optional[Config] = None


def get_config(config_file: Optional[str] = None) -> Config:
    """
    Get or create global configuration instance.

    Args:
        config_file: Path to config file (only used on first call)

    Returns:
        Configuration instance
    """
    global _config
    if _config is None:
        _config = Config(config_file)
        _config.validate()
    return _config


def reload_config():
    """Reload global configuration"""
    if _config:
        _config.reload()


def is_synthetic_data_allowed() -> bool:
    """Check if synthetic data is currently allowed"""
    config = get_config()
    return config.is_synthetic_data_enabled()


def get_broker_provider() -> str:
    """Get current broker provider"""
    config = get_config()
    return config.get_broker_provider()


if __name__ == "__main__":
    # Test configuration loading
    logging.basicConfig(level=logging.INFO)

    try:
        config = get_config()
        print(f"Environment: {config.get_env()}")
        print(f"Broker: {config.get_broker_provider()}")
        print(f"Synthetic data: {config.is_synthetic_data_enabled()}")
        print(f"Strict validation: {config.is_strict_validation_enabled()}")
        print("\nConfiguration loaded successfully!")
    except ConfigError as e:
        print(f"Configuration error: {e}")
