#!/usr/bin/env python3
"""
Advanced Feature Engineering for QuantumTrader Pro
Extracts 50+ predictive features from market data
"""

import pandas as pd
import numpy as np
from ta.trend import ADXIndicator, MACD, SMAIndicator, EMAIndicator
from ta.momentum import RSIIndicator, StochasticOscillator, WilliamsRIndicator
from ta.volatility import BollingerBands, AverageTrueRange
from ta.volume import OnBalanceVolumeIndicator, MFIIndicator


class AdvancedFeatureEngineer:
    """
    Comprehensive feature engineering for trading signals
    """

    def __init__(self):
        self.features = []

    def extract_all_features(self, df):
        """
        Extract all features from OHLCV data

        Args:
            df: DataFrame with columns ['open', 'high', 'low', 'close', 'volume']

        Returns:
            DataFrame with 50+ engineered features
        """
        features_df = pd.DataFrame(index=df.index)

        # 1. Trend Indicators
        features_df = self._add_trend_features(df, features_df)

        # 2. Momentum Indicators
        features_df = self._add_momentum_features(df, features_df)

        # 3. Volatility Indicators
        features_df = self._add_volatility_features(df, features_df)

        # 4. Volume Indicators
        features_df = self._add_volume_features(df, features_df)

        # 5. Price Action Features
        features_df = self._add_price_action_features(df, features_df)

        # 6. Time-based Features
        features_df = self._add_time_features(df, features_df)

        # 7. Statistical Features
        features_df = self._add_statistical_features(df, features_df)

        return features_df

    def _add_trend_features(self, df, features_df):
        """Add trend-following indicators"""

        # ADX - Trend strength
        adx = ADXIndicator(df['high'], df['low'], df['close'], window=14)
        features_df['adx'] = adx.adx()
        features_df['adx_pos'] = adx.adx_pos()
        features_df['adx_neg'] = adx.adx_neg()

        # MACD
        macd = MACD(df['close'])
        features_df['macd'] = macd.macd()
        features_df['macd_signal'] = macd.macd_signal()
        features_df['macd_diff'] = macd.macd_diff()

        # Moving Averages
        for period in [10, 20, 50, 100, 200]:
            features_df[f'sma_{period}'] = SMAIndicator(df['close'], window=period).sma_indicator()
            features_df[f'ema_{period}'] = EMAIndicator(df['close'], window=period).ema_indicator()
            features_df[f'price_to_sma_{period}'] = df['close'] / features_df[f'sma_{period}']

        # MA Crossovers
        features_df['sma_20_50_cross'] = (features_df['sma_20'] > features_df['sma_50']).astype(int)
        features_df['ema_10_20_cross'] = (features_df['ema_10'] > features_df['ema_20']).astype(int)

        return features_df

    def _add_momentum_features(self, df, features_df):
        """Add momentum indicators"""

        # RSI
        for period in [7, 14, 21]:
            features_df[f'rsi_{period}'] = RSIIndicator(df['close'], window=period).rsi()

        # Stochastic
        stoch = StochasticOscillator(df['high'], df['low'], df['close'])
        features_df['stoch_k'] = stoch.stoch()
        features_df['stoch_d'] = stoch.stoch_signal()

        # Williams %R
        features_df['williams_r'] = WilliamsRIndicator(df['high'], df['low'], df['close']).williams_r()

        # Rate of Change
        for period in [5, 10, 20]:
            features_df[f'roc_{period}'] = df['close'].pct_change(period) * 100

        # Momentum
        features_df['momentum_10'] = df['close'] - df['close'].shift(10)

        return features_df

    def _add_volatility_features(self, df, features_df):
        """Add volatility indicators"""

        # Bollinger Bands
        bb = BollingerBands(df['close'], window=20, window_dev=2)
        features_df['bb_upper'] = bb.bollinger_hband()
        features_df['bb_middle'] = bb.bollinger_mavg()
        features_df['bb_lower'] = bb.bollinger_lband()
        features_df['bb_width'] = bb.bollinger_wband()
        features_df['bb_pband'] = bb.bollinger_pband()

        # ATR
        atr = AverageTrueRange(df['high'], df['low'], df['close'], window=14)
        features_df['atr'] = atr.average_true_range()
        features_df['atr_percent'] = (features_df['atr'] / df['close']) * 100

        # Historical Volatility
        for period in [10, 20, 30]:
            returns = df['close'].pct_change()
            features_df[f'volatility_{period}'] = returns.rolling(window=period).std() * np.sqrt(252)

        return features_df

    def _add_volume_features(self, df, features_df):
        """Add volume-based indicators"""

        # Volume SMA ratio
        features_df['volume_sma_20'] = df['volume'].rolling(window=20).mean()
        features_df['volume_ratio'] = df['volume'] / features_df['volume_sma_20']

        # OBV
        features_df['obv'] = OnBalanceVolumeIndicator(df['close'], df['volume']).on_balance_volume()

        # MFI
        features_df['mfi'] = MFIIndicator(df['high'], df['low'], df['close'], df['volume']).money_flow_index()

        # Volume price trend
        features_df['vpt'] = (df['volume'] * ((df['close'] - df['close'].shift(1)) / df['close'].shift(1))).cumsum()

        return features_df

    def _add_price_action_features(self, df, features_df):
        """Add price action patterns"""

        # Candle body and wicks
        features_df['body'] = abs(df['close'] - df['open'])
        features_df['upper_wick'] = df['high'] - df[['close', 'open']].max(axis=1)
        features_df['lower_wick'] = df[['close', 'open']].min(axis=1) - df['low']

        # Candle patterns
        features_df['is_bullish'] = (df['close'] > df['open']).astype(int)
        features_df['is_doji'] = (features_df['body'] < (df['high'] - df['low']) * 0.1).astype(int)

        # Higher highs / Lower lows
        features_df['higher_high'] = (df['high'] > df['high'].shift(1)).astype(int)
        features_df['lower_low'] = (df['low'] < df['low'].shift(1)).astype(int)

        # Support and Resistance (simplified)
        features_df['resistance'] = df['high'].rolling(window=20).max()
        features_df['support'] = df['low'].rolling(window=20).min()
        features_df['distance_to_resistance'] = (features_df['resistance'] - df['close']) / df['close']
        features_df['distance_to_support'] = (df['close'] - features_df['support']) / df['close']

        return features_df

    def _add_time_features(self, df, features_df):
        """Add time-based features"""

        if isinstance(df.index, pd.DatetimeIndex):
            features_df['hour'] = df.index.hour
            features_df['day_of_week'] = df.index.dayofweek
            features_df['day_of_month'] = df.index.day
            features_df['month'] = df.index.month

            # Trading sessions
            features_df['is_asian_session'] = ((df.index.hour >= 0) & (df.index.hour < 8)).astype(int)
            features_df['is_london_session'] = ((df.index.hour >= 8) & (df.index.hour < 16)).astype(int)
            features_df['is_ny_session'] = ((df.index.hour >= 13) & (df.index.hour < 21)).astype(int)

        return features_df

    def _add_statistical_features(self, df, features_df):
        """Add statistical features"""

        # Returns
        features_df['returns_1'] = df['close'].pct_change(1)
        features_df['returns_5'] = df['close'].pct_change(5)
        features_df['returns_10'] = df['close'].pct_change(10)

        # Z-score
        for period in [20, 50]:
            mean = df['close'].rolling(window=period).mean()
            std = df['close'].rolling(window=period).std()
            features_df[f'zscore_{period}'] = (df['close'] - mean) / std

        # Correlation with lagged prices
        for lag in [1, 5, 10]:
            features_df[f'autocorr_{lag}'] = df['close'].rolling(window=20).apply(
                lambda x: x.autocorr(lag=lag), raw=False
            )

        return features_df

    def get_feature_importance(self, model, feature_names):
        """
        Get feature importance from trained model
        """
        if hasattr(model, 'feature_importances_'):
            importance = pd.DataFrame({
                'feature': feature_names,
                'importance': model.feature_importances_
            }).sort_values('importance', ascending=False)
            return importance
        return None


def create_sample_features(csv_path='predictions/predictions.csv'):
    """
    Create sample feature extraction from CSV
    """
    # This is a placeholder - in production, you'd load actual OHLCV data
    print("📊 Advanced Feature Engineering Demo")
    print("=" * 50)

    # Sample data
    dates = pd.date_range('2024-01-01', periods=200, freq='1H')
    sample_data = pd.DataFrame({
        'open': np.random.randn(200).cumsum() + 100,
        'high': np.random.randn(200).cumsum() + 101,
        'low': np.random.randn(200).cumsum() + 99,
        'close': np.random.randn(200).cumsum() + 100,
        'volume': np.random.randint(1000, 10000, 200)
    }, index=dates)

    # Extract features
    engineer = AdvancedFeatureEngineer()
    features = engineer.extract_all_features(sample_data)

    print(f"✅ Extracted {len(features.columns)} features")
    print(f"\nFeature categories:")
    print(f"  - Trend indicators: ADX, MACD, MAs")
    print(f"  - Momentum: RSI, Stochastic, Williams %R")
    print(f"  - Volatility: Bollinger Bands, ATR")
    print(f"  - Volume: OBV, MFI, Volume ratios")
    print(f"  - Price Action: Candle patterns, S/R")
    print(f"  - Time: Sessions, hours, days")
    print(f"  - Statistical: Returns, Z-scores, correlations")

    print(f"\n📈 Sample features (last 5 rows):")
    print(features[['adx', 'rsi_14', 'macd', 'bb_pband', 'atr_percent']].tail())

    return features


if __name__ == '__main__':
    features = create_sample_features()
    print("\n✅ Feature engineering module ready!")
    print("💡 Use these features to train your ML models for better predictions")
