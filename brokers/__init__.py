"""
Broker abstraction layer for QuantumTrader-Pro
Supports multiple brokers: MT4, MT5, Oanda, Binance, LMAX, Generic REST, etc.

Author: Dezirae Stark
Email: clockwork.halo@tutanota.de
"""

from .base_provider import (
    BaseBrokerProvider,
    BrokerError,
    SymbolInfo,
    Tick,
    OHLC,
    Order,
    OrderType,
    OrderSide
)
from .factory import (
    create_broker_provider,
    get_available_brokers,
    is_broker_available,
    register_broker
)

__version__ = "2.1.0"
__all__ = [
    'BaseBrokerProvider',
    'BrokerError',
    'SymbolInfo',
    'Tick',
    'OHLC',
    'Order',
    'OrderType',
    'OrderSide',
    'create_broker_provider',
    'get_available_brokers',
    'is_broker_available',
    'register_broker'
]
