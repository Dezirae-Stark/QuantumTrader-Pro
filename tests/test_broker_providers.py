"""
Unit tests for broker providers
"""

import pytest
import sys
from pathlib import Path
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from brokers import (
    create_broker_provider,
    get_available_brokers,
    is_broker_available,
    BrokerError,
    OrderSide,
    OrderType
)
from brokers.base_provider import (
    SymbolInfo,
    Tick,
    OHLC,
    Order,
    OrderStatus,
    AccountInfo
)


def test_get_available_brokers():
    """Test getting list of available brokers"""
    brokers = get_available_brokers()

    assert isinstance(brokers, list)
    assert len(brokers) > 0

    # Should have at least generic and mt4
    assert 'generic' in brokers or 'mt4' in brokers


def test_is_broker_available():
    """Test checking broker availability"""
    # Should have generic provider
    assert is_broker_available('generic') or is_broker_available('mt4')

    # Non-existent broker
    assert not is_broker_available('nonexistent_broker')


def test_create_generic_broker():
    """Test creating generic broker provider"""
    config = {
        'api_url': 'http://localhost:8080',
        'api_key': 'test_key',
        'timeout_seconds': 30
    }

    broker = create_broker_provider('generic', config)

    assert broker is not None
    assert broker.api_url == 'http://localhost:8080'
    assert broker.api_key == 'test_key'
    assert not broker.is_connected()


def test_create_mt4_broker():
    """Test creating MT4 bridge provider"""
    config = {
        'api_url': 'http://localhost:8080',
        'data_dir': 'bridge/data'
    }

    broker = create_broker_provider('mt4', config)

    assert broker is not None
    assert broker.api_url == 'http://localhost:8080'
    assert not broker.is_connected()


def test_create_invalid_broker():
    """Test creating non-existent broker raises error"""
    config = {'api_url': 'http://localhost:8080'}

    with pytest.raises(BrokerError) as exc_info:
        create_broker_provider('nonexistent', config)

    assert 'not found' in str(exc_info.value).lower()


def test_symbol_info_dataclass():
    """Test SymbolInfo dataclass"""
    info = SymbolInfo(
        symbol='EURUSD',
        description='EUR/USD',
        base_currency='EUR',
        quote_currency='USD',
        pip_size=0.00001,
        lot_size=100000,
        min_lot=0.01,
        max_lot=100.0,
        lot_step=0.01,
        contract_size=100000,
        margin_required=0.0,
        digits=5
    )

    assert info.symbol == 'EURUSD'
    assert info.pip_size == 0.00001
    assert info.digits == 5


def test_tick_dataclass():
    """Test Tick dataclass with properties"""
    tick = Tick(
        symbol='EURUSD',
        bid=1.0850,
        ask=1.0852,
        timestamp=datetime.utcnow()
    )

    assert tick.symbol == 'EURUSD'
    assert tick.mid == 1.0851  # (bid + ask) / 2
    assert tick.spread == 0.0002  # ask - bid


def test_ohlc_dataclass():
    """Test OHLC dataclass with properties"""
    ohlc = OHLC(
        symbol='EURUSD',
        timeframe='M5',
        timestamp=datetime.utcnow(),
        open=1.0850,
        high=1.0860,
        low=1.0845,
        close=1.0855,
        volume=1000
    )

    assert ohlc.typical_price == (1.0860 + 1.0845 + 1.0855) / 3
    assert ohlc.range == 1.0860 - 1.0845
    assert ohlc.body == abs(1.0855 - 1.0850)
    assert ohlc.is_bullish  # close > open
    assert not ohlc.is_bearish


def test_order_dataclass():
    """Test Order dataclass with properties"""
    order = Order(
        order_id='123',
        symbol='EURUSD',
        side=OrderSide.BUY,
        order_type=OrderType.MARKET,
        quantity=0.1,
        price=1.0850,
        stop_loss=1.0800,
        take_profit=1.0900,
        status=OrderStatus.OPEN,
        filled_quantity=0.1,
        average_price=1.0850,
        timestamp=datetime.utcnow()
    )

    assert order.is_open
    assert order.is_buy
    assert not order.is_sell
    assert order.remaining_quantity == 0.0  # fully filled


def test_account_info_dataclass():
    """Test AccountInfo dataclass with properties"""
    account = AccountInfo(
        account_id='12345',
        balance=10000.0,
        equity=10500.0,
        margin_used=1000.0,
        margin_free=9500.0,
        margin_level=1050.0,
        currency='USD',
        leverage=100,
        profit=500.0,
        open_positions=2
    )

    assert account.is_healthy  # margin_level > 100
    assert account.risk_percentage == pytest.approx(9.52, rel=0.1)  # (1000/10500)*100


def test_mt4_symbol_info():
    """Test MT4 provider symbol info generation"""
    config = {
        'api_url': 'http://localhost:8080',
        'data_dir': 'bridge/data'
    }

    broker = create_broker_provider('mt4', config)

    # Test known symbol
    info = broker.get_symbol_info('EURUSD')

    assert info.symbol == 'EURUSD'
    assert info.digits == 5
    assert info.pip_size == 0.00001
    assert info.base_currency == 'EUR'
    assert info.quote_currency == 'USD'


def test_mt4_symbol_info_gold():
    """Test MT4 provider XAUUSD (gold) symbol info"""
    config = {
        'api_url': 'http://localhost:8080',
        'data_dir': 'bridge/data'
    }

    broker = create_broker_provider('mt4', config)

    info = broker.get_symbol_info('XAUUSD')

    assert info.symbol == 'XAUUSD'
    assert info.digits == 2  # Gold has 2 decimal places
    assert info.pip_size == 0.01


@patch('requests.Session.get')
def test_generic_broker_connect(mock_get):
    """Test generic broker connection"""
    # Mock successful health check
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {'status': 'ok'}
    mock_get.return_value = mock_response

    config = {
        'api_url': 'http://localhost:8080',
        'api_key': 'test_key'
    }

    broker = create_broker_provider('generic', config)

    # Test connection
    result = broker.connect()

    assert result is True
    assert broker.is_connected()
    mock_get.assert_called_once()


@patch('requests.Session.get')
def test_generic_broker_get_live_price(mock_get):
    """Test getting live price from generic broker"""
    # Mock price response
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        'bid': 1.0850,
        'ask': 1.0852,
        'timestamp': '2025-11-20T10:00:00Z'
    }
    mock_get.return_value = mock_response

    config = {
        'api_url': 'http://localhost:8080',
        'api_key': 'test_key'
    }

    broker = create_broker_provider('generic', config)
    broker.connected = True  # Simulate connected state

    tick = broker.get_live_price('EURUSD')

    assert tick.symbol == 'EURUSD'
    assert tick.bid == 1.0850
    assert tick.ask == 1.0852
    assert tick.mid == 1.0851


def test_broker_context_manager():
    """Test broker as context manager"""
    config = {
        'api_url': 'http://localhost:8080',
        'api_key': 'test_key'
    }

    broker = create_broker_provider('generic', config)

    # Mock connect/disconnect
    broker.connect = Mock(return_value=True)
    broker.disconnect = Mock(return_value=True)

    with broker:
        broker.connect.assert_called_once()

    broker.disconnect.assert_called_once()


def test_order_side_enum():
    """Test OrderSide enum"""
    assert OrderSide.BUY.value == 'buy'
    assert OrderSide.SELL.value == 'sell'


def test_order_type_enum():
    """Test OrderType enum"""
    assert OrderType.MARKET.value == 'market'
    assert OrderType.LIMIT.value == 'limit'
    assert OrderType.STOP.value == 'stop'


def test_order_status_enum():
    """Test OrderStatus enum"""
    assert OrderStatus.PENDING.value == 'pending'
    assert OrderStatus.OPEN.value == 'open'
    assert OrderStatus.FILLED.value == 'filled'
    assert OrderStatus.CANCELLED.value == 'cancelled'


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
