"""
Broker provider factory
Creates broker instances based on configuration

This implements a registry pattern allowing dynamic broker provider selection.
"""

import logging
from typing import Dict, Any, List, Type
from .base_provider import BaseBrokerProvider, BrokerError

logger = logging.getLogger(__name__)

# Global registry of available broker providers
_BROKER_REGISTRY: Dict[str, Type[BaseBrokerProvider]] = {}


def register_broker(name: str):
    """
    Decorator to register a broker provider.

    Usage:
        @register_broker('mt4')
        class MT4Provider(BaseBrokerProvider):
            ...

    Args:
        name: Broker provider name (lowercase)
    """
    def decorator(cls: Type[BaseBrokerProvider]):
        if not issubclass(cls, BaseBrokerProvider):
            raise TypeError(
                f"{cls.__name__} must inherit from BaseBrokerProvider"
            )

        broker_name = name.lower()
        _BROKER_REGISTRY[broker_name] = cls
        logger.info(f"Registered broker provider: {name} ({cls.__name__})")
        return cls

    return decorator


def create_broker_provider(
    provider_name: str,
    config: Dict[str, Any]
) -> BaseBrokerProvider:
    """
    Create a broker provider instance.

    Args:
        provider_name: Name of broker provider (mt4, mt5, oanda, binance, etc.)
        config: Broker configuration dict

    Returns:
        Initialized broker provider instance

    Raises:
        BrokerError: If provider not found or initialization fails

    Example:
        >>> config = {
        ...     'api_url': 'http://localhost:8080',
        ...     'api_key': 'your_key'
        ... }
        >>> broker = create_broker_provider('generic', config)
        >>> broker.connect()
    """
    provider_name = provider_name.lower().strip()

    if not provider_name:
        raise BrokerError("Provider name cannot be empty")

    if provider_name not in _BROKER_REGISTRY:
        available = ', '.join(sorted(_BROKER_REGISTRY.keys()))
        raise BrokerError(
            f"Broker provider '{provider_name}' not found. "
            f"Available providers: {available}"
        )

    try:
        provider_class = _BROKER_REGISTRY[provider_name]
        provider = provider_class(config)
        logger.info(
            f"Created broker provider: {provider_name} "
            f"({provider_class.__name__})"
        )
        return provider

    except Exception as e:
        raise BrokerError(
            f"Failed to create {provider_name} provider: {e}"
        ) from e


def get_available_brokers() -> List[str]:
    """
    Get list of available (registered) broker providers.

    Returns:
        List of provider names (sorted alphabetically)

    Example:
        >>> brokers = get_available_brokers()
        >>> print(brokers)
        ['binance', 'generic', 'mt4', 'mt5', 'oanda']
    """
    return sorted(_BROKER_REGISTRY.keys())


def is_broker_available(provider_name: str) -> bool:
    """
    Check if a broker provider is available.

    Args:
        provider_name: Broker provider name

    Returns:
        True if provider is registered
    """
    return provider_name.lower() in _BROKER_REGISTRY


def get_broker_class(provider_name: str) -> Type[BaseBrokerProvider]:
    """
    Get broker provider class by name.

    Args:
        provider_name: Broker provider name

    Returns:
        Broker provider class

    Raises:
        BrokerError: If provider not found
    """
    provider_name = provider_name.lower()

    if provider_name not in _BROKER_REGISTRY:
        available = ', '.join(sorted(_BROKER_REGISTRY.keys()))
        raise BrokerError(
            f"Broker provider '{provider_name}' not found. "
            f"Available: {available}"
        )

    return _BROKER_REGISTRY[provider_name]


# ============================================================================
# AUTO-IMPORT BROKER IMPLEMENTATIONS
# ============================================================================
# Import all broker provider modules to trigger @register_broker decorators
# If a provider fails to import, log warning but don't crash

def _import_providers():
    """Import all broker provider implementations"""

    # Generic REST provider
    try:
        from .generic_rest_provider import GenericRESTProvider
        logger.debug("Loaded GenericRESTProvider")
    except ImportError as e:
        logger.warning(f"Generic REST provider not available: {e}")

    # MT4 Bridge provider
    try:
        from .mt4_bridge_provider import MT4BridgeProvider
        logger.debug("Loaded MT4BridgeProvider")
    except ImportError as e:
        logger.warning(f"MT4 Bridge provider not available: {e}")

    # MT5 provider (future)
    try:
        from .mt5_provider import MT5Provider
        logger.debug("Loaded MT5Provider")
    except ImportError as e:
        logger.debug(f"MT5 provider not available: {e}")

    # Oanda provider (future)
    try:
        from .oanda_provider import OandaProvider
        logger.debug("Loaded OandaProvider")
    except ImportError as e:
        logger.debug(f"Oanda provider not available: {e}")

    # Binance provider (future)
    try:
        from .binance_provider import BinanceProvider
        logger.debug("Loaded BinanceProvider")
    except ImportError as e:
        logger.debug(f"Binance provider not available: {e}")


# Import providers on module load
_import_providers()


# Log registered providers
if _BROKER_REGISTRY:
    logger.info(
        f"Broker providers loaded: {', '.join(sorted(_BROKER_REGISTRY.keys()))}"
    )
else:
    logger.warning("No broker providers registered!")
