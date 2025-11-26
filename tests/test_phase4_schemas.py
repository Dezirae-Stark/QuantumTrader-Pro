"""
Unit tests for Phase 4 JSON schemas and validators
Tests market snapshots, signals, orders, and account info
"""

import pytest
import sys
from pathlib import Path
from datetime import datetime

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.validators.json_validator import (
    validate_market_snapshot,
    validate_signal_object,
    validate_order_request,
    validate_order_response,
    validate_account_info,
    ValidationError
)


# ===================================================================
# Market Snapshot Tests
# ===================================================================


def test_valid_market_snapshot():
    """Test valid market snapshot"""
    snapshot = {
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "bid": 1.0850,
        "ask": 1.0852,
        "spread": 0.0002,
        "mid": 1.0851,
        "volume": 1000.0,
        "high": 1.0860,
        "low": 1.0840,
        "open": 1.0845,
        "close": 1.0849,
        "change": 0.0005,
        "change_pct": 0.046,
        "last_update": "2025-01-15T10:30:00Z",
        "source": "mt4"
    }

    # Should not raise
    validate_market_snapshot(snapshot)


def test_market_snapshot_minimal():
    """Test minimal valid market snapshot"""
    snapshot = {
        "symbol": "GBPUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "bid": 1.2650,
        "ask": 1.2653,
        "spread": 0.0003
    }

    validate_market_snapshot(snapshot)


def test_market_snapshot_invalid_ask_bid():
    """Test market snapshot with ask <= bid"""
    snapshot = {
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "bid": 1.0850,
        "ask": 1.0849,  # Invalid: ask < bid
        "spread": 0.0001
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_market_snapshot(snapshot)

    assert "Ask price must be greater than bid price" in str(exc_info.value)


def test_market_snapshot_negative_price():
    """Test market snapshot with negative price"""
    snapshot = {
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "bid": -1.0850,  # Invalid
        "ask": 1.0852,
        "spread": 0.0002
    }

    with pytest.raises(ValidationError):
        validate_market_snapshot(snapshot)


def test_market_snapshot_missing_required():
    """Test market snapshot missing required field"""
    snapshot = {
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "bid": 1.0850
        # Missing 'ask' and 'spread'
    }

    with pytest.raises(ValidationError):
        validate_market_snapshot(snapshot)


# ===================================================================
# Signal Object Tests
# ===================================================================


def test_valid_signal_object():
    """Test valid trading signal"""
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "long",
        "signal_type": "BUY",
        "strength": 0.85,
        "confidence": 85.0,
        "reason": "Strong bullish quantum state detected",
        "entry_price": 1.0850,
        "stop_loss": 1.0820,
        "take_profit": 1.0920,
        "risk_reward_ratio": 2.33,
        "position_size": 0.1,
        "timeframe": "M5",
        "status": "active",
        "source": "quantum"
    }

    validate_signal_object(signal)


def test_signal_long_stop_loss_validation():
    """Test long signal stop loss must be below entry"""
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "long",
        "strength": 0.85,
        "confidence": 85.0,
        "entry_price": 1.0850,
        "stop_loss": 1.0860  # Invalid: above entry for long
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_signal_object(signal)

    assert "stop loss must be below entry" in str(exc_info.value).lower()


def test_signal_short_stop_loss_validation():
    """Test short signal stop loss must be above entry"""
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "short",
        "strength": 0.85,
        "confidence": 85.0,
        "entry_price": 1.0850,
        "stop_loss": 1.0840  # Invalid: below entry for short
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_signal_object(signal)

    assert "stop loss must be above entry" in str(exc_info.value).lower()


def test_signal_long_take_profit_validation():
    """Test long signal take profit must be above entry"""
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "long",
        "strength": 0.85,
        "confidence": 85.0,
        "entry_price": 1.0850,
        "take_profit": 1.0840  # Invalid: below entry for long
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_signal_object(signal)

    assert "take profit must be above entry" in str(exc_info.value).lower()


def test_signal_short_take_profit_validation():
    """Test short signal take profit must be below entry"""
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "short",
        "strength": 0.85,
        "confidence": 85.0,
        "entry_price": 1.0850,
        "take_profit": 1.0860  # Invalid: above entry for short
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_signal_object(signal)

    assert "take profit must be below entry" in str(exc_info.value).lower()


def test_signal_invalid_risk_reward():
    """Test signal with negative risk/reward ratio"""
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "long",
        "strength": 0.85,
        "confidence": 85.0,
        "entry_price": 1.0850,
        "risk_reward_ratio": -1.5  # Invalid
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_signal_object(signal)

    # JSON schema validation error for minimum constraint
    assert "is less than the minimum of 0" in str(exc_info.value).lower()


# ===================================================================
# Order Request Tests
# ===================================================================


def test_valid_market_order_request():
    """Test valid market order request"""
    order = {
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 0.1,
        "order_type": "market",
        "stop_loss": 1.0820,
        "take_profit": 1.0920,
        "time_in_force": "GTC",
        "magic_number": 12345,
        "comment": "Quantum signal trade"
    }

    validate_order_request(order)


def test_valid_limit_order_request():
    """Test valid limit order request"""
    order = {
        "symbol": "GBPUSD",
        "side": "sell",
        "quantity": 0.2,
        "order_type": "limit",
        "price": 1.2700,
        "stop_loss": 1.2730,
        "take_profit": 1.2650,
        "time_in_force": "GTC"
    }

    validate_order_request(order)


def test_limit_order_missing_price():
    """Test limit order without required price"""
    order = {
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 0.1,
        "order_type": "limit"
        # Missing 'price'
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_order_request(order)

    # Schema validation error - price is required for limit orders
    assert "'price' is a required property" in str(exc_info.value)


def test_stop_order_missing_stop_price():
    """Test stop order without required stop_price"""
    order = {
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 0.1,
        "order_type": "stop"
        # Missing 'stop_price'
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_order_request(order)

    # Schema validation error - stop_price is required for stop orders
    assert "'stop_price' is a required property" in str(exc_info.value)


def test_order_request_negative_quantity():
    """Test order with negative quantity"""
    order = {
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": -0.1,  # Invalid
        "order_type": "market"
    }

    with pytest.raises(ValidationError):
        validate_order_request(order)


def test_order_request_invalid_symbol():
    """Test order with invalid symbol format"""
    order = {
        "symbol": "eur",  # Invalid: too short
        "side": "buy",
        "quantity": 0.1,
        "order_type": "market"
    }

    with pytest.raises(ValidationError):
        validate_order_request(order)


# ===================================================================
# Order Response Tests
# ===================================================================


def test_valid_order_response_filled():
    """Test valid filled order response"""
    order = {
        "order_id": "12345678",
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 0.1,
        "filled_quantity": 0.1,
        "remaining_quantity": 0.0,
        "order_type": "market",
        "status": "filled",
        "average_fill_price": 1.0851,
        "timestamp": "2025-01-15T10:30:00Z",
        "filled_at": "2025-01-15T10:30:01Z",
        "commission": 0.50,
        "swap": 0.0,
        "profit": 0.0
    }

    validate_order_response(order)


def test_valid_order_response_partial():
    """Test valid partially filled order response"""
    order = {
        "order_id": "12345678",
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 1.0,
        "filled_quantity": 0.5,
        "remaining_quantity": 0.5,
        "order_type": "limit",
        "status": "partially_filled",
        "price": 1.0850,
        "average_fill_price": 1.0850,
        "timestamp": "2025-01-15T10:30:00Z",
        "updated_at": "2025-01-15T10:30:05Z"
    }

    validate_order_response(order)


def test_order_response_rejected():
    """Test rejected order response"""
    order = {
        "order_id": "12345678",
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 100.0,  # Too large
        "filled_quantity": 0.0,
        "remaining_quantity": 0.0,
        "order_type": "market",
        "status": "rejected",
        "timestamp": "2025-01-15T10:30:00Z",
        "rejection_reason": "Insufficient margin"
    }

    validate_order_response(order)


# ===================================================================
# Account Info Tests
# ===================================================================


def test_valid_account_info():
    """Test valid account information"""
    account = {
        "account_id": "123456",
        "account_name": "Live Trading Account",
        "timestamp": "2025-01-15T10:30:00Z",
        "balance": 10000.0,
        "equity": 10050.0,
        "margin": 500.0,
        "free_margin": 9550.0,
        "margin_level": 2010.0,
        "floating_pl": 50.0,
        "realized_pl": 0.0,
        "currency": "USD",
        "leverage": 100,
        "open_positions": 1,
        "open_orders": 0,
        "total_trades_today": 5,
        "total_volume_today": 0.5,
        "account_type": "live",
        "broker": "MetaTrader 4",
        "server": "BrokerServer-Live"
    }

    validate_account_info(account)


def test_account_info_with_positions():
    """Test account info with positions"""
    account = {
        "account_id": "123456",
        "timestamp": "2025-01-15T10:30:00Z",
        "balance": 10000.0,
        "equity": 10050.0,
        "currency": "USD",
        "positions": [
            {
                "position_id": "78901",
                "symbol": "EURUSD",
                "side": "buy",
                "quantity": 0.1,
                "open_price": 1.0850,
                "current_price": 1.0860,
                "profit": 10.0,
                "commission": 0.50,
                "swap": 0.0,
                "open_time": "2025-01-15T10:00:00Z",
                "magic_number": 12345,
                "comment": "Quantum trade"
            }
        ]
    }

    validate_account_info(account)


def test_account_info_negative_equity():
    """Test account with negative equity"""
    account = {
        "account_id": "123456",
        "timestamp": "2025-01-15T10:30:00Z",
        "balance": 10000.0,
        "equity": -500.0,  # Invalid
        "currency": "USD"
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_account_info(account)

    # JSON schema validation error for minimum constraint
    assert "is less than the minimum of 0" in str(exc_info.value).lower()


def test_account_info_invalid_currency():
    """Test account with invalid currency format"""
    account = {
        "account_id": "123456",
        "timestamp": "2025-01-15T10:30:00Z",
        "balance": 10000.0,
        "equity": 10000.0,
        "currency": "DOLLARS"  # Invalid: must be 3-letter code
    }

    with pytest.raises(ValidationError):
        validate_account_info(account)


def test_account_info_missing_required():
    """Test account info missing required fields"""
    account = {
        "account_id": "123456",
        "timestamp": "2025-01-15T10:30:00Z",
        "balance": 10000.0
        # Missing 'equity' and 'currency'
    }

    with pytest.raises(ValidationError):
        validate_account_info(account)


# ===================================================================
# Integration Tests
# ===================================================================


def test_complete_trading_workflow():
    """Test complete trading workflow validation"""

    # 1. Market snapshot
    snapshot = {
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "bid": 1.0850,
        "ask": 1.0852,
        "spread": 0.0002
    }
    validate_market_snapshot(snapshot)

    # 2. Signal generation
    signal = {
        "id": "EURUSD-a1b2c3d4",
        "symbol": "EURUSD",
        "timestamp": "2025-01-15T10:30:00Z",
        "direction": "long",
        "strength": 0.85,
        "confidence": 85.0,
        "entry_price": 1.0852
    }
    validate_signal_object(signal)

    # 3. Order placement
    order_request = {
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 0.1,
        "order_type": "market"
    }
    validate_order_request(order_request)

    # 4. Order confirmation
    order_response = {
        "order_id": "12345678",
        "symbol": "EURUSD",
        "side": "buy",
        "quantity": 0.1,
        "filled_quantity": 0.1,
        "remaining_quantity": 0.0,
        "order_type": "market",
        "status": "filled",
        "average_fill_price": 1.0852,
        "timestamp": "2025-01-15T10:30:00Z"
    }
    validate_order_response(order_response)

    # 5. Account update
    account = {
        "account_id": "123456",
        "timestamp": "2025-01-15T10:30:01Z",
        "balance": 10000.0,
        "equity": 10000.0,
        "currency": "USD"
    }
    validate_account_info(account)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
