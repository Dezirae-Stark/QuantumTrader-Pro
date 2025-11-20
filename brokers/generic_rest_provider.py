"""
Generic REST API broker provider
Works with any broker that provides a REST API

This is a flexible provider that can be adapted to most broker REST APIs.
Customize the endpoint paths and response parsing for your specific broker.
"""

import requests
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
from .base_provider import (
    BaseBrokerProvider,
    BrokerError,
    ConnectionError as BrokerConnectionError,
    AuthenticationError,
    InvalidOrderError,
    InsufficientFundsError,
    SymbolInfo,
    Tick,
    OHLC,
    Order,
    OrderSide,
    OrderType,
    OrderStatus,
    AccountInfo
)
from .factory import register_broker

logger = logging.getLogger(__name__)


@register_broker('generic')
class GenericRESTProvider(BaseBrokerProvider):
    """
    Generic REST API broker provider.

    Configuration (config dict):
        - api_url: Base API URL (required)
        - api_key: API key (required)
        - api_secret: API secret (optional, depends on broker)
        - timeout_seconds: Request timeout (default: 30)
        - verify_ssl: Verify SSL certificates (default: True)
        - max_retries: Maximum retry attempts (default: 3)

    Example:
        >>> config = {
        ...     'api_url': 'http://localhost:8080',
        ...     'api_key': 'your_api_key',
        ...     'timeout_seconds': 30
        ... }
        >>> broker = GenericRESTProvider(config)
        >>> broker.connect()
    """

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)

        # Required config
        self.api_url = config.get('api_url')
        if not self.api_url:
            raise BrokerError("api_url is required in broker configuration")

        self.api_key = config.get('api_key')
        if not self.api_key:
            raise BrokerError("api_key is required in broker configuration")

        # Optional config
        self.api_secret = config.get('api_secret')
        self.timeout = config.get('timeout_seconds', 30)
        self.verify_ssl = config.get('verify_ssl', True)
        self.max_retries = config.get('max_retries', 3)

        # Create session
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json',
            'User-Agent': 'QuantumTrader-Pro/2.1.0'
        })

        self.logger.info(f"Initialized GenericRESTProvider for {self.api_url}")

    def _request(
        self,
        method: str,
        endpoint: str,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Make HTTP request with retry logic.

        Args:
            method: HTTP method (GET, POST, etc.)
            endpoint: API endpoint (e.g., '/api/account')
            **kwargs: Additional arguments for requests

        Returns:
            Response JSON

        Raises:
            BrokerConnectionError: If request fails
        """
        url = f"{self.api_url}{endpoint}"

        kwargs.setdefault('timeout', self.timeout)
        kwargs.setdefault('verify', self.verify_ssl)

        last_error = None

        for attempt in range(self.max_retries):
            try:
                response = self.session.request(method, url, **kwargs)

                # Check for authentication errors
                if response.status_code == 401:
                    raise AuthenticationError("Invalid API credentials")

                # Raise for HTTP errors
                response.raise_for_status()

                # Return JSON
                return response.json()

            except requests.exceptions.Timeout as e:
                last_error = e
                self.logger.warning(f"Request timeout (attempt {attempt + 1}/{self.max_retries})")

            except requests.exceptions.ConnectionError as e:
                last_error = e
                self.logger.warning(f"Connection error (attempt {attempt + 1}/{self.max_retries})")

            except requests.exceptions.HTTPError as e:
                raise BrokerError(f"HTTP error: {e}")

            except requests.exceptions.RequestException as e:
                raise BrokerError(f"Request failed: {e}")

        # All retries failed
        raise BrokerConnectionError(f"Request failed after {self.max_retries} attempts: {last_error}")

    def connect(self) -> bool:
        """Test connection to broker API"""
        try:
            # Test endpoint - customize for your broker
            # Many brokers have /health, /ping, or /time endpoints
            response = self._request('GET', '/api/health')

            self.connected = True
            self.logger.info("Connected to broker API")
            return True

        except AuthenticationError:
            raise

        except Exception as e:
            raise BrokerConnectionError(f"Connection failed: {e}")

    def disconnect(self) -> bool:
        """Close session"""
        self.session.close()
        self.connected = False
        self.logger.info("Disconnected from broker API")
        return True

    def is_connected(self) -> bool:
        """Check connection status"""
        return self.connected

    def get_symbol_info(self, symbol: str) -> SymbolInfo:
        """Get symbol information"""
        try:
            data = self._request('GET', f'/api/symbols/{symbol}')

            # Map broker response to SymbolInfo
            # Customize this mapping for your broker's response format
            return SymbolInfo(
                symbol=data.get('symbol', symbol),
                description=data.get('description', ''),
                base_currency=data.get('base_currency', ''),
                quote_currency=data.get('quote_currency', ''),
                pip_size=float(data.get('pip_size', 0.0001)),
                lot_size=float(data.get('lot_size', 100000)),
                min_lot=float(data.get('min_lot', 0.01)),
                max_lot=float(data.get('max_lot', 100.0)),
                lot_step=float(data.get('lot_step', 0.01)),
                contract_size=float(data.get('contract_size', 100000)),
                margin_required=float(data.get('margin_required', 0)),
                digits=int(data.get('digits', 5)),
                tick_size=data.get('tick_size'),
                tick_value=data.get('tick_value')
            )

        except Exception as e:
            raise BrokerError(f"Failed to get symbol info for {symbol}: {e}")

    def get_live_price(self, symbol: str) -> Tick:
        """Get current price"""
        try:
            data = self._request('GET', f'/api/prices/{symbol}')

            return Tick(
                symbol=symbol,
                bid=float(data['bid']),
                ask=float(data['ask']),
                timestamp=self._parse_timestamp(data.get('timestamp')),
                volume=data.get('volume')
            )

        except Exception as e:
            raise BrokerError(f"Failed to get live price for {symbol}: {e}")

    def get_ohlc(
        self,
        symbol: str,
        timeframe: str,
        limit: int = 500,
        since: Optional[datetime] = None
    ) -> List[OHLC]:
        """Get historical candles"""
        try:
            params = {
                'symbol': symbol,
                'timeframe': timeframe,
                'limit': limit
            }

            if since:
                params['since'] = since.isoformat()

            data = self._request('GET', '/api/ohlc', params=params)

            candles = []
            for candle in data.get('candles', []):
                candles.append(OHLC(
                    symbol=symbol,
                    timeframe=timeframe,
                    timestamp=self._parse_timestamp(candle['timestamp']),
                    open=float(candle['open']),
                    high=float(candle['high']),
                    low=float(candle['low']),
                    close=float(candle['close']),
                    volume=float(candle.get('volume', 0))
                ))

            # Sort by timestamp (oldest to newest)
            candles.sort(key=lambda c: c.timestamp)

            return candles

        except Exception as e:
            raise BrokerError(f"Failed to get OHLC data for {symbol}: {e}")

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
        """Place order"""
        try:
            # Validate order
            if quantity <= 0:
                raise InvalidOrderError("Quantity must be positive")

            if order_type != OrderType.MARKET and price is None:
                raise InvalidOrderError(f"{order_type.value} orders require a price")

            # Build payload
            payload = {
                'symbol': symbol,
                'side': side.value,
                'quantity': quantity,
                'type': order_type.value
            }

            if price is not None:
                payload['price'] = price

            if stop_loss is not None:
                payload['stop_loss'] = stop_loss

            if take_profit is not None:
                payload['take_profit'] = take_profit

            # Add optional parameters
            if 'comment' in kwargs:
                payload['comment'] = kwargs['comment']

            if 'magic_number' in kwargs:
                payload['magic_number'] = kwargs['magic_number']

            # Send order
            data = self._request('POST', '/api/orders', json=payload)

            # Parse response
            return self._parse_order(data)

        except InvalidOrderError:
            raise

        except Exception as e:
            # Try to detect insufficient funds
            if 'insufficient' in str(e).lower() or 'funds' in str(e).lower():
                raise InsufficientFundsError(f"Insufficient funds to place order: {e}")

            raise BrokerError(f"Failed to place order: {e}")

    def close_order(self, order_id: str) -> bool:
        """Close order"""
        try:
            self._request('DELETE', f'/api/orders/{order_id}')
            self.logger.info(f"Closed order {order_id}")
            return True

        except Exception as e:
            raise BrokerError(f"Failed to close order {order_id}: {e}")

    def get_order(self, order_id: str) -> Order:
        """Get order by ID"""
        try:
            data = self._request('GET', f'/api/orders/{order_id}')
            return self._parse_order(data)

        except Exception as e:
            raise BrokerError(f"Failed to get order {order_id}: {e}")

    def get_open_positions(self) -> List[Order]:
        """Get open positions"""
        try:
            data = self._request('GET', '/api/positions')

            positions = []
            for pos in data.get('positions', []):
                positions.append(self._parse_order(pos))

            return positions

        except Exception as e:
            raise BrokerError(f"Failed to get open positions: {e}")

    def get_account_info(self) -> AccountInfo:
        """Get account information"""
        try:
            data = self._request('GET', '/api/account')

            return AccountInfo(
                account_id=str(data.get('account_id', '')),
                balance=float(data.get('balance', 0)),
                equity=float(data.get('equity', 0)),
                margin_used=float(data.get('margin_used', 0)),
                margin_free=float(data.get('margin_free', 0)),
                margin_level=float(data.get('margin_level', 0)),
                currency=data.get('currency', 'USD'),
                leverage=int(data.get('leverage', 1)),
                profit=float(data.get('profit', 0)),
                open_positions=int(data.get('open_positions', 0))
            )

        except Exception as e:
            raise BrokerError(f"Failed to get account info: {e}")

    def _parse_order(self, data: Dict[str, Any]) -> Order:
        """Parse order data from broker response"""
        return Order(
            order_id=str(data['order_id']),
            symbol=data['symbol'],
            side=OrderSide(data['side']),
            order_type=OrderType(data.get('type', 'market')),
            quantity=float(data['quantity']),
            price=data.get('price'),
            stop_loss=data.get('stop_loss'),
            take_profit=data.get('take_profit'),
            status=OrderStatus(data.get('status', 'open')),
            filled_quantity=float(data.get('filled_quantity', 0)),
            average_price=data.get('average_price'),
            timestamp=self._parse_timestamp(data['timestamp']),
            comment=data.get('comment'),
            magic_number=data.get('magic_number')
        )

    def _parse_timestamp(self, ts: Any) -> datetime:
        """Parse timestamp from various formats"""
        if isinstance(ts, datetime):
            return ts

        if isinstance(ts, str):
            # Try ISO format
            try:
                return datetime.fromisoformat(ts.replace('Z', '+00:00'))
            except:
                pass

            # Try other formats as needed
            try:
                return datetime.strptime(ts, '%Y-%m-%d %H:%M:%S')
            except:
                pass

        if isinstance(ts, (int, float)):
            # Unix timestamp
            return datetime.fromtimestamp(ts)

        # Default to now
        return datetime.utcnow()
