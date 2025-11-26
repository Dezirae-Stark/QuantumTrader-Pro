"""
Unit tests for JSON schema validation
"""

import pytest
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.validators.json_validator import (
    validate_prediction_response,
    validate_signal,
    create_standard_response,
    ValidationError
)


def test_valid_prediction_response():
    """Test validation of a properly formatted prediction response"""
    response = {
        "pair": "EURUSD",
        "timeframe": "M5",
        "timestamp": "2025-11-20T10:30:00Z",
        "signals": [
            {
                "id": "signal-123",
                "direction": "long",
                "strength": 0.85,
                "confidence": 85.0,
                "reason": "Strong bullish momentum"
            }
        ],
        "prediction": {
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        "confidence": 85.0
    }

    # Should not raise
    validate_prediction_response(response)


def test_missing_signals_array_gets_added():
    """Test that missing signals array is automatically added"""
    response = {
        "pair": "EURUSD",
        "timeframe": "M5",
        "timestamp": "2025-11-20T10:30:00Z",
        # No signals array!
        "prediction": {
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        "confidence": 85.0
    }

    # Should add empty signals array
    validate_prediction_response(response)
    assert 'signals' in response
    assert response['signals'] == []


def test_signals_must_be_array():
    """Test that signals must be an array type"""
    response = {
        "pair": "EURUSD",
        "timeframe": "M5",
        "timestamp": "2025-11-20T10:30:00Z",
        "signals": "not an array",  # Wrong type!
        "prediction": {
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        "confidence": 85.0
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_prediction_response(response)

    assert "'signals' must be an array" in str(exc_info.value)


def test_negative_price_rejected():
    """Test that negative predicted prices are rejected"""
    response = {
        "pair": "EURUSD",
        "timeframe": "M5",
        "timestamp": "2025-11-20T10:30:00Z",
        "signals": [],
        "prediction": {
            "next_price": -1.5,  # Negative price!
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        "confidence": 85.0
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_prediction_response(response)

    # The actual error from jsonschema mentions "minimum of 0" due to exclusiveMinimum
    assert "is less than or equal to the minimum of 0" in str(exc_info.value).lower()


def test_confidence_range_validation():
    """Test that confidence must be 0-100"""
    response = {
        "pair": "EURUSD",
        "timeframe": "M5",
        "timestamp": "2025-11-20T10:30:00Z",
        "signals": [],
        "prediction": {
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        "confidence": 150.0  # Out of range!
    }

    with pytest.raises(ValidationError) as exc_info:
        validate_prediction_response(response)

    # The actual error from jsonschema mentions "greater than the maximum of 100"
    assert "is greater than the maximum of 100" in str(exc_info.value).lower()


def test_signal_validation():
    """Test individual signal validation"""
    valid_signal = {
        "id": "sig-123",
        "direction": "long",
        "strength": 0.85,
        "confidence": 85.0,
        "reason": "Test signal"
    }

    # Should not raise
    validate_signal(valid_signal)

    # Missing required field
    invalid_signal = {
        "id": "sig-123",
        "direction": "long",
        # Missing strength!
        "confidence": 85.0,
        "reason": "Test signal"
    }

    with pytest.raises(ValidationError):
        validate_signal(invalid_signal)


def test_create_standard_response():
    """Test standard response creation"""
    response = create_standard_response(
        pair="EURUSD",
        timeframe="M5",
        signals=[],
        prediction={
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        confidence=85.0
    )

    # Should have all required fields
    assert response['pair'] == "EURUSD"
    assert response['timeframe'] == "M5"
    assert 'timestamp' in response
    assert response['signals'] == []
    assert response['prediction']['next_price'] == 1.0850
    assert response['confidence'] == 85.0

    # Should pass validation
    validate_prediction_response(response)


def test_invalid_timeframe():
    """Test that invalid timeframes are rejected"""
    response = {
        "pair": "EURUSD",
        "timeframe": "X99",  # Invalid timeframe!
        "timestamp": "2025-11-20T10:30:00Z",
        "signals": [],
        "prediction": {
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "bull"
        },
        "confidence": 85.0
    }

    with pytest.raises(ValidationError):
        validate_prediction_response(response)


def test_invalid_prediction_state():
    """Test that invalid prediction states are rejected"""
    response = {
        "pair": "EURUSD",
        "timeframe": "M5",
        "timestamp": "2025-11-20T10:30:00Z",
        "signals": [],
        "prediction": {
            "next_price": 1.0850,
            "move_pct": 0.15,
            "volatility": 0.8,
            "state": "invalid_state"  # Not in enum!
        },
        "confidence": 85.0
    }

    with pytest.raises(ValidationError):
        validate_prediction_response(response)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
