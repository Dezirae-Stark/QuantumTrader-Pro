"""
Base broker provider interface
All broker implementations must inherit from this class

This provides a clean abstraction allowing QuantumTrader-Pro to work
with any broker: MT4, MT5, Oanda, Binance, LMAX, etc.
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class OrderType(Enum):
    """Order types supported across brokers"""
    MARKET = "market"
    LIMIT = "limit"
    STOP = "stop"
    STOP_LIMIT = "stop_limit"


class OrderSide(Enum):
    """Order side: buy or sell"""
    BUY = "buy"
    SELL = "sell"


class OrderStatus(Enum):
    """Order status"""
    PENDING = "pending"
    OPEN = "open"
    FILLED = "filled"
    PARTIALLY_FILLED = "partially_filled"
    CANCELLED = "cancelled"
    REJECTED = "rejected"
    EXPIRED = "expired"


@dataclass
class SymbolInfo:
    """Symbol/instrument information"""
    symbol: str
    description: str
    base_currency: str
    quote_currency: str
    pip_size: float
    lot_size: float
    min_lot: float
    max_lot: float
    lot_step: float
    contract_size: float
    margin_required: float
    digits: int
    tick_size: Optional[float] = None
    tick_value: Optional[float] = None


@dataclass
class Tick:
    """Price tick data"""
    symbol: str
    bid: float
    ask: float
    timestamp: datetime
    volume: Optional[float] = None

    @property
    def mid(self) -> float:
        """Mid price (bid + ask) / 2"""
        return (self.bid + self.ask) / 2.0

    @property
    def spread(self) -> float:
        """Spread in price units"""
        return self.ask - self.bid


@dataclass
class OHLC:
    """OHLC candle data"""
    symbol: str
    timeframe: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float

    @property
    def typical_price(self) -> float:
        """Typical price (H + L + C) / 3"""
        return (self.high + self.low + self.close) / 3.0

    @property
    def range(self) -> float:
        """Candle range (high - low)"""
        return self.high - self.low

    @property
    def body(self) -> float:
        """Candle body size"""
        return abs(self.close - self.open)

    @property
    def is_bullish(self) -> bool:
        """True if bullish candle"""
        return self.close > self.open

    @property
    def is_bearish(self) -> bool:
        """True if bearish candle"""
        return self.close < self.open


@dataclass
class Order:
    """Trading order"""
    order_id: str
    symbol: str
    side: OrderSide
    order_type: OrderType
    quantity: float
    price: Optional[float]
    stop_loss: Optional[float]
    take_profit: Optional[float]
    status: OrderStatus
    filled_quantity: float
    average_price: Optional[float]
    timestamp: datetime
    comment: Optional[str] = None
    magic_number: Optional[int] = None

    @property
    def is_open(self) -> bool:
        """True if order is open"""
        return self.status in [OrderStatus.OPEN, OrderStatus.PARTIALLY_FILLED]

    @property
    def remaining_quantity(self) -> float:
        """Remaining unfilled quantity"""
        return self.quantity - self.filled_quantity

    @property
    def is_buy(self) -> bool:
        """True if buy order"""
        return self.side == OrderSide.BUY

    @property
    def is_sell(self) -> bool:
        """True if sell order"""
        return self.side == OrderSide.SELL


@dataclass
class AccountInfo:
    """Trading account information"""
    account_id: str
    balance: float
    equity: float
    margin_used: float
    margin_free: float
    margin_level: float
    currency: str
    leverage: int
    profit: float
    open_positions: int

    @property
    def is_healthy(self) -> bool:
        """True if account is healthy (margin level > 100%)"""
        return self.margin_level > 100.0

    @property
    def risk_percentage(self) -> float:
        """Percentage of equity at risk"""
        if self.equity <= 0:
            return 0.0
        return (self.margin_used / self.equity) * 100.0


class BrokerError(Exception):
    """Broker-related error"""
    def __init__(self, message: str, error_code: Optional[str] = None):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class ConnectionError(BrokerError):
    """Connection-related error"""
    pass


class AuthenticationError(BrokerError):
    """Authentication error"""
    pass


class InsufficientFundsError(BrokerError):
    """Insufficient funds for order"""
    pass


class InvalidOrderError(BrokerError):
    """Invalid order parameters"""
    pass


class BaseBrokerProvider(ABC):
    """
    Abstract base class for all broker providers.

    All broker integrations (MT4, MT5, Oanda, Binance, etc.) must implement
    these methods to ensure consistent interface across the application.
    """

    def __init__(self, config: Dict[str, Any]):
        """
        Initialize broker provider.

        Args:
            config: Broker-specific configuration dict
                Required keys vary by broker, but typically include:
                - api_url: Base API URL
                - api_key: API key
                - api_secret: API secret (optional)
                - timeout_seconds: Request timeout
        """
        self.config = config
        self.connected = False
        self.logger = logging.getLogger(f"{__name__}.{self.__class__.__name__}")

    @abstractmethod
    def connect(self) -> bool:
        """
        Establish connection to broker.

        Returns:
            True if connection successful

        Raises:
            ConnectionError: If connection fails
            AuthenticationError: If authentication fails
        """
        pass

    @abstractmethod
    def disconnect(self) -> bool:
        """
        Close connection to broker.

        Returns:
            True if disconnection successful
        """
        pass

    @abstractmethod
    def is_connected(self) -> bool:
        """
        Check if currently connected to broker.

        Returns:
            True if connected
        """
        pass

    @abstractmethod
    def get_symbol_info(self, symbol: str) -> SymbolInfo:
        """
        Get symbol/instrument information.

        Args:
            symbol: Trading pair symbol (e.g., "EURUSD", "XAUUSD")

        Returns:
            SymbolInfo object with symbol specifications

        Raises:
            BrokerError: If symbol not found or error occurs
        """
        pass

    @abstractmethod
    def get_live_price(self, symbol: str) -> Tick:
        """
        Get current live price for symbol.

        Args:
            symbol: Trading pair symbol

        Returns:
            Tick object with current bid/ask prices

        Raises:
            BrokerError: If error occurs
        """
        pass

    @abstractmethod
    def get_ohlc(
        self,
        symbol: str,
        timeframe: str,
        limit: int = 500,
        since: Optional[datetime] = None
    ) -> List[OHLC]:
        """
        Get historical OHLC candle data.

        Args:
            symbol: Trading pair symbol
            timeframe: Timeframe string (M1, M5, M15, M30, H1, H4, D1, etc.)
            limit: Maximum number of candles to retrieve (default 500)
            since: Start datetime (optional, None = most recent)

        Returns:
            List of OHLC candles, sorted oldest to newest

        Raises:
            BrokerError: If error occurs
        """
        pass

    @abstractmethod
    def place_order(
        self,
        symbol: str,
        side: OrderSide,
        quantity: float,
        order_type: OrderType = OrderType.MARKET,
        price: Optional[float] = None,
        stop_loss: Optional[float] = None,
        take_profit: Optional[float] = None,
        **kwargs
    ) -> Order:
        """
        Place a trading order.

        Args:
            symbol: Trading pair symbol
            side: Buy or sell
            quantity: Order quantity in lots
            order_type: Market, limit, stop, etc.
            price: Limit/stop price (required for non-market orders)
            stop_loss: Stop loss price (optional)
            take_profit: Take profit price (optional)
            **kwargs: Broker-specific parameters (comment, magic number, etc.)

        Returns:
            Order object with order details

        Raises:
            InvalidOrderError: If order parameters are invalid
            InsufficientFundsError: If insufficient funds
            BrokerError: If order fails for other reasons
        """
        pass

    @abstractmethod
    def close_order(self, order_id: str) -> bool:
        """
        Close an open order/position.

        Args:
            order_id: Order ID to close

        Returns:
            True if successful

        Raises:
            BrokerError: If order not found or error occurs
        """
        pass

    @abstractmethod
    def get_order(self, order_id: str) -> Order:
        """
        Get order details by ID.

        Args:
            order_id: Order ID

        Returns:
            Order object

        Raises:
            BrokerError: If order not found
        """
        pass

    @abstractmethod
    def get_open_positions(self) -> List[Order]:
        """
        Get all open positions.

        Returns:
            List of open Order objects

        Raises:
            BrokerError: If error occurs
        """
        pass

    @abstractmethod
    def get_account_info(self) -> AccountInfo:
        """
        Get account information (balance, equity, margin, etc.).

        Returns:
            AccountInfo object with account details

        Raises:
            BrokerError: If error occurs
        """
        pass

    def subscribe_ticks(
        self,
        symbol: str,
        callback: Callable[[Tick], None]
    ) -> bool:
        """
        Subscribe to real-time tick updates.

        Optional: Not all brokers support WebSocket/streaming.

        Args:
            symbol: Trading pair symbol
            callback: Function to call on each tick update

        Returns:
            True if subscription successful

        Raises:
            NotImplementedError: If broker doesn't support tick subscriptions
        """
        raise NotImplementedError(
            f"{self.__class__.__name__} does not support tick subscriptions"
        )

    def unsubscribe_ticks(self, symbol: str) -> bool:
        """
        Unsubscribe from tick updates.

        Args:
            symbol: Trading pair symbol

        Returns:
            True if unsubscription successful

        Raises:
            NotImplementedError: If broker doesn't support tick subscriptions
        """
        raise NotImplementedError(
            f"{self.__class__.__name__} does not support tick subscriptions"
        )

    def test_connection(self) -> bool:
        """
        Test broker connection without throwing exceptions.

        Returns:
            True if connection test successful, False otherwise
        """
        try:
            if not self.is_connected():
                self.connect()

            # Try to get account info as a connection test
            self.get_account_info()
            return True

        except Exception as e:
            self.logger.error(f"Connection test failed: {e}")
            return False

    def __enter__(self):
        """Context manager support: connect on enter"""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager support: disconnect on exit"""
        self.disconnect()
        return False

    def __repr__(self) -> str:
        """String representation"""
        status = "connected" if self.connected else "disconnected"
        return f"<{self.__class__.__name__} {status}>"
