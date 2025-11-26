#!/usr/bin/env python3
"""
Market Predictor Daemon - Real-time Market Prediction Service
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
from dotenv import load_dotenv

import numpy as np
import pandas as pd

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.technical_predictor import TechnicalPredictor, get_realistic_base_price

# Load environment variables
load_dotenv('ml/.env')

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

    def __init__(self, bridge_data_dir='bridge/data', predictions_dir='predictions'):
        self.bridge_data_dir = Path(bridge_data_dir)
        self.predictions_dir = Path(predictions_dir)
        
        # Load configuration from environment
        self.poll_interval = int(os.getenv('PREDICTOR_UPDATE_INTERVAL', 10))
        self.confidence_threshold = float(os.getenv('CONFIDENCE_THRESHOLD', 0.7))
        self.symbols = os.getenv('SYMBOLS', 'EURUSD,GBPUSD,XAUUSD').split(',')
        
        self.predictor = TechnicalPredictor()
        self.last_predictions = {}
        self.model_trained = False

        # Ensure directories exist
        os.makedirs(self.bridge_data_dir, exist_ok=True)
        os.makedirs(self.predictions_dir, exist_ok=True)
        os.makedirs('ml/logs', exist_ok=True)
        os.makedirs('ml/models', exist_ok=True)

        logger.info("Predictor Daemon initialized")
        logger.info(f"Monitoring: {self.bridge_data_dir}")
        logger.info(f"Output to: {self.predictions_dir}")
        logger.info(f"Symbols: {self.symbols}")
        logger.info(f"Poll interval: {self.poll_interval}s")

    def load_market_data(self, symbol):
        """Load real market data from bridge"""
        market_file = self.bridge_data_dir / f"{symbol}_market.json"

        if not market_file.exists():
            logger.warning(f"No market data found for {symbol}")
            return None

        try:
            with open(market_file, 'r') as f:
                data = json.load(f)

            if not data:
                logger.warning(f"Empty market data for {symbol}")
                return None

            # Handle both list and dict formats
            if isinstance(data, dict) and 'candles' in data:
                data = data['candles']
            
            if len(data) < 50:
                logger.warning(f"Insufficient data for {symbol}: {len(data)} candles")
                return None

            # Convert to pandas DataFrame
            df = pd.DataFrame(data)
            
            # Handle different timestamp formats
            if 'timestamp' in df.columns:
                df['time'] = pd.to_datetime(df['timestamp'])
            elif 'time' in df.columns:
                df['time'] = pd.to_datetime(df['time'])
            else:
                # Create synthetic timestamps if missing
                df['time'] = pd.date_range(end=datetime.now(), periods=len(df), freq='1H')
            
            df = df.set_index('time')
            
            # Ensure we have required columns
            if 'bid' in df.columns and 'ask' in df.columns:
                df['close'] = (df['bid'] + df['ask']) / 2
                df['open'] = df['close'].shift(1).fillna(df['close'])
                df['high'] = df[['bid', 'ask']].max(axis=1)
                df['low'] = df[['bid', 'ask']].min(axis=1)
            elif 'close' not in df.columns:
                logger.error(f"Missing price data for {symbol}")
                return None
            
            # Ensure volume exists
            if 'volume' not in df.columns:
                df['volume'] = 100  # Default volume
            
            return df

        except Exception as e:
            logger.error(f"Error loading market data for {symbol}: {e}")
            return None

    def train_models_if_needed(self):
        """Train models on available data if not already trained"""
        if self.model_trained:
            return True
        
        logger.info("Training prediction models...")
        
        # Combine data from all symbols for training
        all_data = []
        for symbol in self.symbols:
            df = self.load_market_data(symbol)
            if df is not None and len(df) > 100:
                all_data.append(df)
        
        if not all_data:
            logger.error("No sufficient data for training")
            return False
        
        # Use the symbol with most data for training
        training_data = max(all_data, key=len)
        
        try:
            self.model_trained = self.predictor.train(training_data)
            if self.model_trained:
                logger.info("Models trained successfully")
                # Save model state
                self.save_model_state()
            return self.model_trained
        except Exception as e:
            logger.error(f"Model training failed: {e}")
            return False

    def generate_predictions(self, symbol, market_data):
        """Generate predictions for a symbol"""
        try:
            logger.info(f"Generating predictions for {symbol}")

            # Get predictions
            predictions = self.predictor.predict_next_candles(market_data, n_candles=5)
            
            # Analyze market regime
            regime = self.predictor.analyze_market_regime(market_data)
            
            # Get current price info
            current_price = float(market_data['close'].iloc[-1])
            current_bid = float(market_data['bid'].iloc[-1]) if 'bid' in market_data else current_price
            current_ask = float(market_data['ask'].iloc[-1]) if 'ask' in market_data else current_price
            
            # Build signal
            main_prediction = predictions[0] if predictions else {}
            
            signal = {
                'symbol': symbol,
                'timestamp': datetime.now().isoformat(),
                'current_price': {
                    'bid': current_bid,
                    'ask': current_ask,
                    'mid': current_price
                },
                'prediction': main_prediction.get('direction', 'NEUTRAL'),
                'confidence': main_prediction.get('confidence', 0.5),
                'predicted_price': main_prediction.get('predicted_price', current_price),
                'upper_bound': main_prediction.get('upper_bound', current_price * 1.001),
                'lower_bound': main_prediction.get('lower_bound', current_price * 0.999),
                'market_regime': regime,
                'technical_scores': main_prediction.get('technical_scores', {}),
                'next_candles': predictions,
                'metadata': {
                    'model_version': '2.0',
                    'data_points': len(market_data),
                    'last_update': market_data.index[-1].isoformat() if not market_data.empty else None
                }
            }

            return signal

        except Exception as e:
            logger.error(f"Error generating predictions for {symbol}: {e}")
            return None

    def save_predictions(self, signals):
        """Save predictions to file"""
        if not signals:
            return
        
        output_file = self.predictions_dir / 'signal_output.json'
        
        try:
            # Save main signal file
            with open(output_file, 'w') as f:
                json.dump(signals, f, indent=2)
            
            # Save individual symbol files
            for signal in signals:
                symbol_file = self.predictions_dir / f"{signal['symbol']}_signal.json"
                with open(symbol_file, 'w') as f:
                    json.dump(signal, f, indent=2)
            
            logger.info(f"Saved {len(signals)} predictions")
            
        except Exception as e:
            logger.error(f"Error saving predictions: {e}")

    def save_model_state(self):
        """Save trained model state"""
        try:
            import pickle
            model_file = Path('ml/models/technical_model.pkl')
            with open(model_file, 'wb') as f:
                pickle.dump({
                    'predictor': self.predictor,
                    'trained_at': datetime.now().isoformat(),
                    'version': '2.0'
                }, f)
            logger.info("Model state saved")
        except Exception as e:
            logger.error(f"Error saving model: {e}")

    def load_model_state(self):
        """Load previously trained model if available"""
        try:
            import pickle
            model_file = Path('ml/models/technical_model.pkl')
            if model_file.exists():
                with open(model_file, 'rb') as f:
                    state = pickle.load(f)
                    self.predictor = state['predictor']
                    self.model_trained = True
                    logger.info(f"Loaded model trained at {state['trained_at']}")
                    return True
        except Exception as e:
            logger.error(f"Error loading model: {e}")
        return False

    def run_once(self):
        """Run one prediction cycle"""
        signals = []
        
        # Ensure models are trained
        if not self.model_trained:
            self.load_model_state()
            if not self.model_trained:
                self.train_models_if_needed()
        
        for symbol in self.symbols:
            try:
                # Load market data
                market_data = self.load_market_data(symbol)
                
                if market_data is None:
                    logger.warning(f"Skipping {symbol} - no data")
                    continue
                
                # Generate predictions
                signal = self.generate_predictions(symbol, market_data)
                
                if signal and signal['confidence'] >= self.confidence_threshold:
                    signals.append(signal)
                    logger.info(f"{symbol}: {signal['prediction']} (confidence: {signal['confidence']:.2f})")
                else:
                    logger.info(f"{symbol}: Low confidence signal filtered out")
                    
            except Exception as e:
                logger.error(f"Error processing {symbol}: {e}")
                continue
        
        # Save all signals
        if signals:
            self.save_predictions(signals)
        
        return signals

    def run(self):
        """Main daemon loop"""
        logger.info("Starting prediction daemon...")
        
        while True:
            try:
                start_time = time.time()
                
                # Run prediction cycle
                signals = self.run_once()
                
                # Calculate cycle time
                cycle_time = time.time() - start_time
                logger.info(f"Prediction cycle completed in {cycle_time:.2f}s")
                
                # Sleep for remainder of interval
                sleep_time = max(0, self.poll_interval - cycle_time)
                if sleep_time > 0:
                    time.sleep(sleep_time)
                    
            except KeyboardInterrupt:
                logger.info("Daemon stopped by user")
                break
            except Exception as e:
                logger.error(f"Daemon error: {e}")
                time.sleep(self.poll_interval)

    def generate_test_data(self):
        """Generate test data for development"""
        logger.info("Generating test data...")
        
        for symbol in self.symbols:
            base_price = get_realistic_base_price(symbol)
            
            # Generate realistic price movements
            timestamps = pd.date_range(end=datetime.now(), periods=200, freq='1H')
            prices = [base_price]
            
            for _ in range(199):
                # Random walk with momentum
                change = np.random.normal(0, 0.0002) + (prices[-1] - base_price) * -0.01
                new_price = prices[-1] * (1 + change)
                prices.append(new_price)
            
            # Create market data
            spread_pct = 0.00001 if 'USD' in symbol else 0.0001
            data = []
            for i, (ts, price) in enumerate(zip(timestamps, prices)):
                spread = price * spread_pct
                data.append({
                    'timestamp': ts.isoformat(),
                    'bid': price - spread/2,
                    'ask': price + spread/2,
                    'volume': np.random.randint(50, 200),
                    'open': prices[max(0, i-1)],
                    'high': price * 1.0001,
                    'low': price * 0.9999,
                    'close': price
                })
            
            # Save test data
            output_file = self.bridge_data_dir / f"{symbol}_market.json"
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=2)
            
            logger.info(f"Generated test data for {symbol}")


def main():
    parser = argparse.ArgumentParser(description='Market Predictor Daemon')
    parser.add_argument('--test-data', action='store_true', help='Generate test data')
    parser.add_argument('--once', action='store_true', help='Run once and exit')
    args = parser.parse_args()
    
    daemon = PredictorDaemon()
    
    if args.test_data:
        daemon.generate_test_data()
        return
    
    if args.once:
        daemon.run_once()
    else:
        daemon.run()


if __name__ == '__main__':
    main()