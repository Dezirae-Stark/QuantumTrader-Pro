#!/usr/bin/env python3
"""
Quantum Predictor Daemon v2 - With Schema Validation and Config Integration
Real-time Market Prediction Service with standardized JSON responses
"""

import os
import sys
import json
import time
import argparse
import logging
import uuid
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.quantum_predictor import QuantumMarketPredictor, ChaosTheoryAnalyzer
from backend.config_loader import get_config
from backend.validators.json_validator import (
    validate_prediction_response,
    create_standard_response,
    ValidationError
)
from brokers import create_broker_provider, BrokerError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/daemon.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class PredictorDaemonV2:
    """
    Enhanced daemon service with:
    - Configuration-driven data source selection
    - JSON schema validation
    - Proper error handling
    - Standardized response format
    """

    def __init__(self, poll_interval=10, config_file=None):
        # Load configuration
        self.config = get_config(config_file)
        self.poll_interval = poll_interval

        # Initialize predictors
        self.quantum = QuantumMarketPredictor()
        self.chaos = ChaosTheoryAnalyzer()

        # Get paths from config
        project_root = Path(__file__).parent.parent
        self.bridge_data_dir = project_root / "bridge" / "data"
        self.predictions_dir = project_root / "predictions"

        # Ensure directories exist
        os.makedirs(self.bridge_data_dir, exist_ok=True)
        os.makedirs(self.predictions_dir, exist_ok=True)
        os.makedirs('logs', exist_ok=True)

        # Configuration checks
        self.use_synthetic = self.config.is_synthetic_data_enabled()
        self.fail_on_error = self.config.should_fail_on_data_error()
        self.strict_validation = self.config.is_strict_validation_enabled()

        # Initialize broker provider
        self.broker = None
        try:
            broker_provider = self.config.get_broker_provider()
            broker_config = self.config.get_broker_config()

            # Add data_dir to broker config for MT4 bridge
            if broker_provider in ['mt4', 'mt4_bridge']:
                broker_config['data_dir'] = str(self.bridge_data_dir)

            self.broker = create_broker_provider(broker_provider, broker_config)
            self.broker.connect()
            logger.info(f"✅ Connected to broker: {broker_provider}")
        except Exception as e:
            logger.warning(f"⚠️  Broker connection failed: {e}")
            if not self.use_synthetic and self.fail_on_error:
                raise
            logger.info("Continuing with file-based data fallback")

        logger.info("=" * 70)
        logger.info("🚀 Quantum Predictor Daemon V2 Initialized")
        logger.info("=" * 70)
        logger.info(f"Environment: {self.config.get_env()}")
        logger.info(f"Broker: {self.config.get_broker_provider()}")
        logger.info(f"Synthetic data: {self.use_synthetic}")
        logger.info(f"Fail on data error: {self.fail_on_error}")
        logger.info(f"Strict validation: {self.strict_validation}")
        logger.info(f"Monitoring: {self.bridge_data_dir}")
        logger.info(f"Output to: {self.predictions_dir}")
        logger.info("=" * 70)

        # Validate configuration
        if self.config.is_production() and self.use_synthetic:
            raise RuntimeError(
                "CRITICAL: Cannot use synthetic data in production mode!"
            )

    def load_market_data(self, symbol):
        """
        Load market data from configured source (broker or synthetic).

        Args:
            symbol: Trading pair symbol

        Returns:
            pandas.Series of prices, or None if unavailable
        """
        # Try loading from broker provider first
        if self.broker and self.broker.is_connected():
            try:
                candles = self.broker.get_ohlc(symbol, 'M5', limit=500)

                if candles and len(candles) >= 50:
                    # Convert to pandas Series
                    df = pd.DataFrame([{
                        'timestamp': c.timestamp,
                        'price': c.typical_price  # (H+L+C)/3
                    } for c in candles])
                    df = df.set_index('timestamp')

                    logger.info(f"✅ {symbol}: Loaded {len(df)} candles from broker")
                    return df['price']
                else:
                    logger.warning(f"{symbol}: Insufficient data from broker ({len(candles) if candles else 0} candles)")

            except BrokerError as e:
                logger.error(f"Broker error for {symbol}: {e}")
            except Exception as e:
                logger.error(f"Error loading {symbol} from broker: {e}")

        # Fallback to file-based data
        market_file = self.bridge_data_dir / f"{symbol}_market.json"
        if market_file.exists():
            try:
                with open(market_file, 'r') as f:
                    data = json.load(f)

                if data and len(data) >= 50:
                    # Convert to pandas Series
                    df = pd.DataFrame(data)
                    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s')
                    df = df.set_index('timestamp')

                    # Use mid price (bid + ask) / 2
                    df['price'] = (df['bid'] + df['ask']) / 2.0

                    logger.info(f"✅ {symbol}: Loaded {len(df)} candles from file")
                    return df['price']

            except Exception as e:
                logger.error(f"Error loading {symbol} from file: {e}")

        # Final fallback behavior
        if self.use_synthetic:
            logger.warning(f"⚠️  {symbol}: Using SYNTHETIC data (demo/dev mode)")
            return self._generate_synthetic_data(symbol)

        elif self.fail_on_error:
            logger.error(f"❌ {symbol}: No broker data and synthetic disabled")
            return None

        else:
            logger.warning(f"⚠️  {symbol}: No data available, skipping")
            return None

    def _generate_synthetic_data(self, symbol, length=200):
        """
        Generate synthetic market data for demo/testing.
        Only called when USE_SYNTHETIC_DATA=true.
        """
        # Get realistic base price for symbol
        base_prices = {
            'EURUSD': 1.0850,
            'GBPUSD': 1.2650,
            'USDJPY': 149.50,
            'AUDUSD': 0.6550,
            'USDCAD': 1.3850,
            'XAUUSD': 2050.0,
            'BTCUSD': 43000.0
        }

        base_price = base_prices.get(symbol, 1.0)

        # Generate random walk with drift
        np.random.seed(int(time.time()) % 10000)
        returns = np.random.normal(0.0001, 0.01, length)
        prices = base_price * np.exp(np.cumsum(returns))

        # Create time index
        timestamps = pd.date_range(
            end=datetime.utcnow(),
            periods=length,
            freq='5min'
        )

        return pd.Series(prices, index=timestamps)

    def generate_prediction_response(self, symbol, price_data, timeframe='M5'):
        """
        Generate standardized prediction response with validation.

        Args:
            symbol: Trading pair symbol
            price_data: pandas.Series of price data
            timeframe: Chart timeframe

        Returns:
            Validated prediction response dict
        """
        try:
            cycle_id = str(uuid.uuid4())
            start_time = time.time()

            logger.info(f"📊 {symbol}: Generating predictions...")

            # Get quantum predictions
            predictions = self.quantum.predict_next_candles(price_data, n_candles=8)

            # Get superposition states
            states = self.quantum.quantum_superposition_prediction(price_data)

            # Get chaos analysis
            attractor = self.chaos.detect_strange_attractor(price_data)

            # Calculate probabilities
            bullish_prob = states['strong_bull']['probability'] + states['bull']['probability']
            bearish_prob = states['strong_bear']['probability'] + states['bear']['probability']
            neutral_prob = states['neutral']['probability']

            # Determine signal direction
            confidence_threshold = self.config.get('ML_CONFIG.confidence_threshold', 70.0) / 100.0

            signals = []

            if bullish_prob > confidence_threshold:
                direction = "long"
                signal_type = "BUY"
                confidence = bullish_prob * 100
                reason = f"Strong bullish quantum state detected ({bullish_prob:.1%} probability)"

            elif bearish_prob > confidence_threshold:
                direction = "short"
                signal_type = "SELL"
                confidence = bearish_prob * 100
                reason = f"Strong bearish quantum state detected ({bearish_prob:.1%} probability)"

            else:
                direction = "flat"
                signal_type = "HOLD"
                confidence = max(bullish_prob, bearish_prob, neutral_prob) * 100
                reason = "No strong directional bias - market in neutral state"

            # Create signal if actionable
            if direction != "flat":
                signal = {
                    "id": f"{symbol}-{cycle_id[:8]}",
                    "direction": direction,
                    "strength": float(max(bullish_prob, bearish_prob)),
                    "confidence": float(confidence),
                    "reason": reason,
                    "entry_price": float(price_data.iloc[-1]),
                    "stop_loss": None,  # Calculate in risk manager
                    "take_profit": None,  # Calculate in risk manager
                    "risk_reward_ratio": None
                }
                signals.append(signal)

            # Get next candle prediction
            next_candle = predictions[0]
            next_price = float(next_candle['predicted_price'])
            current_price = float(price_data.iloc[-1])

            # Sanity check prediction
            max_move_pct = self.config.get('ML_CONFIG.max_price_move_pct', 10.0) / 100.0
            if abs(next_price - current_price) / current_price > max_move_pct:
                logger.warning(
                    f"{symbol}: Prediction {next_price} too far from current {current_price}, "
                    f"clamping to {max_move_pct:.1%} max move"
                )
                if next_price > current_price:
                    next_price = current_price * (1 + max_move_pct)
                else:
                    next_price = current_price * (1 - max_move_pct)

            # Ensure positive price
            next_price = max(next_price, current_price * 0.5)

            # Build prediction object
            prediction = {
                "next_price": float(next_price),
                "move_pct": float((next_price - current_price) / current_price * 100),
                "volatility": float(price_data.pct_change().std() * 100),
                "state": "bull" if bullish_prob > bearish_prob else "bear" if bearish_prob > bullish_prob else "neutral",
                "upper_bound": float(next_candle['upper_bound']),
                "lower_bound": float(next_candle['lower_bound'])
            }

            # Build chaos analysis
            chaos_analysis = {
                "is_strange_attractor": bool(attractor['is_attractor']),
                "fractal_dimension": float(attractor['fractal_dimension']),
                "lyapunov_exponent": float(attractor['lyapunov_exponent']),
                "predictability": attractor['predictability']
            }

            # Build metadata
            meta = {
                "model_version": self.config.get('ML_CONFIG.model_version', '2.1.0'),
                "cycle_id": cycle_id,
                "data_source": "synthetic" if self.use_synthetic else "broker",
                "prediction_latency_ms": int((time.time() - start_time) * 1000)
            }

            # Create standardized response
            response = create_standard_response(
                pair=symbol,
                timeframe=timeframe,
                signals=signals,
                prediction=prediction,
                confidence=float(confidence),
                chaos_analysis=chaos_analysis,
                meta=meta
            )

            logger.info(
                f"✅ {symbol}: {signal_type} signal @ {confidence:.1f}% confidence "
                f"(next: {next_price:.5f}, {prediction['move_pct']:+.2f}%)"
            )

            return response

        except ValidationError as e:
            logger.error(f"❌ {symbol}: Validation error - {e.message} [{e.field}]")
            if self.strict_validation:
                raise
            return None

        except Exception as e:
            logger.error(f"❌ {symbol}: Prediction error - {e}", exc_info=True)
            return None

    def save_predictions(self, predictions):
        """
        Save predictions to file for API serving.

        Args:
            predictions: List of prediction response dicts
        """
        try:
            output = {
                "predictions": predictions,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "total": len(predictions),
                "version": "2.0"
            }

            output_file = self.predictions_dir / 'predictions_output.json'
            with open(output_file, 'w') as f:
                json.dump(output, f, indent=2)

            logger.info(f"💾 Saved {len(predictions)} predictions to {output_file}")
            return True

        except Exception as e:
            logger.error(f"Error saving predictions: {e}")
            return False

    def run(self, symbols=None):
        """Main daemon loop"""
        if symbols is None:
            # Get symbols from config or use defaults
            symbols = list(self.config.get_symbol_map().keys())
            if not symbols:
                symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'XAUUSD']

        logger.info("=" * 70)
        logger.info("🔬 Starting Prediction Loop")
        logger.info("=" * 70)
        logger.info(f"Symbols: {', '.join(symbols)}")
        logger.info(f"Poll interval: {self.poll_interval}s")
        logger.info("=" * 70)

        iteration = 0

        while True:
            try:
                iteration += 1
                logger.info(f"\n{'=' * 70}")
                logger.info(f"🔄 Prediction Cycle #{iteration}")
                logger.info(f"{'=' * 70}")

                predictions = []

                for symbol in symbols:
                    # Load market data
                    price_data = self.load_market_data(symbol)

                    if price_data is None or len(price_data) < 50:
                        logger.debug(f"Skipping {symbol}: insufficient data")
                        continue

                    # Generate prediction
                    prediction = self.generate_prediction_response(symbol, price_data)

                    if prediction:
                        predictions.append(prediction)

                # Save predictions
                if predictions:
                    self.save_predictions(predictions)
                    logger.info(f"\n✅ Cycle #{iteration} complete: {len(predictions)} predictions")
                else:
                    logger.warning(f"\n⚠️  Cycle #{iteration}: No predictions (waiting for data)")

                # Sleep
                logger.info(f"😴 Sleeping {self.poll_interval}s...\n")
                time.sleep(self.poll_interval)

            except KeyboardInterrupt:
                logger.info("\n🛑 Daemon stopped by user")
                break

            except Exception as e:
                logger.error(f"❌ Error in main loop: {e}", exc_info=True)
                time.sleep(self.poll_interval)


def main():
    parser = argparse.ArgumentParser(description='Quantum Predictor Daemon V2')
    parser.add_argument('--symbols', type=str, help='Comma-separated symbols')
    parser.add_argument('--interval', type=int, default=10, help='Poll interval (seconds)')
    parser.add_argument('--config', type=str, help='Config file path')

    args = parser.parse_args()

    # Parse symbols
    symbols = None
    if args.symbols:
        symbols = [s.strip().upper() for s in args.symbols.split(',')]

    # Create daemon
    daemon = PredictorDaemonV2(
        poll_interval=args.interval,
        config_file=args.config
    )

    # Run
    daemon.run(symbols=symbols)


if __name__ == '__main__':
    main()
