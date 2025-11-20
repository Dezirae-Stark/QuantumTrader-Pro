"""
JSON Schema Validator for QuantumTrader-Pro API Responses
Validates prediction responses, signals, and market data against schemas.
"""

import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime
import jsonschema
from jsonschema import validate, ValidationError as JSONSchemaValidationError

logger = logging.getLogger(__name__)

# Path to schemas directory
SCHEMA_DIR = Path(__file__).parent.parent.parent / "schemas"


class ValidationError(Exception):
    """Custom validation error with detailed information"""
    def __init__(self, message: str, field: Optional[str] = None, value: Any = None):
        self.message = message
        self.field = field
        self.value = value
        super().__init__(self.message)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "error": "ValidationError",
            "message": self.message,
            "field": self.field,
            "value": str(self.value) if self.value is not None else None
        }


class SchemaValidator:
    """JSON Schema validator with caching"""

    def __init__(self):
        self._schemas: Dict[str, Dict[str, Any]] = {}
        self._load_schemas()

    def _load_schemas(self):
        """Load all JSON schemas from the schemas directory"""
        if not SCHEMA_DIR.exists():
            logger.warning(f"Schema directory not found: {SCHEMA_DIR}")
            return

        for schema_file in SCHEMA_DIR.glob("*.json"):
            try:
                with open(schema_file, 'r') as f:
                    schema_name = schema_file.stem
                    self._schemas[schema_name] = json.load(f)
                    logger.info(f"Loaded schema: {schema_name}")
            except Exception as e:
                logger.error(f"Failed to load schema {schema_file}: {e}")

    def validate(self, instance: Dict[str, Any], schema_name: str) -> None:
        """
        Validate a JSON instance against a named schema.

        Args:
            instance: The JSON object to validate
            schema_name: Name of the schema (without .json extension)

        Raises:
            ValidationError: If validation fails
        """
        if schema_name not in self._schemas:
            raise ValidationError(f"Schema '{schema_name}' not found")

        schema = self._schemas[schema_name]

        try:
            validate(instance=instance, schema=schema)
            logger.debug(f"Validation passed for schema: {schema_name}")
        except JSONSchemaValidationError as e:
            # Extract field path from validation error
            field_path = ".".join(str(p) for p in e.path) if e.path else "root"
            raise ValidationError(
                message=f"Schema validation failed: {e.message}",
                field=field_path,
                value=e.instance
            )

    def get_schema(self, schema_name: str) -> Optional[Dict[str, Any]]:
        """Get a loaded schema by name"""
        return self._schemas.get(schema_name)


# Global validator instance
_validator = SchemaValidator()


def validate_prediction_response(response: Dict[str, Any]) -> None:
    """
    Validate a prediction API response.

    Args:
        response: The prediction response dict

    Raises:
        ValidationError: If validation fails
    """
    # Ensure signals array exists (even if empty)
    if 'signals' not in response:
        response['signals'] = []
        logger.warning("Added missing 'signals' array to response")

    # Ensure signals is a list
    if not isinstance(response.get('signals'), list):
        raise ValidationError(
            message="'signals' must be an array",
            field="signals",
            value=type(response.get('signals')).__name__
        )

    # Validate against schema
    _validator.validate(response, "prediction_response")

    # Additional business logic validations
    _validate_prediction_logic(response)


def _validate_prediction_logic(response: Dict[str, Any]) -> None:
    """Additional logic-based validation for predictions"""

    prediction = response.get('prediction', {})

    # Check for valid price
    next_price = prediction.get('next_price')
    if next_price is not None:
        if next_price <= 0:
            raise ValidationError(
                message="Predicted price must be positive",
                field="prediction.next_price",
                value=next_price
            )

        if not is_finite(next_price):
            raise ValidationError(
                message="Predicted price must be finite",
                field="prediction.next_price",
                value=next_price
            )

    # Check bounds consistency
    upper = prediction.get('upper_bound')
    lower = prediction.get('lower_bound')
    if upper is not None and lower is not None:
        if upper <= lower:
            raise ValidationError(
                message="Upper bound must be greater than lower bound",
                field="prediction.bounds",
                value=f"upper={upper}, lower={lower}"
            )

        if next_price is not None:
            if not (lower <= next_price <= upper):
                logger.warning(
                    f"Predicted price {next_price} outside bounds [{lower}, {upper}]"
                )

    # Validate confidence range
    confidence = response.get('confidence')
    if confidence is not None:
        if not (0 <= confidence <= 100):
            raise ValidationError(
                message="Confidence must be between 0 and 100",
                field="confidence",
                value=confidence
            )

    # Validate signal confidence
    for i, signal in enumerate(response.get('signals', [])):
        sig_conf = signal.get('confidence')
        if sig_conf is not None and not (0 <= sig_conf <= 100):
            raise ValidationError(
                message=f"Signal {i} confidence must be between 0 and 100",
                field=f"signals[{i}].confidence",
                value=sig_conf
            )

        sig_strength = signal.get('strength')
        if sig_strength is not None and not (0 <= sig_strength <= 1):
            raise ValidationError(
                message=f"Signal {i} strength must be between 0 and 1",
                field=f"signals[{i}].strength",
                value=sig_strength
            )


def validate_signal(signal: Dict[str, Any]) -> None:
    """
    Validate a single trading signal.

    Args:
        signal: The signal dict

    Raises:
        ValidationError: If validation fails
    """
    required_fields = ['id', 'direction', 'strength', 'confidence', 'reason']

    for field in required_fields:
        if field not in signal:
            raise ValidationError(
                message=f"Required field '{field}' missing from signal",
                field=field
            )

    # Validate direction
    valid_directions = ['long', 'short', 'flat', 'BUY', 'SELL', 'HOLD']
    if signal['direction'] not in valid_directions:
        raise ValidationError(
            message=f"Invalid signal direction",
            field="direction",
            value=signal['direction']
        )

    # Validate strength (0-1)
    strength = signal.get('strength')
    if not isinstance(strength, (int, float)) or not (0 <= strength <= 1):
        raise ValidationError(
            message="Signal strength must be between 0 and 1",
            field="strength",
            value=strength
        )

    # Validate confidence (0-100)
    confidence = signal.get('confidence')
    if not isinstance(confidence, (int, float)) or not (0 <= confidence <= 100):
        raise ValidationError(
            message="Signal confidence must be between 0 and 100",
            field="confidence",
            value=confidence
        )


def is_finite(value: float) -> bool:
    """Check if a value is finite (not inf, not nan)"""
    import math
    return math.isfinite(value)


def create_standard_response(
    pair: str,
    timeframe: str,
    signals: List[Dict[str, Any]] = None,
    prediction: Dict[str, Any] = None,
    confidence: float = 0.0,
    **kwargs
) -> Dict[str, Any]:
    """
    Create a standard prediction response with proper structure.

    Args:
        pair: Trading pair symbol
        timeframe: Chart timeframe
        signals: List of signal dicts (default: empty list)
        prediction: Prediction dict
        confidence: Overall confidence score
        **kwargs: Additional fields (features, meta, chaos_analysis, etc.)

    Returns:
        Validated prediction response dict
    """
    response = {
        "pair": pair,
        "timeframe": timeframe,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "signals": signals if signals is not None else [],
        "prediction": prediction if prediction is not None else {
            "next_price": 0.0,
            "move_pct": 0.0,
            "volatility": 0.0,
            "state": "neutral"
        },
        "confidence": confidence
    }

    # Add optional fields
    response.update(kwargs)

    # Validate before returning
    validate_prediction_response(response)

    return response


def safe_validate_and_log(response: Dict[str, Any], schema_name: str = "prediction_response") -> bool:
    """
    Safely validate a response and log errors instead of raising.
    Useful for production error handling.

    Args:
        response: The response to validate
        schema_name: Schema name to validate against

    Returns:
        True if valid, False if invalid
    """
    try:
        _validator.validate(response, schema_name)
        return True
    except ValidationError as e:
        logger.error(f"Validation failed: {e.message} [field: {e.field}]")
        return False
    except Exception as e:
        logger.error(f"Unexpected validation error: {e}")
        return False


# ===================================================================
# Phase 4: Additional Schema Validators
# ===================================================================


def validate_market_snapshot(snapshot: Dict[str, Any]) -> None:
    """
    Validate a market snapshot.

    Args:
        snapshot: Market snapshot dict

    Raises:
        ValidationError: If validation fails
    """
    _validator.validate(snapshot, "market_snapshot")

    # Additional logic validation
    bid = snapshot.get('bid')
    ask = snapshot.get('ask')

    if bid is not None and ask is not None:
        if ask <= bid:
            raise ValidationError(
                message="Ask price must be greater than bid price",
                field="ask",
                value=f"bid={bid}, ask={ask}"
            )

        # Calculate spread and verify
        expected_spread = ask - bid
        if 'spread' in snapshot:
            if abs(snapshot['spread'] - expected_spread) > 0.0001:
                logger.warning(
                    f"Spread mismatch: provided={snapshot['spread']}, "
                    f"calculated={expected_spread:.5f}"
                )

    # Verify mid price
    if 'mid' in snapshot and bid is not None and ask is not None:
        expected_mid = (bid + ask) / 2
        if abs(snapshot['mid'] - expected_mid) > 0.0001:
            raise ValidationError(
                message="Mid price calculation incorrect",
                field="mid",
                value=f"provided={snapshot['mid']}, expected={expected_mid:.5f}"
            )


def validate_signal_object(signal: Dict[str, Any]) -> None:
    """
    Validate a standalone signal object.

    Args:
        signal: Signal dict

    Raises:
        ValidationError: If validation fails
    """
    _validator.validate(signal, "signal_object")

    # Additional logic validation
    direction = signal.get('direction')
    entry_price = signal.get('entry_price')
    stop_loss = signal.get('stop_loss')
    take_profit = signal.get('take_profit')

    # Validate stop loss placement
    if direction == 'long' and stop_loss is not None and entry_price is not None:
        if stop_loss >= entry_price:
            raise ValidationError(
                message="For long signals, stop loss must be below entry price",
                field="stop_loss",
                value=f"entry={entry_price}, sl={stop_loss}"
            )

    if direction == 'short' and stop_loss is not None and entry_price is not None:
        if stop_loss <= entry_price:
            raise ValidationError(
                message="For short signals, stop loss must be above entry price",
                field="stop_loss",
                value=f"entry={entry_price}, sl={stop_loss}"
            )

    # Validate take profit placement
    if direction == 'long' and take_profit is not None and entry_price is not None:
        if take_profit <= entry_price:
            raise ValidationError(
                message="For long signals, take profit must be above entry price",
                field="take_profit",
                value=f"entry={entry_price}, tp={take_profit}"
            )

    if direction == 'short' and take_profit is not None and entry_price is not None:
        if take_profit >= entry_price:
            raise ValidationError(
                message="For short signals, take profit must be below entry price",
                field="take_profit",
                value=f"entry={entry_price}, tp={take_profit}"
            )

    # Validate risk/reward ratio
    if 'risk_reward_ratio' in signal:
        rr = signal['risk_reward_ratio']
        if rr is not None and rr <= 0:
            raise ValidationError(
                message="Risk/reward ratio must be positive",
                field="risk_reward_ratio",
                value=rr
            )


def validate_order_request(order: Dict[str, Any]) -> None:
    """
    Validate an order placement request.

    Args:
        order: Order request dict

    Raises:
        ValidationError: If validation fails
    """
    _validator.validate(order, "order_request")

    # Additional business logic validation
    order_type = order.get('order_type')
    side = order.get('side')

    # Ensure price is provided for limit orders
    if order_type in ['limit', 'stop_limit'] and 'price' not in order:
        raise ValidationError(
            message=f"{order_type} orders require a price",
            field="price"
        )

    # Ensure stop_price is provided for stop orders
    if order_type in ['stop', 'stop_limit'] and 'stop_price' not in order:
        raise ValidationError(
            message=f"{order_type} orders require a stop_price",
            field="stop_price"
        )

    # Validate stop loss/take profit placement
    entry_price = order.get('price') or order.get('stop_price')
    stop_loss = order.get('stop_loss')
    take_profit = order.get('take_profit')

    if entry_price and stop_loss:
        if side == 'buy' and stop_loss >= entry_price:
            logger.warning(
                f"Buy order stop loss {stop_loss} should be below entry {entry_price}"
            )
        elif side == 'sell' and stop_loss <= entry_price:
            logger.warning(
                f"Sell order stop loss {stop_loss} should be above entry {entry_price}"
            )

    if entry_price and take_profit:
        if side == 'buy' and take_profit <= entry_price:
            logger.warning(
                f"Buy order take profit {take_profit} should be above entry {entry_price}"
            )
        elif side == 'sell' and take_profit >= entry_price:
            logger.warning(
                f"Sell order take profit {take_profit} should be below entry {entry_price}"
            )


def validate_order_response(order: Dict[str, Any]) -> None:
    """
    Validate an order response from broker.

    Args:
        order: Order response dict

    Raises:
        ValidationError: If validation fails
    """
    _validator.validate(order, "order_response")

    # Additional validation
    quantity = order.get('quantity', 0)
    filled_quantity = order.get('filled_quantity', 0)
    remaining_quantity = order.get('remaining_quantity', 0)

    # Verify quantity consistency
    if filled_quantity + remaining_quantity != quantity:
        expected_remaining = quantity - filled_quantity
        if abs(remaining_quantity - expected_remaining) > 0.0001:
            logger.warning(
                f"Quantity mismatch: filled={filled_quantity}, "
                f"remaining={remaining_quantity}, total={quantity}"
            )

    # Verify status consistency
    status = order.get('status')
    if status == 'filled' and filled_quantity < quantity:
        logger.warning(
            f"Order marked as filled but quantity mismatch: "
            f"filled={filled_quantity}, total={quantity}"
        )

    if status == 'pending' and filled_quantity > 0:
        logger.warning(
            f"Order marked as pending but has fills: filled={filled_quantity}"
        )


def validate_account_info(account: Dict[str, Any]) -> None:
    """
    Validate account information.

    Args:
        account: Account info dict

    Raises:
        ValidationError: If validation fails
    """
    _validator.validate(account, "account_info")

    # Additional validation
    balance = account.get('balance')
    equity = account.get('equity')
    margin = account.get('margin', 0)
    free_margin = account.get('free_margin', 0)

    # Verify equity >= balance - used_margin (approximately)
    if balance is not None and equity is not None:
        if equity < 0:
            raise ValidationError(
                message="Equity cannot be negative",
                field="equity",
                value=equity
            )

    # Verify margin calculations
    if margin is not None and free_margin is not None and equity is not None:
        expected_free = equity - margin
        if abs(free_margin - expected_free) > 1.0:  # Allow small rounding errors
            logger.warning(
                f"Free margin mismatch: provided={free_margin}, "
                f"expected={expected_free:.2f} (equity={equity}, margin={margin})"
            )

    # Verify margin level
    if 'margin_level' in account:
        margin_level = account['margin_level']
        if margin > 0 and equity is not None:
            expected_level = (equity / margin) * 100
            if abs(margin_level - expected_level) > 1.0:
                logger.warning(
                    f"Margin level mismatch: provided={margin_level:.2f}%, "
                    f"expected={expected_level:.2f}%"
                )

    # Validate positions
    if 'positions' in account:
        for i, position in enumerate(account['positions']):
            try:
                _validate_position(position, i)
            except ValidationError as e:
                raise ValidationError(
                    message=f"Position {i} validation failed: {e.message}",
                    field=f"positions[{i}].{e.field}",
                    value=e.value
                )


def _validate_position(position: Dict[str, Any], index: int) -> None:
    """Validate a single position within account info"""
    side = position.get('side')
    open_price = position.get('open_price')
    current_price = position.get('current_price')
    profit = position.get('profit')

    # Verify profit calculation (approximate)
    if all([side, open_price, current_price, profit]) and 'quantity' in position:
        quantity = position['quantity']
        if side == 'buy':
            expected_profit = (current_price - open_price) * quantity
        else:  # sell
            expected_profit = (open_price - current_price) * quantity

        # Allow some tolerance for commission/swap
        if abs(profit - expected_profit) > abs(expected_profit) * 0.1:
            logger.warning(
                f"Position {index} profit mismatch: provided={profit:.2f}, "
                f"expected≈{expected_profit:.2f}"
            )
