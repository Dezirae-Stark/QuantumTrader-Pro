#!/usr/bin/env python3
"""
Technical Analysis-Based Market Predictor
Uses proven technical indicators and machine learning for market prediction
Replaces the pseudoscientific quantum mechanics approach
"""

import numpy as np
import pandas as pd
import ta
from scipy import stats
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
import warnings
import logging
import os
from datetime import datetime, timedelta, timezone
import json

# Import our advanced indicator system
from indicators.signal_engine import SignalEngine, SignalWeight
from indicators.base import SignalStrength
from ultra_high_accuracy_strategy import UltraHighAccuracyStrategy
from high_volatility_trading_suite import HighVolatilityTradingSuite
from adaptive_strategy_manager import AdaptiveStrategyManager
from news_event_trading_suite import NewsEventTradingSuite, NewsEventType
from aggressive_position_manager import AggressivePositionManager
from unified_aggressive_trading import UnifiedAggressiveTradingManager

warnings.filterwarnings('ignore')

# Configure logging
log_dir = 'ml/logs'
os.makedirs(log_dir, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(log_dir, 'technical_predictor.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class TechnicalPredictor:
    """
    Technical analysis-based predictor using real indicators and ML
    """
    
    def __init__(self):
        self.scaler = StandardScaler()
        self.direction_model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42
        )
        self.price_model = GradientBoostingRegressor(
            n_estimators=100,
            max_depth=5,
            random_state=42
        )
        self.feature_importance = {}
        
        # Initialize the advanced signal engine
        self.signal_engine = SignalEngine(
            custom_weights={
                "Alligator": 1.0,      # Primary trend
                "Elliott Wave": 0.9,    # Pattern recognition
                "Awesome Oscillator": 0.7,
                "Accelerator Oscillator": 0.7,
                "Fractals": 0.8,
                "Williams MFI": 0.6
            }
        )
        
        # Initialize ultra-high accuracy strategy (94.7%+ win rate)
        self.ultra_high_accuracy = UltraHighAccuracyStrategy()
        self.use_ultra_high_accuracy = False  # Can be toggled
        
        # Initialize high volatility trading suite (90%+ win rate in volatile markets)
        self.volatility_suite = HighVolatilityTradingSuite()
        self.use_volatility_suite = False  # Can be toggled
        
        # Initialize adaptive strategy manager (automatically chooses best strategy)
        self.adaptive_manager = AdaptiveStrategyManager()
        self.use_adaptive_mode = True  # Default to adaptive mode
        
        # Initialize news event trading suite (85%+ win rate on major news)
        self.news_trader = NewsEventTradingSuite()
        self.use_news_trading = False  # Can be toggled
        
        # Initialize aggressive position manager for high leverage trading
        self.position_manager = AggressivePositionManager()
        self.use_aggressive_sizing = False  # Can be toggled
        
        # Initialize unified aggressive trading manager (your 20% GBP/USD model)
        self.unified_aggressive = UnifiedAggressiveTradingManager()
        self.use_unified_aggressive = False  # Can be toggled
        
    def calculate_technical_indicators(self, df):
        """
        Calculate comprehensive technical indicators
        """
        if len(df) < 50:
            logger.warning(f"Insufficient data for indicators: {len(df)} rows")
            return pd.DataFrame()
            
        # Ensure we have OHLCV data
        required_columns = ['open', 'high', 'low', 'close', 'volume']
        if 'bid' in df.columns and 'close' not in df.columns:
            # Convert bid/ask to OHLC format
            df['close'] = df['bid']
            df['open'] = df['bid'].shift(1).fillna(df['bid'])
            df['high'] = df[['bid', 'ask']].max(axis=1) if 'ask' in df.columns else df['bid']
            df['low'] = df['bid']
            df['volume'] = df.get('volume', 100)
        
        features = pd.DataFrame(index=df.index)
        
        # Price-based features
        features['returns'] = df['close'].pct_change()
        features['log_returns'] = np.log(df['close'] / df['close'].shift(1))
        
        # Trend Indicators
        features['sma_20'] = ta.trend.SMAIndicator(df['close'], window=20).sma_indicator()
        features['sma_50'] = ta.trend.SMAIndicator(df['close'], window=50).sma_indicator()
        features['ema_12'] = ta.trend.EMAIndicator(df['close'], window=12).ema_indicator()
        features['ema_26'] = ta.trend.EMAIndicator(df['close'], window=26).ema_indicator()
        
        # MACD
        macd = ta.trend.MACD(df['close'])
        features['macd'] = macd.macd()
        features['macd_signal'] = macd.macd_signal()
        features['macd_diff'] = macd.macd_diff()
        
        # RSI
        features['rsi'] = ta.momentum.RSIIndicator(df['close']).rsi()
        
        # Bollinger Bands
        bb = ta.volatility.BollingerBands(df['close'])
        features['bb_high'] = bb.bollinger_hband()
        features['bb_low'] = bb.bollinger_lband()
        features['bb_mid'] = bb.bollinger_mavg()
        features['bb_width'] = bb.bollinger_wband()
        features['bb_pct'] = bb.bollinger_pband()
        
        # Stochastic Oscillator
        stoch = ta.momentum.StochasticOscillator(df['high'], df['low'], df['close'])
        features['stoch_k'] = stoch.stoch()
        features['stoch_d'] = stoch.stoch_signal()
        
        # ADX (Trend Strength)
        adx = ta.trend.ADXIndicator(df['high'], df['low'], df['close'])
        features['adx'] = adx.adx()
        features['adx_pos'] = adx.adx_pos()
        features['adx_neg'] = adx.adx_neg()
        
        # ATR (Volatility)
        features['atr'] = ta.volatility.AverageTrueRange(df['high'], df['low'], df['close']).average_true_range()
        
        # Volume Indicators
        if df['volume'].sum() > 0:
            features['obv'] = ta.volume.OnBalanceVolumeIndicator(df['close'], df['volume']).on_balance_volume()
            features['vwap'] = ta.volume.VolumeWeightedAveragePrice(
                df['high'], df['low'], df['close'], df['volume']
            ).volume_weighted_average_price()
        
        # Market Microstructure
        if 'ask' in df.columns:
            features['spread'] = df['ask'] - df['bid']
            features['spread_pct'] = features['spread'] / df['bid']
            features['mid_price'] = (df['bid'] + df['ask']) / 2
        
        # Statistical Features
        for window in [5, 10, 20]:
            features[f'volatility_{window}'] = features['returns'].rolling(window).std()
            features[f'skew_{window}'] = features['returns'].rolling(window).skew()
            features[f'kurt_{window}'] = features['returns'].rolling(window).kurt()
        
        # Support/Resistance Levels
        for window in [20, 50]:
            features[f'resistance_{window}'] = df['high'].rolling(window).max()
            features[f'support_{window}'] = df['low'].rolling(window).min()
            features[f'price_to_resistance_{window}'] = (features[f'resistance_{window}'] - df['close']) / df['close']
            features[f'price_to_support_{window}'] = (df['close'] - features[f'support_{window}']) / df['close']
        
        return features
    
    def prepare_training_data(self, df, prediction_horizon=5):
        """
        Prepare data for ML training with proper target labels
        """
        features = self.calculate_technical_indicators(df)
        
        if features.empty or len(features) < 100:
            return None, None, None
        
        # Create target variables
        future_returns = df['close'].shift(-prediction_horizon) / df['close'] - 1
        
        # Direction: 1 for up, 0 for down
        y_direction = (future_returns > 0).astype(int)
        
        # Price target
        y_price = df['close'].shift(-prediction_horizon)
        
        # Remove NaN rows
        mask = ~(features.isna().any(axis=1) | y_direction.isna() | y_price.isna())
        
        X = features[mask].values
        y_dir = y_direction[mask].values
        y_price = y_price[mask].values
        
        return X, y_dir, y_price
    
    def train(self, market_data):
        """
        Train the ML models on historical data
        """
        logger.info("Training technical prediction models...")
        
        X, y_dir, y_price = self.prepare_training_data(market_data)
        
        if X is None or len(X) < 200:
            logger.error("Insufficient data for training")
            return False
        
        # Split data (80/20)
        split_idx = int(len(X) * 0.8)
        X_train, X_test = X[:split_idx], X[split_idx:]
        y_dir_train, y_dir_test = y_dir[:split_idx], y_dir[split_idx:]
        y_price_train, y_price_test = y_price[:split_idx], y_price[split_idx:]
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Train direction model
        self.direction_model.fit(X_train_scaled, y_dir_train)
        dir_accuracy = self.direction_model.score(X_test_scaled, y_dir_test)
        logger.info(f"Direction model accuracy: {dir_accuracy:.3f}")
        
        # Train price model
        self.price_model.fit(X_train_scaled, y_price_train)
        price_r2 = self.price_model.score(X_test_scaled, y_price_test)
        logger.info(f"Price model R²: {price_r2:.3f}")
        
        # Store feature importance
        feature_names = self.calculate_technical_indicators(market_data).columns
        self.feature_importance = dict(zip(
            feature_names,
            self.direction_model.feature_importances_
        ))
        
        return True
    
    def predict_next_candles(self, price_series, n_candles=5):
        """
        Predict next n candles with confidence intervals
        Enhanced with advanced signal engine analysis
        """
        # Convert to DataFrame if Series
        if isinstance(price_series, pd.Series):
            df = pd.DataFrame({'bid': price_series})
        else:
            df = price_series.copy()
        
        # Calculate features
        features = self.calculate_technical_indicators(df)
        
        if features.empty:
            logger.warning("No features calculated, returning neutral prediction")
            return self._generate_neutral_predictions(df, n_candles)
        
        # Get latest features (remove NaN)
        latest_features = features.dropna().iloc[-1:].values
        
        if latest_features.shape[0] == 0:
            return self._generate_neutral_predictions(df, n_candles)
        
        try:
            # Get signal engine analysis
            signal_analysis = None
            try:
                if len(df) >= self.signal_engine.get_required_periods():
                    # Ensure we have proper OHLCV format for signal engine
                    signal_df = df.copy()
                    if 'bid' in df.columns and 'close' not in df.columns:
                        signal_df['close'] = df['bid']
                        signal_df['open'] = df['bid'].shift(1).fillna(df['bid'])
                        signal_df['high'] = df[['bid', 'ask']].max(axis=1) if 'ask' in df.columns else df['bid']
                        signal_df['low'] = df['bid']
                        signal_df['volume'] = df.get('volume', 100)
                    
                    symbol = 'UNKNOWN'  # Default symbol
                    signal_analysis = self.signal_engine.analyze(signal_df, symbol)
                    logger.info(f"Signal Engine Analysis: {signal_analysis.signal.name} "
                              f"with {signal_analysis.probability:.1f}% probability")
            except Exception as e:
                logger.warning(f"Signal engine analysis failed: {e}")
            
            # Scale features
            latest_features_scaled = self.scaler.transform(latest_features)
            
            # Predict direction and probability
            direction_proba = self.direction_model.predict_proba(latest_features_scaled)[0]
            direction = self.direction_model.predict(latest_features_scaled)[0]
            
            # Predict price
            predicted_price = self.price_model.predict(latest_features_scaled)[0]
            
            # Calculate confidence based on model certainty
            ml_confidence = max(direction_proba)
            
            # Combine with signal engine confidence if available
            if signal_analysis:
                # Weight ML and signal engine confidences
                combined_confidence = (ml_confidence * 0.4 + 
                                     signal_analysis.confidence * 0.3 + 
                                     signal_analysis.probability/100 * 0.3)
                
                # Adjust direction based on strong signal engine signals
                if signal_analysis.signal in [SignalStrength.STRONG_BUY, SignalStrength.STRONG_SELL]:
                    if signal_analysis.signal == SignalStrength.STRONG_BUY:
                        direction = 1
                    elif signal_analysis.signal == SignalStrength.STRONG_SELL:
                        direction = 0
            else:
                combined_confidence = ml_confidence
            
            # Generate predictions for each candle
            predictions = []
            current_price = float(df['bid'].iloc[-1]) if 'bid' in df else float(df['close'].iloc[-1])
            
            for i in range(n_candles):
                # Decay confidence over time
                candle_confidence = combined_confidence * (0.95 ** i)
                
                # Calculate price change
                if i == n_candles - 1:
                    # Use model prediction for final candle
                    candle_price = predicted_price
                else:
                    # Interpolate for intermediate candles
                    price_change = (predicted_price - current_price) * ((i + 1) / n_candles)
                    candle_price = current_price + price_change
                
                # Calculate bounds based on ATR and signal engine risk
                atr = features['atr'].dropna().iloc[-1] if 'atr' in features else current_price * 0.001
                risk_multiplier = 1.0
                if signal_analysis and signal_analysis.risk_level == "High Risk":
                    risk_multiplier = 1.5
                elif signal_analysis and signal_analysis.risk_level == "Low Risk":
                    risk_multiplier = 0.7
                
                bound_width = atr * (i + 1) * 0.5 * risk_multiplier
                
                prediction = {
                    'candle': i + 1,
                    'predicted_price': float(candle_price),
                    'direction': 'UP' if direction == 1 else 'DOWN',
                    'confidence': float(candle_confidence),
                    'upper_bound': float(candle_price + bound_width),
                    'lower_bound': float(candle_price - bound_width),
                    'timestamp': (datetime.now() + timedelta(hours=i+1)).isoformat(),
                    'technical_scores': self._get_technical_scores(features),
                    'signal_engine': {
                        'signal': signal_analysis.signal.name if signal_analysis else 'NEUTRAL',
                        'probability': signal_analysis.probability if signal_analysis else 50.0,
                        'market_condition': signal_analysis.market_condition if signal_analysis else 'unknown',
                        'risk_level': signal_analysis.risk_level if signal_analysis else 'Medium Risk'
                    } if signal_analysis else None
                }
                predictions.append(prediction)
            
            return predictions
            
        except Exception as e:
            logger.error(f"Prediction error: {e}")
            return self._generate_neutral_predictions(df, n_candles)
    
    def _get_technical_scores(self, features):
        """
        Get current technical indicator scores
        """
        latest = features.dropna().iloc[-1] if not features.empty else pd.Series()
        
        scores = {
            'trend': 'neutral',
            'momentum': 'neutral',
            'volatility': 'normal'
        }
        
        if not latest.empty:
            # Trend assessment
            if 'sma_20' in latest and 'sma_50' in latest:
                if latest.get('close', 0) > latest['sma_20'] > latest['sma_50']:
                    scores['trend'] = 'bullish'
                elif latest.get('close', 0) < latest['sma_20'] < latest['sma_50']:
                    scores['trend'] = 'bearish'
            
            # Momentum assessment
            if 'rsi' in latest:
                if latest['rsi'] > 70:
                    scores['momentum'] = 'overbought'
                elif latest['rsi'] < 30:
                    scores['momentum'] = 'oversold'
                else:
                    scores['momentum'] = 'neutral'
            
            # Volatility assessment
            if 'atr' in latest and 'close' in latest:
                atr_pct = latest['atr'] / latest['close']
                if atr_pct > 0.02:
                    scores['volatility'] = 'high'
                elif atr_pct < 0.005:
                    scores['volatility'] = 'low'
        
        return scores
    
    def _generate_neutral_predictions(self, df, n_candles):
        """
        Generate neutral predictions when models can't predict
        """
        current_price = float(df.iloc[-1]['bid']) if 'bid' in df.columns else float(df.iloc[-1]['close'])
        
        predictions = []
        for i in range(n_candles):
            predictions.append({
                'candle': i + 1,
                'predicted_price': current_price,
                'direction': 'NEUTRAL',
                'confidence': 0.5,
                'upper_bound': current_price * 1.001,
                'lower_bound': current_price * 0.999,
                'timestamp': (datetime.now() + timedelta(hours=i+1)).isoformat(),
                'technical_scores': {
                    'trend': 'neutral',
                    'momentum': 'neutral',
                    'volatility': 'normal'
                }
            })
        
        return predictions
    
    def analyze_market_regime(self, df):
        """
        Identify current market regime (trending, ranging, volatile)
        """
        features = self.calculate_technical_indicators(df)
        
        if features.empty:
            return {
                'regime': 'unknown',
                'strength': 0.0,
                'characteristics': {}
            }
        
        latest = features.dropna().iloc[-1]
        
        regime_scores = {
            'trending': 0.0,
            'ranging': 0.0,
            'volatile': 0.0
        }
        
        # Trending market indicators
        if 'adx' in latest:
            if latest['adx'] > 25:
                regime_scores['trending'] += 0.4
            if latest['adx'] > 40:
                regime_scores['trending'] += 0.3
        
        if 'macd_diff' in latest:
            if abs(latest['macd_diff']) > 0:
                regime_scores['trending'] += 0.3
        
        # Ranging market indicators
        if 'bb_width' in latest and 'atr' in latest:
            if latest['bb_width'] < latest['atr'] * 2:
                regime_scores['ranging'] += 0.5
        
        if 'rsi' in latest:
            if 40 < latest['rsi'] < 60:
                regime_scores['ranging'] += 0.5
        
        # Volatile market indicators
        if 'volatility_20' in latest:
            recent_vol = features['volatility_20'].dropna().tail(20).mean()
            current_vol = latest['volatility_20']
            if current_vol > recent_vol * 1.5:
                regime_scores['volatile'] += 0.7
        
        # Determine primary regime
        primary_regime = max(regime_scores, key=regime_scores.get)
        
        return {
            'regime': primary_regime,
            'strength': regime_scores[primary_regime],
            'characteristics': {
                'adx': float(latest.get('adx', 0)),
                'volatility': float(latest.get('volatility_20', 0)),
                'trend_direction': 'up' if latest.get('sma_20', 0) > latest.get('sma_50', 0) else 'down'
            }
        }
    
    def get_advanced_signals(self, df, symbol='UNKNOWN'):
        """
        Get comprehensive signal analysis from the advanced indicator engine
        """
        try:
            # Ensure proper OHLCV format
            signal_df = df.copy()
            if 'bid' in df.columns and 'close' not in df.columns:
                signal_df['close'] = df['bid']
                signal_df['open'] = df['bid'].shift(1).fillna(df['bid'])
                signal_df['high'] = df[['bid', 'ask']].max(axis=1) if 'ask' in df.columns else df['bid']
                signal_df['low'] = df['bid']
                signal_df['volume'] = df.get('volume', 100)
            
            # Check if we have enough data
            if len(signal_df) < self.signal_engine.get_required_periods():
                return {
                    'status': 'insufficient_data',
                    'required_periods': self.signal_engine.get_required_periods(),
                    'available_periods': len(signal_df)
                }
            
            # Get comprehensive analysis
            analysis = self.signal_engine.analyze(signal_df, symbol)
            
            # Get historical statistics
            stats = self.signal_engine.get_signal_statistics(signal_df, symbol, 
                                                           lookback_periods=min(100, len(signal_df) - 50))
            
            return {
                'status': 'success',
                'current_signal': {
                    'signal': analysis.signal.name,
                    'signal_value': analysis.signal.value,
                    'confidence': analysis.confidence,
                    'probability': analysis.probability,
                    'market_condition': analysis.market_condition,
                    'recommended_action': analysis.recommended_action,
                    'risk_level': analysis.risk_level,
                    'indicators_used': analysis.indicators_used
                },
                'contributing_indicators': analysis.contributing_signals,
                'statistics': stats,
                'timestamp': analysis.timestamp.isoformat()
            }
            
        except Exception as e:
            logger.error(f"Advanced signal analysis error: {e}")
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def toggle_indicator(self, indicator_name, enabled):
        """
        Enable or disable specific indicators in the signal engine
        """
        self.signal_engine.toggle_indicator(indicator_name, enabled)
        logger.info(f"Indicator {indicator_name} {'enabled' if enabled else 'disabled'}")
    
    def enable_ultra_high_accuracy_mode(self, enabled: bool = True):
        """
        Enable/disable ultra-high accuracy mode (94.7%+ win rate)
        """
        self.use_ultra_high_accuracy = enabled
        logger.info(f"Ultra-high accuracy mode {'enabled' if enabled else 'disabled'}")
        
        if enabled:
            # Adjust signal engine weights for ultra-high accuracy
            self.signal_engine = SignalEngine(
                custom_weights={
                    "Alligator": 2.0,       # Heavy trend emphasis
                    "Elliott Wave": 1.5,    # Pattern recognition
                    "Awesome Oscillator": 0.7,
                    "Accelerator Oscillator": 0.6,
                    "Fractals": 1.2,        # Key levels
                    "Williams MFI": 0.8
                }
            )
    
    def get_ultra_high_accuracy_signal(self, df: pd.DataFrame, symbol: str, 
                                     spread: float = 0.0001) -> dict:
        """
        Get ultra-high accuracy trade signal (94.7%+ win rate)
        """
        if not self.use_ultra_high_accuracy:
            self.enable_ultra_high_accuracy_mode(True)
        
        return self.ultra_high_accuracy.evaluate_trade_setup(df, symbol)
    
    def get_volatility_signal(self, df: pd.DataFrame, symbol: str,
                            spread: float = 0.0001) -> dict:
        """
        Get volatility trading signal (90%+ win rate in volatile markets)
        """
        signal = self.volatility_suite.analyze_volatility_opportunity(df, symbol, spread)
        
        if signal:
            return {
                'status': 'success',
                'can_trade': True,
                'strategy': signal.strategy.value,
                'direction': signal.direction.name,
                'confidence': signal.confidence,
                'volatility_regime': signal.volatility_regime.value,
                'entry_price': signal.entry_price,
                'stop_loss': signal.stop_loss,
                'take_profit_1': signal.take_profit_1,
                'take_profit_2': signal.take_profit_2,
                'risk_reward': signal.risk_reward,
                'time_limit': signal.time_limit,
                'entry_reason': signal.entry_reason
            }
        else:
            return {
                'status': 'no_signal',
                'can_trade': False,
                'reason': 'No volatility opportunity detected'
            }
    
    def get_adaptive_signal(self, df: pd.DataFrame, symbol: str,
                          spread: float = 0.0001) -> dict:
        """
        Get adaptive signal that automatically selects best strategy
        """
        signal = self.adaptive_manager.analyze_market(df, symbol, spread)
        
        return {
            'status': 'success',
            'strategy_used': signal.strategy_used,
            'market_condition': signal.market_condition.value,
            'can_trade': signal.can_trade,
            'confidence': signal.confidence,
            'expected_win_rate': signal.expected_win_rate,
            'recommended_action': signal.recommended_action,
            'risk_level': signal.risk_level,
            'signal_details': signal.signal_details,
            'filters_summary': signal.filters_summary
        }
    
    def enable_volatility_suite(self, enabled: bool = True):
        """
        Enable/disable high volatility trading suite
        """
        self.use_volatility_suite = enabled
        logger.info(f"High volatility trading suite {'enabled' if enabled else 'disabled'}")
    
    def enable_adaptive_mode(self, enabled: bool = True):
        """
        Enable/disable adaptive strategy selection
        """
        self.use_adaptive_mode = enabled
        logger.info(f"Adaptive strategy mode {'enabled' if enabled else 'disabled'}")
    
    def get_news_signal(self, df: pd.DataFrame, symbol: str) -> dict:
        """
        Get news event trading signal (85%+ win rate on major news)
        """
        # Get upcoming news events
        current_time = datetime.now(timezone.utc)
        start_time = current_time - timedelta(hours=4)
        end_time = current_time + timedelta(hours=8)
        
        upcoming_events = self.news_trader.get_economic_calendar_events(start_time, end_time)
        
        # Analyze for news opportunities
        signal = self.news_trader.analyze_news_opportunity(df, symbol, upcoming_events, current_time)
        
        if signal:
            response = {
                'status': 'success',
                'can_trade': True,
                'event_type': signal.event.event_type.value,
                'strategy': signal.strategy.value,
                'phase': signal.phase.value,
                'direction': signal.direction.name,
                'confidence': signal.confidence,
                'expected_move': signal.expected_move,
                'risk_reward': signal.risk_reward,
                'entry_price': signal.entry_price,
                'stop_loss': signal.stop_loss,
                'take_profit_1': signal.take_profit_1,
                'take_profit_2': signal.take_profit_2,
                'take_profit_3': signal.take_profit_3,
                'max_hold_time': signal.max_hold_time,
                'entry_reason': signal.entry_reason,
                'time_to_event': (signal.event.release_time - current_time).total_seconds() / 60,
                'filters_passed': signal.filters_passed
            }
            
            # Add aggressive position sizing if enabled
            if self.use_aggressive_sizing:
                try:
                    aggressive_position = self.position_manager.calculate_aggressive_position(signal)
                    response['aggressive_sizing'] = {
                        'position_size_lots': aggressive_position.position_size_lots,
                        'position_value_usd': aggressive_position.position_value_usd,
                        'leverage_used': aggressive_position.leverage_used,
                        'risk_amount': aggressive_position.risk_amount,
                        'risk_percentage': aggressive_position.risk_percentage,
                        'aggressive_targets': aggressive_position.take_profit_targets,
                        'target_profit_amounts': aggressive_position.target_profit_amounts,
                        'expected_daily_return': aggressive_position.expected_daily_return
                    }
                except Exception as e:
                    logger.error(f"Error calculating aggressive position: {e}")
                    response['aggressive_sizing'] = {'error': 'Position calculation failed'}
            
            return response
        else:
            return {
                'status': 'no_signal',
                'can_trade': False,
                'reason': 'No news trading opportunity detected',
                'upcoming_events': len(upcoming_events),
                'next_event': upcoming_events[0].event_type.value if upcoming_events else None
            }
    
    def enable_news_trading(self, enabled: bool = True):
        """
        Enable/disable news event trading suite
        """
        self.use_news_trading = enabled
        logger.info(f"News event trading suite {'enabled' if enabled else 'disabled'}")
    
    def get_economic_calendar(self, symbol: str, days_ahead: int = 7) -> dict:
        """
        Get upcoming economic calendar events
        """
        current_time = datetime.now(timezone.utc)
        end_time = current_time + timedelta(days=days_ahead)
        
        events = self.news_trader.get_economic_calendar_events(current_time, end_time)
        
        calendar_events = []
        for event in events:
            if event.symbol == symbol:
                calendar_events.append({
                    'event_type': event.event_type.value,
                    'release_time': event.release_time.isoformat(),
                    'impact_level': event.impact_level,
                    'forecast': event.forecast,
                    'previous': event.previous,
                    'time_until_release': (event.release_time - current_time).total_seconds() / 3600,  # hours
                    'expected_move': self.news_trader.event_params.get(event.event_type, {}).get('expected_move', 0),
                    'strategies': [s.value for s in self.news_trader.event_params.get(event.event_type, {}).get('strategies', [])]
                })
        
        return {
            'status': 'success',
            'symbol': symbol,
            'events': calendar_events,
            'total_events': len(calendar_events)
        }
    
    def enable_aggressive_sizing(self, enabled: bool = True, account_balance: float = None):
        """
        Enable/disable aggressive position sizing (100:1+ leverage, 20% risk)
        """
        self.use_aggressive_sizing = enabled
        
        if account_balance is not None:
            self.position_manager.update_account_balance(account_balance)
        
        logger.info(f"Aggressive position sizing {'enabled' if enabled else 'disabled'}")
    
    def get_aggressive_position_analysis(self, df: pd.DataFrame, symbol: str) -> dict:
        """
        Get comprehensive position analysis for aggressive trading
        """
        if not self.use_aggressive_sizing:
            return {
                'status': 'disabled',
                'message': 'Aggressive sizing not enabled'
            }
        
        # Get news signal first
        news_signal_data = self.get_news_signal(df, symbol)
        
        if not news_signal_data.get('can_trade'):
            return {
                'status': 'no_signal',
                'message': 'No tradeable news signal available'
            }
        
        # Calculate daily profit potential
        # Note: This assumes we have the actual news signal object
        # In practice, you'd reconstruct it from the news_signal_data
        
        account_info = {
            'account_balance': self.position_manager.account_balance,
            'max_risk_per_trade': self.position_manager.max_risk_percentage,
            'target_daily_return': self.position_manager.target_daily_return,
            'max_leverage': self.position_manager.max_leverage
        }
        
        if 'aggressive_sizing' in news_signal_data:
            sizing = news_signal_data['aggressive_sizing']
            return {
                'status': 'success',
                'account_info': account_info,
                'position_analysis': sizing,
                'trading_recommendation': {
                    'recommended_action': f"{news_signal_data['direction']} {sizing['position_size_lots']:.2f} lots",
                    'risk_assessment': f"{sizing['risk_percentage']:.0%} account risk",
                    'profit_potential': f"${sizing['target_profit_amounts'][0]:,.0f} first target",
                    'daily_return_target': f"{sizing['expected_daily_return']:.1%}",
                    'leverage_utilization': f"{sizing['leverage_used']:.0f}:1"
                }
            }
        else:
            return {
                'status': 'error',
                'message': 'Failed to calculate aggressive position sizing'
            }
    
    def enable_unified_aggressive_trading(self, enabled: bool = True, account_balance: float = None):
        """
        Enable/disable unified aggressive trading (your 20% GBP/USD model for ALL strategies)
        """
        self.use_unified_aggressive = enabled
        
        if account_balance is not None:
            self.unified_aggressive.update_account_balance(account_balance)
        
        logger.info(f"Unified aggressive trading {'enabled' if enabled else 'disabled'}")
    
    def get_unified_aggressive_signal(self, df: pd.DataFrame, symbol: str = 'GBPUSD') -> dict:
        """
        Get unified aggressive signal with your 20% risk model applied to ALL strategies
        """
        if not self.use_unified_aggressive:
            return {
                'status': 'disabled',
                'message': 'Unified aggressive trading not enabled'
            }
        
        try:
            signal = self.unified_aggressive.get_unified_signal(df, symbol)
            
            if signal:
                return {
                    'status': 'success',
                    'can_trade': True,
                    'strategy_used': signal.strategy_used,
                    'signal_strength': signal.signal_strength,
                    'direction': signal.direction,
                    'confidence': signal.confidence,
                    'win_probability': signal.win_probability,
                    
                    # Your 20% position sizing
                    'position_size_lots': signal.position_size_lots,
                    'leverage_used': signal.leverage_used,
                    'risk_amount': signal.risk_amount,
                    'risk_percentage': signal.risk_percentage,
                    
                    # Trade details
                    'entry_price': signal.entry_price,
                    'stop_loss': signal.stop_loss,
                    'take_profit_targets': signal.take_profit_targets,
                    'profit_amounts': signal.profit_amounts,
                    'risk_reward_ratio': signal.risk_reward_ratio,
                    'expected_daily_return': signal.expected_daily_return,
                    'max_hold_time': signal.max_hold_time,
                    'entry_reason': signal.entry_reason
                }
            else:
                return {
                    'status': 'no_signal',
                    'can_trade': False,
                    'message': 'No high-probability setup available',
                    'strategies_checked': ['ultra_high_accuracy', 'news_trading', 'volatility_suite']
                }
                
        except Exception as e:
            logger.error(f"Error getting unified aggressive signal: {e}")
            return {
                'status': 'error',
                'message': f'Signal generation failed: {str(e)}'
            }
    
    def get_daily_trading_plan(self, df: pd.DataFrame, symbol: str = 'GBPUSD') -> dict:
        """
        Get comprehensive daily trading plan with your 20% risk model
        """
        if not self.use_unified_aggressive:
            return {
                'status': 'disabled',
                'message': 'Unified aggressive trading not enabled'
            }
        
        try:
            plan = self.unified_aggressive.get_daily_trading_plan(df, symbol)
            return {
                'status': 'success',
                'plan': plan
            }
        except Exception as e:
            logger.error(f"Error generating daily trading plan: {e}")
            return {
                'status': 'error',
                'message': f'Plan generation failed: {str(e)}'
            }


def get_realistic_base_price(symbol):
    """
    Get realistic base prices for different symbols
    Used when no historical data is available
    """
    base_prices = {
        'EURUSD': 1.0800,
        'GBPUSD': 1.2700,
        'USDJPY': 150.00,
        'USDCHF': 0.8900,
        'USDCAD': 1.3500,
        'AUDUSD': 0.6500,
        'NZDUSD': 0.6000,
        'XAUUSD': 2050.00,
        'XAGUSD': 24.00,
        'BTCUSD': 42000.00,
        'ETHUSD': 2200.00,
        'US30': 38000.00,
        'US500': 4900.00,
        'USTEC': 17000.00,
    }
    
    return base_prices.get(symbol, 1.0000)