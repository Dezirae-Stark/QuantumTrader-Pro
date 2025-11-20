"""
ML Prediction Post-Processing and Sanity Checks
Ensures predictions are numerically valid, positive, finite, and realistic

This module prevents common ML prediction errors:
- Negative prices
- Infinite/NaN values
- Unrealistic price movements
- Invalid confidence scores
- Inconsistent bounds
"""

import numpy as np
import math
import logging
from typing import Dict, Any, List, Optional, Union

logger = logging.getLogger(__name__)


def is_valid_price(price: Union[float, int]) -> bool:
    """
    Check if price is valid (positive, finite).

    Args:
        price: Price value to check

    Returns:
        True if valid (positive and finite)

    Example:
        >>> is_valid_price(1.0850)
        True
        >>> is_valid_price(-1.5)
        False
        >>> is_valid_price(float('inf'))
        False
    """
    if not isinstance(price, (int, float)):
        return False

    if not math.isfinite(price):
        return False

    if price <= 0:
        return False

    return True


def is_finite(value: Union[float, int]) -> bool:
    """
    Check if value is finite (not inf, not nan).

    Args:
        value: Numeric value to check

    Returns:
        True if finite
    """
    return math.isfinite(float(value))


def clamp_value(value: float, min_val: float, max_val: float) -> float:
    """
    Clamp value to range [min_val, max_val].

    Args:
        value: Value to clamp
        min_val: Minimum allowed value
        max_val: Maximum allowed value

    Returns:
        Clamped value

    Example:
        >>> clamp_value(150, 0, 100)
        100
        >>> clamp_value(-10, 0, 100)
        0
        >>> clamp_value(50, 0, 100)
        50
    """
    return max(min_val, min(max_val, value))


def clamp_prediction_to_range(
    current_price: float,
    predicted_price: float,
    max_pct_move: float = 0.10
) -> float:
    """
    Clamp predicted price to reasonable range based on current price.

    Prevents absurd predictions like 10x or 0.1x the current price.

    Args:
        current_price: Current market price
        predicted_price: ML-predicted price
        max_pct_move: Maximum allowed percentage move (default 10%)

    Returns:
        Clamped prediction

    Example:
        >>> clamp_prediction_to_range(1.0850, 1.2000, 0.10)  # Too high
        1.1935
        >>> clamp_prediction_to_range(1.0850, 1.0900, 0.10)  # OK
        1.0900
    """
    if not is_valid_price(current_price):
        logger.error(f"Invalid current price: {current_price}")
        return abs(current_price) if current_price != 0 else 1.0

    if not is_valid_price(predicted_price):
        logger.warning(f"Invalid prediction {predicted_price}, using current price")
        return current_price

    # Calculate bounds
    max_up = current_price * (1 + max_pct_move)
    max_down = current_price * (1 - max_pct_move)

    # Clamp to bounds
    if predicted_price > max_up:
        logger.warning(
            f"Prediction {predicted_price:.5f} too high (>{max_pct_move:.0%} above {current_price:.5f}), "
            f"clamping to {max_up:.5f}"
        )
        return max_up

    if predicted_price < max_down:
        logger.warning(
            f"Prediction {predicted_price:.5f} too low (>{max_pct_move:.0%} below {current_price:.5f}), "
            f"clamping to {max_down:.5f}"
        )
        return max_down

    return predicted_price


def validate_prediction_bounds(
    prediction: float,
    upper_bound: float,
    lower_bound: float,
    current_price: float,
    max_spread_pct: float = 0.20
) -> Dict[str, float]:
    """
    Validate and fix prediction bounds.

    Ensures:
    1. All values are positive and finite
    2. lower_bound < prediction < upper_bound
    3. Bounds are reasonable (not too wide)

    Args:
        prediction: Predicted price
        upper_bound: Upper confidence bound
        lower_bound: Lower confidence bound
        current_price: Current market price
        max_spread_pct: Maximum allowed spread between bounds (default 20%)

    Returns:
        Dict with validated values: predicted_price, upper_bound, lower_bound

    Example:
        >>> validate_prediction_bounds(1.0850, 1.0900, 1.0800, 1.0845)
        {'predicted_price': 1.0850, 'upper_bound': 1.0900, 'lower_bound': 1.0800}
    """
    # Ensure all are valid prices
    if not is_valid_price(prediction):
        logger.warning(f"Invalid prediction {prediction}, using current price")
        prediction = current_price

    if not is_valid_price(upper_bound):
        logger.warning(f"Invalid upper bound {upper_bound}, setting to current + 5%")
        upper_bound = current_price * 1.05

    if not is_valid_price(lower_bound):
        logger.warning(f"Invalid lower bound {lower_bound}, setting to current - 5%")
        lower_bound = current_price * 0.95

    # Ensure bounds are ordered correctly
    if lower_bound >= upper_bound:
        logger.warning(
            f"Lower bound {lower_bound:.5f} >= upper bound {upper_bound:.5f}, fixing"
        )
        spread = abs(current_price * 0.05)
        lower_bound = current_price - spread
        upper_bound = current_price + spread

    # Check if bounds are too wide
    spread_pct = (upper_bound - lower_bound) / current_price
    if spread_pct > max_spread_pct:
        logger.warning(
            f"Bounds too wide ({spread_pct:.1%}), clamping to {max_spread_pct:.0%}"
        )
        center = (upper_bound + lower_bound) / 2
        half_spread = current_price * max_spread_pct / 2
        lower_bound = center - half_spread
        upper_bound = center + half_spread

    # Ensure prediction is within bounds
    if not (lower_bound <= prediction <= upper_bound):
        logger.warning(
            f"Prediction {prediction:.5f} outside bounds [{lower_bound:.5f}, {upper_bound:.5f}], "
            f"clamping"
        )
        prediction = clamp_value(prediction, lower_bound, upper_bound)

    return {
        'predicted_price': prediction,
        'upper_bound': upper_bound,
        'lower_bound': lower_bound
    }


def validate_confidence(confidence: float) -> float:
    """
    Validate and fix confidence score (must be 0-1 or 0-100).

    Args:
        confidence: Confidence value

    Returns:
        Valid confidence in [0, 1] range

    Example:
        >>> validate_confidence(0.85)
        0.85
        >>> validate_confidence(85)  # Percentage
        0.85
        >>> validate_confidence(150)  # Out of range
        1.0
    """
    if not is_finite(confidence):
        logger.warning(f"Invalid confidence {confidence}, setting to 0.5")
        return 0.5

    # If confidence is > 1, assume it's a percentage (0-100)
    if confidence > 1:
        confidence = confidence / 100.0

    # Clamp to [0, 1]
    if confidence < 0 or confidence > 1:
        logger.warning(f"Confidence {confidence} out of range, clamping")
        confidence = clamp_value(confidence, 0.0, 1.0)

    return confidence


def sanitize_candle_prediction(
    prediction: Dict[str, Any],
    current_price: float,
    max_move_pct: float = 0.10
) -> Dict[str, Any]:
    """
    Sanitize a single candle prediction.

    Args:
        prediction: Prediction dict with predicted_price, upper_bound, lower_bound, confidence
        current_price: Current market price
        max_move_pct: Maximum allowed price move percentage

    Returns:
        Sanitized prediction dict
    """
    # Clamp predicted price
    predicted_price = prediction.get('predicted_price', current_price)
    predicted_price = clamp_prediction_to_range(
        current_price,
        predicted_price,
        max_move_pct
    )
    prediction['predicted_price'] = predicted_price

    # Validate bounds
    validated = validate_prediction_bounds(
        predicted_price,
        prediction.get('upper_bound', current_price * 1.05),
        prediction.get('lower_bound', current_price * 0.95),
        current_price
    )
    prediction.update(validated)

    # Validate confidence
    if 'confidence' in prediction:
        prediction['confidence'] = validate_confidence(prediction['confidence'])

    return prediction


def sanitize_prediction_output(
    predictions: List[Dict[str, Any]],
    current_price: float,
    max_move_pct: float = 0.10
) -> List[Dict[str, Any]]:
    """
    Sanitize a list of candle predictions.

    Ensures all predictions are:
    - Positive prices
    - Finite values
    - Within reasonable movement range
    - With valid confidence scores

    Args:
        predictions: List of prediction dicts
        current_price: Current market price
        max_move_pct: Maximum allowed move percentage (default 10%)

    Returns:
        Sanitized prediction list

    Example:
        >>> predictions = [
        ...     {'predicted_price': 1.0900, 'confidence': 0.85, 'upper_bound': 1.0950, 'lower_bound': 1.0850}
        ... ]
        >>> sanitized = sanitize_prediction_output(predictions, 1.0850, 0.10)
    """
    if not predictions:
        return []

    sanitized = []

    for i, pred in enumerate(predictions):
        try:
            # Sanitize this prediction
            sanitized_pred = sanitize_candle_prediction(pred, current_price, max_move_pct)
            sanitized.append(sanitized_pred)

        except Exception as e:
            logger.error(f"Error sanitizing prediction {i}: {e}")
            # Create safe default prediction
            sanitized.append({
                'predicted_price': current_price,
                'upper_bound': current_price * 1.05,
                'lower_bound': current_price * 0.95,
                'confidence': 0.5
            })

    return sanitized


def check_price_sanity(
    price: float,
    symbol: str = 'UNKNOWN',
    min_price: Optional[float] = None,
    max_price: Optional[float] = None
) -> bool:
    """
    Check if price is sane for a given symbol.

    Args:
        price: Price to check
        symbol: Trading symbol (for context in logs)
        min_price: Minimum reasonable price (optional)
        max_price: Maximum reasonable price (optional)

    Returns:
        True if price seems reasonable

    Example:
        >>> check_price_sanity(1.0850, 'EURUSD', 0.5, 2.0)
        True
        >>> check_price_sanity(100.0, 'EURUSD', 0.5, 2.0)
        False
    """
    if not is_valid_price(price):
        logger.error(f"{symbol}: Invalid price {price}")
        return False

    if min_price and price < min_price:
        logger.warning(f"{symbol}: Price {price} below minimum {min_price}")
        return False

    if max_price and price > max_price:
        logger.warning(f"{symbol}: Price {price} above maximum {max_price}")
        return False

    return True


def get_reasonable_price_range(symbol: str) -> tuple[float, float]:
    """
    Get reasonable price range for a symbol.

    Args:
        symbol: Trading symbol

    Returns:
        Tuple of (min_price, max_price)

    Example:
        >>> get_reasonable_price_range('EURUSD')
        (0.5, 2.0)
        >>> get_reasonable_price_range('XAUUSD')
        (500.0, 5000.0)
    """
    # Known ranges for common symbols
    ranges = {
        'EURUSD': (0.5, 2.0),
        'GBPUSD': (0.5, 2.5),
        'USDJPY': (50.0, 200.0),
        'AUDUSD': (0.3, 1.5),
        'USDCAD': (0.8, 1.8),
        'USDCHF': (0.6, 1.5),
        'NZDUSD': (0.3, 1.2),
        'XAUUSD': (500.0, 5000.0),  # Gold
        'XAGUSD': (5.0, 100.0),  # Silver
        'BTCUSD': (1000.0, 150000.0),  # Bitcoin
        'ETHUSD': (100.0, 10000.0),  # Ethereum
    }

    return ranges.get(symbol, (0.0, float('inf')))


def enforce_price_sanity(
    price: float,
    symbol: str,
    fallback_price: Optional[float] = None
) -> float:
    """
    Enforce price sanity, return fallback if invalid.

    Args:
        price: Price to check
        symbol: Trading symbol
        fallback_price: Price to return if invalid (default: reasonable mid-range)

    Returns:
        Valid price

    Example:
        >>> enforce_price_sanity(1.0850, 'EURUSD')
        1.0850
        >>> enforce_price_sanity(-1.5, 'EURUSD', fallback_price=1.0800)
        1.0800
    """
    min_price, max_price = get_reasonable_price_range(symbol)

    if not check_price_sanity(price, symbol, min_price, max_price):
        if fallback_price and check_price_sanity(fallback_price, symbol, min_price, max_price):
            logger.warning(f"{symbol}: Using fallback price {fallback_price}")
            return fallback_price
        else:
            # Use mid-range as fallback
            safe_price = (min_price + max_price) / 2 if max_price != float('inf') else min_price * 2
            logger.warning(f"{symbol}: Using safe default price {safe_price}")
            return safe_price

    return price


def detect_outliers(
    predictions: List[float],
    threshold: float = 3.0
) -> List[int]:
    """
    Detect outlier predictions using z-score.

    Args:
        predictions: List of predicted prices
        threshold: Z-score threshold (default 3.0)

    Returns:
        List of indices of outliers

    Example:
        >>> predictions = [1.0850, 1.0855, 1.0860, 1.5000]  # Last is outlier
        >>> detect_outliers(predictions)
        [3]
    """
    if len(predictions) < 3:
        return []

    predictions_array = np.array(predictions)
    mean = np.mean(predictions_array)
    std = np.std(predictions_array)

    if std == 0:
        return []

    z_scores = np.abs((predictions_array - mean) / std)
    outliers = np.where(z_scores > threshold)[0].tolist()

    if outliers:
        logger.warning(f"Detected {len(outliers)} outlier predictions: {outliers}")

    return outliers


def remove_outliers(
    predictions: List[Dict[str, Any]],
    threshold: float = 3.0
) -> List[Dict[str, Any]]:
    """
    Remove outlier predictions from list.

    Args:
        predictions: List of prediction dicts
        threshold: Z-score threshold

    Returns:
        Cleaned prediction list
    """
    if len(predictions) < 3:
        return predictions

    prices = [p.get('predicted_price', 0) for p in predictions]
    outlier_indices = detect_outliers(prices, threshold)

    if not outlier_indices:
        return predictions

    # Remove outliers
    cleaned = [p for i, p in enumerate(predictions) if i not in outlier_indices]

    logger.info(f"Removed {len(outlier_indices)} outlier predictions")

    return cleaned


# Convenience function for complete prediction sanitization
def sanitize_predictions(
    predictions: List[Dict[str, Any]],
    current_price: float,
    symbol: str = 'UNKNOWN',
    max_move_pct: float = 0.10,
    remove_outliers_enabled: bool = True
) -> List[Dict[str, Any]]:
    """
    Complete prediction sanitization pipeline.

    Args:
        predictions: Raw prediction list
        current_price: Current market price
        symbol: Trading symbol
        max_move_pct: Maximum allowed price move
        remove_outliers_enabled: Whether to remove outliers

    Returns:
        Fully sanitized predictions
    """
    if not predictions:
        return []

    # Step 1: Sanitize each prediction
    sanitized = sanitize_prediction_output(predictions, current_price, max_move_pct)

    # Step 2: Remove outliers if enabled
    if remove_outliers_enabled and len(sanitized) > 3:
        sanitized = remove_outliers(sanitized)

    # Step 3: Enforce price sanity for symbol
    for pred in sanitized:
        pred['predicted_price'] = enforce_price_sanity(
            pred['predicted_price'],
            symbol,
            fallback_price=current_price
        )

    logger.info(f"{symbol}: Sanitized {len(sanitized)} predictions")

    return sanitized
