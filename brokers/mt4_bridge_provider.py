"""
MT4 Bridge Provider
Connects to the QuantumTrader-Pro bridge server that interfaces with MT4 EAs

This provider works with the existing WebSocket bridge server that receives
market data from MT4 Expert Advisors via HTTP POST.
"""

import requests
import json
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
from pathlib import Path
from .base_provider import (
    BaseBrokerProvider,
    BrokerError,
    ConnectionError as BrokerConnectionError,
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


@register_broker('mt4')
@register_broker('mt4_bridge')
class MT4BridgeProvider(BaseBrokerProvider):
    """
    MT4 Bridge provider for QuantumTrader-Pro.

    Connects to the Node.js WebSocket bridge server that receives data
    from MT4 Expert Advisors.

    Configuration:
        - api_url: Bridge server URL (default: http://localhost:8080)
        - api_key: API key for authentication (optional if auth disabled)
        - timeout_seconds: Request timeout (default: 30)
        - data_dir: Directory where bridge stores market data files
                    (default: bridge/data)

    Example:
        >>> config = {
        ...     'api_url': 'http://localhost:8080',
        ...     'data_dir': 'bridge/data'
        ... }
        >>> broker = MT4BridgeProvider(config)
        >>> broker.connect()
    """

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)

        # Configuration
        self.api_url = config.get('api_url', 'http://localhost:8080')
        self.api_key = config.get('api_key')
        self.timeout = config.get('timeout_seconds', 30)

        # Data directory where bridge stores JSON files
        data_dir = config.get('data_dir', 'bridge/data')
        self.data_dir = Path(data_dir)

        # Create session
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'QuantumTrader-Pro/2.1.0'
        })

        if self.api_key:
            self.session.headers['Authorization'] = f'Bearer {self.api_key}'

        # Cache account info
        self._account_info: Optional[Dict[str, Any]] = None

        self.logger.info(f"Initialized MT4BridgeProvider for {self.api_url}")

    def connect(self) -> bool:
        """Test connection to bridge server"""
        try:
            response = self.session.get(
                f"{self.api_url}/api/health",
                timeout=self.timeout
            )
            response.raise_for_status()

            self.connected = True
            self.logger.info("Connected to MT4 bridge server")
            return True

        except requests.exceptions.RequestException as e:
            raise BrokerConnectionError(f"Failed to connect to bridge: {e}")

    def disconnect(self) -> bool:
        """Close session"""
        self.session.close()
        self.connected = False
        self.logger.info("Disconnected from MT4 bridge server")
        return True

    def is_connected(self) -> bool:
        """Check connection status"""
        return self.connected

    def get_symbol_info(self, symbol: str) -> SymbolInfo:
        """
        Get symbol information.

        For MT4, returns standard Forex symbol specifications.
        """
        # Standard Forex symbols specifications
        forex_specs = {
            'EURUSD': {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000},
            'GBPUSD': {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000},
            'USDJPY': {'digits': 3, 'pip_size': 0.001, 'contract_size': 100000},
            'AUDUSD': {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000},
            'USDCAD': {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000},
            'USDCHF': {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000},
            'NZDUSD': {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000},
            'XAUUSD': {'digits': 2, 'pip_size': 0.01, 'contract_size': 100},  # Gold
            'XAGUSD': {'digits': 3, 'pip_size': 0.001, 'contract_size': 5000},  # Silver
        }

        spec = forex_specs.get(symbol, {'digits': 5, 'pip_size': 0.00001, 'contract_size': 100000})

        # Parse currency pair
        if len(symbol) >= 6:
            base = symbol[:3]
            quote = symbol[3:6]
        else:
            base = symbol
            quote = 'USD'

        return SymbolInfo(
            symbol=symbol,
            description=f"{symbol} Spot",
            base_currency=base,
            quote_currency=quote,
            pip_size=spec['pip_size'],
            lot_size=spec['contract_size'],
            min_lot=0.01,
            max_lot=100.0,
            lot_step=0.01,
            contract_size=spec['contract_size'],
            margin_required=0.0,  # Depends on leverage
            digits=spec['digits']
        )

    def get_live_price(self, symbol: str) -> Tick:
        """
        Get current price from bridge.

        First tries API endpoint, then falls back to reading data file.
        """
        # Try API endpoint
        try:
            response = self.session.get(
                f"{self.api_url}/api/prices/{symbol}",
                timeout=self.timeout
            )

            if response.status_code == 200:
                data = response.json()
                return Tick(
                    symbol=symbol,
                    bid=float(data['bid']),
                    ask=float(data['ask']),
                    timestamp=self._parse_timestamp(data.get('timestamp')),
                    volume=data.get('volume')
                )

        except Exception as e:
            self.logger.debug(f"API price fetch failed, trying file: {e}")

        # Fallback: Read from data file
        try:
            market_file = self.data_dir / f"{symbol}_market.json"

            if market_file.exists():
                with open(market_file, 'r') as f:
                    data = json.load(f)

                if data and len(data) > 0:
                    # Get most recent tick
                    latest = data[-1]
                    return Tick(
                        symbol=symbol,
                        bid=float(latest['bid']),
                        ask=float(latest['ask']),
                        timestamp=datetime.fromtimestamp(latest.get('timestamp', 0)),
                        volume=latest.get('volume')
                    )

        except Exception as e:
            self.logger.warning(f"Failed to read market data file: {e}")

        raise BrokerError(f"No price data available for {symbol}")

    def get_ohlc(
        self,
        symbol: str,
        timeframe: str,
        limit: int = 500,
        since: Optional[datetime] = None
    ) -> List[OHLC]:
        """
        Get historical OHLC data.

        Reads from bridge's stored market data files.
        """
        try:
            market_file = self.data_dir / f"{symbol}_market.json"

            if not market_file.exists():
                raise BrokerError(f"No market data file for {symbol}")

            with open(market_file, 'r') as f:
                data = json.load(f)

            if not data:
                raise BrokerError(f"Empty market data for {symbol}")

            # Convert ticks to OHLC candles
            # Group by timeframe periods
            candles = self._ticks_to_ohlc(data, symbol, timeframe)

            # Filter by since date
            if since:
                candles = [c for c in candles if c.timestamp >= since]

            # Limit results
            if limit and len(candles) > limit:
                candles = candles[-limit:]

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
        """Place order via bridge"""
        try:
            payload = {
                'symbol': symbol,
                'side': side.value,
                'quantity': quantity,
                'type': order_type.value,
                'price': price,
                'stop_loss': stop_loss,
                'take_profit': take_profit
            }

            # Add optional parameters
            if 'comment' in kwargs:
                payload['comment'] = kwargs['comment']

            if 'magic_number' in kwargs:
                payload['magic_number'] = kwargs['magic_number']

            response = self.session.post(
                f"{self.api_url}/api/trade",
                json=payload,
                timeout=self.timeout
            )
            response.raise_for_status()

            data = response.json()

            return Order(
                order_id=str(data.get('order_id', '')),
                symbol=symbol,
                side=side,
                order_type=order_type,
                quantity=quantity,
                price=price,
                stop_loss=stop_loss,
                take_profit=take_profit,
                status=OrderStatus.OPEN,
                filled_quantity=quantity,  # MT4 market orders fill immediately
                average_price=data.get('price'),
                timestamp=datetime.utcnow(),
                comment=kwargs.get('comment'),
                magic_number=kwargs.get('magic_number')
            )

        except Exception as e:
            raise BrokerError(f"Failed to place order: {e}")

    def close_order(self, order_id: str) -> bool:
        """Close order via bridge"""
        try:
            response = self.session.post(
                f"{self.api_url}/api/close",
                json={'order_id': order_id},
                timeout=self.timeout
            )
            response.raise_for_status()

            self.logger.info(f"Closed order {order_id}")
            return True

        except Exception as e:
            raise BrokerError(f"Failed to close order {order_id}: {e}")

    def get_order(self, order_id: str) -> Order:
        """Get order by ID"""
        # MT4 bridge doesn't have individual order lookup
        # Get all positions and filter
        positions = self.get_open_positions()

        for order in positions:
            if order.order_id == order_id:
                return order

        raise BrokerError(f"Order {order_id} not found")

    def get_open_positions(self) -> List[Order]:
        """Get open positions from bridge"""
        try:
            response = self.session.get(
                f"{self.api_url}/api/positions",
                timeout=self.timeout
            )
            response.raise_for_status()

            data = response.json()

            positions = []
            for pos in data.get('positions', []):
                positions.append(Order(
                    order_id=str(pos.get('ticket', '')),
                    symbol=pos.get('symbol', ''),
                    side=OrderSide.BUY if pos.get('type') == 0 else OrderSide.SELL,
                    order_type=OrderType.MARKET,
                    quantity=float(pos.get('volume', 0)),
                    price=float(pos.get('open_price', 0)),
                    stop_loss=pos.get('sl'),
                    take_profit=pos.get('tp'),
                    status=OrderStatus.OPEN,
                    filled_quantity=float(pos.get('volume', 0)),
                    average_price=float(pos.get('open_price', 0)),
                    timestamp=self._parse_timestamp(pos.get('open_time')),
                    comment=pos.get('comment'),
                    magic_number=pos.get('magic_number')
                ))

            return positions

        except Exception as e:
            raise BrokerError(f"Failed to get positions: {e}")

    def get_account_info(self) -> AccountInfo:
        """Get account information from bridge"""
        try:
            # Try reading from account.json file
            account_file = self.data_dir / 'account.json'

            if account_file.exists():
                with open(account_file, 'r') as f:
                    data = json.load(f)

                return AccountInfo(
                    account_id=str(data.get('account', '')),
                    balance=float(data.get('balance', 0)),
                    equity=float(data.get('equity', 0)),
                    margin_used=float(data.get('margin', 0)),
                    margin_free=float(data.get('free_margin', 0)),
                    margin_level=float(data.get('margin_level', 0)),
                    currency=data.get('currency', 'USD'),
                    leverage=int(data.get('leverage', 100)),
                    profit=float(data.get('profit', 0)),
                    open_positions=int(data.get('open_orders', 0))
                )

            # Fallback to defaults if no file
            return AccountInfo(
                account_id='MT4',
                balance=10000.0,
                equity=10000.0,
                margin_used=0.0,
                margin_free=10000.0,
                margin_level=0.0,
                currency='USD',
                leverage=100,
                profit=0.0,
                open_positions=0
            )

        except Exception as e:
            self.logger.warning(f"Failed to get account info: {e}")

            # Return defaults
            return AccountInfo(
                account_id='MT4',
                balance=10000.0,
                equity=10000.0,
                margin_used=0.0,
                margin_free=10000.0,
                margin_level=0.0,
                currency='USD',
                leverage=100,
                profit=0.0,
                open_positions=0
            )

    def _ticks_to_ohlc(
        self,
        ticks: List[Dict[str, Any]],
        symbol: str,
        timeframe: str
    ) -> List[OHLC]:
        """
        Convert tick data to OHLC candles.

        Args:
            ticks: List of tick dicts with bid/ask/timestamp
            symbol: Symbol name
            timeframe: Timeframe (M1, M5, etc.)

        Returns:
            List of OHLC candles
        """
        # Timeframe to seconds mapping
        timeframe_seconds = {
            'M1': 60,
            'M5': 300,
            'M15': 900,
            'M30': 1800,
            'H1': 3600,
            'H4': 14400,
            'D1': 86400
        }

        period_seconds = timeframe_seconds.get(timeframe, 300)  # Default M5

        # Group ticks into candles
        candles_dict = {}

        for tick in ticks:
            # Get mid price
            mid = (tick['bid'] + tick['ask']) / 2.0
            timestamp = tick.get('timestamp', 0)

            # Round timestamp to period boundary
            period_start = (timestamp // period_seconds) * period_seconds

            if period_start not in candles_dict:
                candles_dict[period_start] = {
                    'open': mid,
                    'high': mid,
                    'low': mid,
                    'close': mid,
                    'volume': 0
                }

            candle = candles_dict[period_start]
            candle['high'] = max(candle['high'], mid)
            candle['low'] = min(candle['low'], mid)
            candle['close'] = mid
            candle['volume'] += tick.get('volume', 1)

        # Convert to OHLC objects
        candles = []
        for period_start, data in sorted(candles_dict.items()):
            candles.append(OHLC(
                symbol=symbol,
                timeframe=timeframe,
                timestamp=datetime.fromtimestamp(period_start),
                open=data['open'],
                high=data['high'],
                low=data['low'],
                close=data['close'],
                volume=data['volume']
            ))

        return candles

    def _parse_timestamp(self, ts: Any) -> datetime:
        """Parse timestamp from various formats"""
        if isinstance(ts, datetime):
            return ts

        if isinstance(ts, str):
            try:
                return datetime.fromisoformat(ts.replace('Z', '+00:00'))
            except:
                try:
                    return datetime.strptime(ts, '%Y-%m-%d %H:%M:%S')
                except:
                    pass

        if isinstance(ts, (int, float)):
            return datetime.fromtimestamp(ts)

        return datetime.utcnow()
