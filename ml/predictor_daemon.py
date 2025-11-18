#!/usr/bin/env python3
"""
Quantum Predictor Daemon - Real-time Market Prediction Service
Consumes real market data from bridge and generates trading signals
"""

import os
import sys
import json
import time
import argparse
import logging
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.quantum_predictor import QuantumMarketPredictor, ChaosTheoryAnalyzer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ml/logs/daemon.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class PredictorDaemon:
    """Daemon service that continuously monitors market data and generates predictions"""

    def __init__(self, bridge_data_dir='bridge/data', predictions_dir='predictions', poll_interval=10):
        self.bridge_data_dir = Path(bridge_data_dir)
        self.predictions_dir = Path(predictions_dir)
        self.poll_interval = poll_interval

        self.quantum = QuantumMarketPredictor()
        self.chaos = ChaosTheoryAnalyzer()

        # Ensure directories exist
        os.makedirs(self.bridge_data_dir, exist_ok=True)
        os.makedirs(self.predictions_dir, exist_ok=True)
        os.makedirs('ml/logs', exist_ok=True)

        logger.info("Predictor Daemon initialized")
        logger.info(f"Monitoring: {self.bridge_data_dir}")
        logger.info(f"Output to: {self.predictions_dir}")

    def load_market_data(self, symbol):
        """Load real market data from bridge"""
        market_file = self.bridge_data_dir / f"{symbol}_market.json"

        if not market_file.exists():
            logger.warning(f"No market data found for {symbol}")
            return None

        try:
            with open(market_file, 'r') as f:
                data = json.load(f)

            if not data or len(data) < 50:
                logger.warning(f"Insufficient data for {symbol}: {len(data)} candles")
                return None

            # Convert to pandas Series
            df = pd.DataFrame(data)
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s')
            df = df.set_index('timestamp')

            # Use mid price (bid + ask) / 2
            df['price'] = (df['bid'] + df['ask']) / 2.0

            return df['price']

        except Exception as e:
            logger.error(f"Error loading market data for {symbol}: {e}")
            return None

    def generate_predictions(self, symbol, price_data):
        """Generate predictions for a symbol"""
        try:
            logger.info(f"Generating predictions for {symbol}")

            # Get predictions
            predictions = self.quantum.predict_next_candles(price_data, n_candles=8)

            # Get superposition states
            states = self.quantum.quantum_superposition_prediction(price_data)

            # Get chaos analysis
            attractor = self.chaos.detect_strange_attractor(price_data)

            # Calculate confidence
            bullish_prob = states['strong_bull']['probability'] + states['bull']['probability']
            bearish_prob = states['strong_bear']['probability'] + states['bear']['probability']
            neutral_prob = states['neutral']['probability']

            # Determine action
            confidence_threshold = 0.6
            action = "HOLD"
            signal_type = "NEUTRAL"

            if bullish_prob > confidence_threshold:
                action = "BUY"
                signal_type = "BUY"
                confidence = bullish_prob
            elif bearish_prob > confidence_threshold:
                action = "SELL"
                signal_type = "SELL"
                confidence = bearish_prob
            else:
                confidence = max(bullish_prob, bearish_prob, neutral_prob)

            # Get next candle prediction
            next_candle = predictions[0]

            # Create signal
            signal = {
                'symbol': symbol,
                'type': signal_type,
                'action': action,
                'trend': 'BULLISH' if bullish_prob > bearish_prob else 'BEARISH' if bearish_prob > bullish_prob else 'NEUTRAL',
                'probability': float(bullish_prob if bullish_prob > bearish_prob else bearish_prob),
                'confidence': float(confidence * 100),  # Convert to percentage
                'timestamp': datetime.utcnow().isoformat(),
                'ml_prediction': {
                    'next_price': float(next_candle['predicted_price']),
                    'upper_bound': float(next_candle['upper_bound']),
                    'lower_bound': float(next_candle['lower_bound']),
                    'entry_probability': float(bullish_prob if signal_type == 'BUY' else bearish_prob if signal_type == 'SELL' else neutral_prob),
                    'exit_probability': float(1 - confidence),
                    'confidence_score': float(next_candle['confidence'] * 100),
                    'predicted_window': 8
                },
                'chaos_analysis': {
                    'is_strange_attractor': attractor['is_attractor'],
                    'fractal_dimension': float(attractor['fractal_dimension']),
                    'lyapunov_exponent': float(attractor['lyapunov_exponent']),
                    'predictability': attractor['predictability']
                }
            }

            logger.info(f"{symbol}: {action} signal (confidence: {confidence*100:.1f}%)")
            return signal

        except Exception as e:
            logger.error(f"Error generating predictions for {symbol}: {e}")
            return None

    def save_signals(self, signals):
        """Save signals to file for bridge to serve"""
        try:
            output = {
                'signals': signals,
                'timestamp': datetime.utcnow().isoformat(),
                'total_signals': len(signals)
            }

            output_file = self.predictions_dir / 'signal_output.json'
            with open(output_file, 'w') as f:
                json.dump(output, f, indent=2)

            logger.info(f"Saved {len(signals)} signals to {output_file}")
            return True

        except Exception as e:
            logger.error(f"Error saving signals: {e}")
            return False

    def run(self, symbols=None):
        """Main daemon loop"""
        if symbols is None:
            symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'XAUUSD']

        logger.info("=" * 60)
        logger.info("🔬 Quantum Predictor Daemon Starting")
        logger.info("=" * 60)
        logger.info(f"Monitoring symbols: {', '.join(symbols)}")
        logger.info(f"Poll interval: {self.poll_interval}s")
        logger.info("Waiting for market data from EA...")
        logger.info("=" * 60)

        iteration = 0

        while True:
            try:
                iteration += 1
                logger.info(f"\n--- Prediction Cycle #{iteration} ---")

                signals = []

                for symbol in symbols:
                    # Load real market data
                    price_data = self.load_market_data(symbol)

                    if price_data is None or len(price_data) < 50:
                        logger.debug(f"Skipping {symbol}: insufficient data")
                        continue

                    # Generate predictions
                    signal = self.generate_predictions(symbol, price_data)

                    if signal:
                        signals.append(signal)

                # Save signals
                if signals:
                    self.save_signals(signals)
                    logger.info(f"✅ Generated {len(signals)} signals")
                else:
                    logger.warning("⚠️  No signals generated (waiting for market data)")

                # Sleep until next cycle
                logger.info(f"Sleeping {self.poll_interval}s until next cycle...")
                time.sleep(self.poll_interval)

            except KeyboardInterrupt:
                logger.info("\n🛑 Daemon stopped by user")
                break

            except Exception as e:
                logger.error(f"Error in main loop: {e}", exc_info=True)
                time.sleep(self.poll_interval)


def main():
    parser = argparse.ArgumentParser(description='Quantum Predictor Daemon')
    parser.add_argument('--symbols', type=str, help='Comma-separated list of symbols (default: EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD)')
    parser.add_argument('--interval', type=int, default=10, help='Poll interval in seconds (default: 10)')
    parser.add_argument('--bridge-data', type=str, default='bridge/data', help='Bridge data directory')
    parser.add_argument('--predictions', type=str, default='predictions', help='Predictions output directory')

    args = parser.parse_args()

    # Parse symbols
    symbols = None
    if args.symbols:
        symbols = [s.strip() for s in args.symbols.split(',')]

    # Create daemon
    daemon = PredictorDaemon(
        bridge_data_dir=args.bridge_data,
        predictions_dir=args.predictions,
        poll_interval=args.interval
    )

    # Run
    daemon.run(symbols=symbols)


if __name__ == '__main__':
    main()
