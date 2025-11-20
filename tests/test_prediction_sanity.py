"""
Unit tests for prediction sanity checks and postprocessing
"""

import pytest
import sys
from pathlib import Path
import math

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from ml.postprocessing import (
    is_valid_price,
    is_finite,
    clamp_value,
    clamp_prediction_to_range,
    validate_prediction_bounds,
    validate_confidence,
    sanitize_candle_prediction,
    sanitize_prediction_output,
    check_price_sanity,
    get_reasonable_price_range,
    enforce_price_sanity,
    detect_outliers,
    remove_outliers,
    sanitize_predictions
)


def test_is_valid_price():
    """Test price validation"""
    # Valid prices
    assert is_valid_price(1.0850) is True
    assert is_valid_price(100.5) is True
    assert is_valid_price(0.0001) is True

    # Invalid prices
    assert is_valid_price(-1.5) is False  # Negative
    assert is_valid_price(0) is False  # Zero
    assert is_valid_price(float('inf')) is False  # Infinite
    assert is_valid_price(float('nan')) is False  # NaN
    assert is_valid_price('string') is False  # Wrong type


def test_is_finite():
    """Test finite check"""
    assert is_finite(1.0) is True
    assert is_finite(100) is True
    assert is_finite(float('inf')) is False
    assert is_finite(float('-inf')) is False
    assert is_finite(float('nan')) is False


def test_clamp_value():
    """Test value clamping"""
    assert clamp_value(50, 0, 100) == 50  # In range
    assert clamp_value(150, 0, 100) == 100  # Too high
    assert clamp_value(-10, 0, 100) == 0  # Too low


def test_clamp_prediction_to_range():
    """Test prediction clamping"""
    current = 1.0850

    # Normal prediction (within 10%)
    assert clamp_prediction_to_range(current, 1.0900, 0.10) == 1.0900

    # Too high (>10% above)
    clamped = clamp_prediction_to_range(current, 1.2000, 0.10)
    assert clamped <= current * 1.10
    assert clamped == pytest.approx(current * 1.10, rel=0.001)

    # Too low (>10% below)
    clamped = clamp_prediction_to_range(current, 0.9000, 0.10)
    assert clamped >= current * 0.90
    assert clamped == pytest.approx(current * 0.90, rel=0.001)


def test_clamp_prediction_negative():
    """Test clamping handles negative predictions"""
    current = 1.0850
    negative = -1.5

    # Should return current price for invalid prediction
    result = clamp_prediction_to_range(current, negative, 0.10)
    assert result == current


def test_validate_prediction_bounds():
    """Test prediction bounds validation"""
    current = 1.0850
    prediction = 1.0900
    upper = 1.0950
    lower = 1.0850

    validated = validate_prediction_bounds(prediction, upper, lower, current)

    assert validated['predicted_price'] == prediction
    assert validated['upper_bound'] == upper
    assert validated['lower_bound'] == lower


def test_validate_prediction_bounds_invalid_order():
    """Test bounds validation when lower >= upper"""
    current = 1.0850
    prediction = 1.0900
    upper = 1.0800  # Wrong! Upper < lower
    lower = 1.0900

    validated = validate_prediction_bounds(prediction, upper, lower, current)

    # Should fix the bounds
    assert validated['lower_bound'] < validated['upper_bound']
    assert validated['lower_bound'] < validated['predicted_price'] < validated['upper_bound']


def test_validate_prediction_bounds_outside():
    """Test prediction outside bounds gets clamped"""
    current = 1.0850
    prediction = 1.1000  # Outside bounds
    upper = 1.0900
    lower = 1.0800

    validated = validate_prediction_bounds(prediction, upper, lower, current)

    # Prediction should be clamped to upper bound
    assert validated['lower_bound'] <= validated['predicted_price'] <= validated['upper_bound']


def test_validate_confidence():
    """Test confidence validation"""
    # Valid confidence (0-1)
    assert validate_confidence(0.85) == 0.85

    # Percentage format (0-100)
    assert validate_confidence(85.0) == 0.85

    # Out of range
    assert validate_confidence(150.0) == 1.0
    assert validate_confidence(-10.0) == 0.0

    # Invalid
    assert validate_confidence(float('nan')) == 0.5


def test_sanitize_candle_prediction():
    """Test sanitizing a single prediction"""
    current = 1.0850

    prediction = {
        'predicted_price': 1.2000,  # Too high
        'upper_bound': 1.2100,
        'lower_bound': 1.1900,
        'confidence': 85.0  # Percentage format
    }

    sanitized = sanitize_candle_prediction(prediction, current, max_move_pct=0.10)

    # Price should be clamped
    assert sanitized['predicted_price'] <= current * 1.10

    # Confidence should be normalized
    assert 0 <= sanitized['confidence'] <= 1


def test_sanitize_prediction_output():
    """Test sanitizing multiple predictions"""
    current = 1.0850

    predictions = [
        {
            'predicted_price': 1.0900,
            'upper_bound': 1.0950,
            'lower_bound': 1.0850,
            'confidence': 0.85
        },
        {
            'predicted_price': 1.5000,  # Outlier
            'upper_bound': 1.5100,
            'lower_bound': 1.4900,
            'confidence': 150.0  # Invalid
        }
    ]

    sanitized = sanitize_prediction_output(predictions, current, max_move_pct=0.10)

    # Should have 2 predictions
    assert len(sanitized) == 2

    # All should be valid
    for pred in sanitized:
        assert is_valid_price(pred['predicted_price'])
        assert 0 <= pred['confidence'] <= 1
        assert pred['lower_bound'] < pred['upper_bound']


def test_check_price_sanity():
    """Test price sanity checking"""
    # EURUSD sanity
    assert check_price_sanity(1.0850, 'EURUSD', 0.5, 2.0) is True
    assert check_price_sanity(5.0, 'EURUSD', 0.5, 2.0) is False

    # Negative price
    assert check_price_sanity(-1.5, 'EURUSD') is False


def test_get_reasonable_price_range():
    """Test getting reasonable price ranges"""
    # EURUSD
    min_price, max_price = get_reasonable_price_range('EURUSD')
    assert min_price == 0.5
    assert max_price == 2.0

    # Gold
    min_price, max_price = get_reasonable_price_range('XAUUSD')
    assert min_price == 500.0
    assert max_price == 5000.0

    # Unknown symbol (should return default)
    min_price, max_price = get_reasonable_price_range('UNKNOWN')
    assert min_price == 0.0
    assert max_price == float('inf')


def test_enforce_price_sanity():
    """Test price sanity enforcement"""
    # Valid price
    price = enforce_price_sanity(1.0850, 'EURUSD')
    assert price == 1.0850

    # Invalid price with fallback
    price = enforce_price_sanity(-1.5, 'EURUSD', fallback_price=1.0800)
    assert price == 1.0800

    # Invalid price without fallback (uses mid-range)
    price = enforce_price_sanity(-1.5, 'EURUSD')
    assert price > 0
    assert 0.5 < price < 2.0  # Within EURUSD range


def test_detect_outliers():
    """Test outlier detection"""
    # Normal predictions
    predictions = [1.0850, 1.0855, 1.0860, 1.0865]
    outliers = detect_outliers(predictions)
    assert len(outliers) == 0

    # With outlier
    predictions = [1.0850, 1.0855, 1.0860, 5.0000]  # Last is outlier
    outliers = detect_outliers(predictions)
    assert 3 in outliers  # Index 3 is outlier


def test_remove_outliers():
    """Test outlier removal"""
    predictions = [
        {'predicted_price': 1.0850},
        {'predicted_price': 1.0855},
        {'predicted_price': 1.0860},
        {'predicted_price': 5.0000}  # Outlier
    ]

    cleaned = remove_outliers(predictions)

    # Should remove 1 outlier
    assert len(cleaned) == 3

    # All remaining should be close to each other
    prices = [p['predicted_price'] for p in cleaned]
    assert max(prices) - min(prices) < 0.01


def test_sanitize_predictions_complete():
    """Test complete sanitization pipeline"""
    current = 1.0850

    predictions = [
        {
            'predicted_price': 1.0900,
            'upper_bound': 1.0950,
            'lower_bound': 1.0850,
            'confidence': 0.85
        },
        {
            'predicted_price': -1.5,  # Invalid
            'upper_bound': 1.0950,
            'lower_bound': 1.0850,
            'confidence': 0.75
        },
        {
            'predicted_price': 5.0000,  # Outlier
            'upper_bound': 5.1000,
            'lower_bound': 4.9000,
            'confidence': 0.90
        }
    ]

    sanitized = sanitize_predictions(
        predictions,
        current,
        symbol='EURUSD',
        max_move_pct=0.10,
        remove_outliers_enabled=True
    )

    # Should have valid predictions
    assert len(sanitized) > 0

    # All should be valid
    for pred in sanitized:
        assert is_valid_price(pred['predicted_price'])
        assert 0 <= pred['confidence'] <= 1
        assert pred['lower_bound'] < pred['upper_bound']

        # Should be within EURUSD reasonable range
        assert 0.5 < pred['predicted_price'] < 2.0


def test_sanitize_empty_predictions():
    """Test sanitizing empty prediction list"""
    result = sanitize_prediction_output([], 1.0850)
    assert result == []


def test_sanitize_predictions_preserves_good_data():
    """Test that sanitization preserves already-good predictions"""
    current = 1.0850

    good_prediction = {
        'predicted_price': 1.0900,
        'upper_bound': 1.0950,
        'lower_bound': 1.0850,
        'confidence': 0.85
    }

    result = sanitize_prediction_output([good_prediction], current)

    assert len(result) == 1
    # Should preserve good data (within tolerance)
    assert result[0]['predicted_price'] == pytest.approx(1.0900, rel=0.001)
    assert result[0]['confidence'] == 0.85


def test_confidence_normalization():
    """Test different confidence formats"""
    # 0-1 format
    assert validate_confidence(0.5) == 0.5

    # 0-100 format
    assert validate_confidence(50.0) == 0.5
    assert validate_confidence(100.0) == 1.0
    assert validate_confidence(0.0) == 0.0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
