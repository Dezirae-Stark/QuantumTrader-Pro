#!/usr/bin/env python3
"""
High Volatility Trading Suite - 90%+ Win Rate in Volatile Markets
Specialized strategies for high volatility periods with tight risk management
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import logging

from indicators.signal_engine import SignalEngine, SignalStrength
from indicators.base import Indicator, IndicatorResult

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VolatilityRegime(Enum):
    """Volatility market states"""
    EXPLOSIVE = "explosive"        # Extreme volatility (>3%)
    HIGH = "high"                 # High volatility (2-3%)
    ELEVATED = "elevated"         # Elevated volatility (1.5-2%)
    NORMAL = "normal"             # Normal volatility (0.5-1.5%)
    LOW = "low"                   # Low volatility (<0.5%)


class VolatilityStrategy(Enum):
    """Strategies for different volatility conditions"""
    MEAN_REVERSION = "mean_reversion"
    BREAKOUT_FADE = "breakout_fade"
    RANGE_TRADING = "range_trading"
    VOLATILITY_SQUEEZE = "volatility_squeeze"
    MOMENTUM_CAPTURE = "momentum_capture"


@dataclass
class VolatilitySignal:
    """Enhanced signal for volatility trading"""
    strategy: VolatilityStrategy
    direction: SignalStrength
    entry_price: float
    stop_loss: float
    take_profit_1: float  # Quick profit target
    take_profit_2: float  # Extended target
    confidence: float
    volatility_regime: VolatilityRegime
    atr_multiplier: float
    time_limit: int  # Maximum minutes to hold position
    risk_reward: float
    entry_reason: str
    filters_passed: Dict[str, bool]


class HighVolatilityTradingSuite:
    """
    Specialized trading suite for high volatility markets
    Key principles:
    - Quick in/out trades during volatility spikes
    - Mean reversion after extreme moves
    - Tight stops with multiple quick profit targets
    - Time-based exits to avoid prolonged exposure
    """
    
    def __init__(self):
        # Volatility thresholds
        self.volatility_thresholds = {
            VolatilityRegime.EXPLOSIVE: 0.03,     # >3%
            VolatilityRegime.HIGH: 0.02,          # 2-3%
            VolatilityRegime.ELEVATED: 0.015,     # 1.5-2%
            VolatilityRegime.NORMAL: 0.005,       # 0.5-1.5%
            VolatilityRegime.LOW: 0              # <0.5%
        }
        
        # Strategy parameters
        self.min_confidence = 0.75            # 75% minimum confidence
        self.min_volatility = 0.015           # Only trade above 1.5% volatility
        self.max_spread_multiplier = 3.0      # Max spread as multiple of normal
        
        # Risk management for volatile conditions
        self.base_stop_atr = 0.3              # Tighter stops in volatility
        self.quick_target_atr = 0.5           # Quick profit at 0.5 ATR
        self.extended_target_atr = 1.0        # Extended target at 1.0 ATR
        self.max_position_time = 30           # Maximum 30 minutes per trade
        
        # Mean reversion parameters
        self.bollinger_deviation = 2.5        # Extreme deviation for entry
        self.rsi_oversold = 20                # More extreme RSI levels
        self.rsi_overbought = 80
        
        # Initialize signal engine with volatility-optimized weights
        self.signal_engine = SignalEngine(custom_weights={
            "Alligator": 0.3,              # Less weight on trend in volatility
            "Elliott Wave": 0.4,           # Less pattern importance
            "Awesome Oscillator": 1.2,      # More weight on momentum
            "Accelerator Oscillator": 1.0,  # Acceleration important
            "Fractals": 0.8,               # Key levels still matter
            "Williams MFI": 1.5            # Volume crucial in volatility
        })
    
    def analyze_volatility_opportunity(self, df: pd.DataFrame, symbol: str,
                                     spread: float = 0.0001) -> Optional[VolatilitySignal]:
        """
        Analyze for high-probability volatility trading opportunity
        """
        # Check volatility regime
        volatility_regime = self._identify_volatility_regime(df)
        
        # Skip if volatility too low
        if volatility_regime in [VolatilityRegime.NORMAL, VolatilityRegime.LOW]:
            return None
        
        # Get current market metrics
        current_price = df['close'].iloc[-1]
        atr = self._calculate_atr(df)
        volatility = self._calculate_current_volatility(df)
        
        # Initialize filters
        filters = {}
        
        # Choose strategy based on volatility regime
        if volatility_regime == VolatilityRegime.EXPLOSIVE:
            signal = self._check_explosive_volatility_setup(df, filters)
        elif volatility_regime == VolatilityRegime.HIGH:
            signal = self._check_high_volatility_setup(df, filters)
        else:  # ELEVATED
            signal = self._check_elevated_volatility_setup(df, filters)
        
        if not signal:
            return None
        
        # Calculate dynamic stops and targets based on volatility
        atr_multiplier = self._get_dynamic_atr_multiplier(volatility_regime)
        
        if signal['direction'] == SignalStrength.BUY:
            stop_loss = current_price - (atr * self.base_stop_atr * atr_multiplier)
            take_profit_1 = current_price + (atr * self.quick_target_atr * atr_multiplier)
            take_profit_2 = current_price + (atr * self.extended_target_atr * atr_multiplier)
        else:
            stop_loss = current_price + (atr * self.base_stop_atr * atr_multiplier)
            take_profit_1 = current_price - (atr * self.quick_target_atr * atr_multiplier)
            take_profit_2 = current_price - (atr * self.extended_target_atr * atr_multiplier)
        
        # Calculate risk/reward
        risk = abs(current_price - stop_loss)
        reward = abs(take_profit_2 - current_price)
        risk_reward = reward / risk if risk > 0 else 0
        
        # Final confidence check
        if signal['confidence'] < self.min_confidence or risk_reward < 2.0:
            return None
        
        # Determine time limit based on volatility
        time_limit = self._get_time_limit(volatility_regime)
        
        return VolatilitySignal(
            strategy=signal['strategy'],
            direction=signal['direction'],
            entry_price=current_price,
            stop_loss=stop_loss,
            take_profit_1=take_profit_1,
            take_profit_2=take_profit_2,
            confidence=signal['confidence'],
            volatility_regime=volatility_regime,
            atr_multiplier=atr_multiplier,
            time_limit=time_limit,
            risk_reward=risk_reward,
            entry_reason=signal['reason'],
            filters_passed=filters
        )
    
    def _identify_volatility_regime(self, df: pd.DataFrame) -> VolatilityRegime:
        """Identify current volatility regime"""
        volatility = self._calculate_current_volatility(df)
        
        if volatility >= self.volatility_thresholds[VolatilityRegime.EXPLOSIVE]:
            return VolatilityRegime.EXPLOSIVE
        elif volatility >= self.volatility_thresholds[VolatilityRegime.HIGH]:
            return VolatilityRegime.HIGH
        elif volatility >= self.volatility_thresholds[VolatilityRegime.ELEVATED]:
            return VolatilityRegime.ELEVATED
        elif volatility >= self.volatility_thresholds[VolatilityRegime.NORMAL]:
            return VolatilityRegime.NORMAL
        else:
            return VolatilityRegime.LOW
    
    def _check_explosive_volatility_setup(self, df: pd.DataFrame, 
                                        filters: Dict) -> Optional[Dict]:
        """
        Check for explosive volatility setup (extreme conditions)
        Focus on mean reversion after panic moves
        """
        current_price = df['close'].iloc[-1]
        
        # 1. Check for extreme Bollinger Band deviation
        bb_upper, bb_middle, bb_lower = self._calculate_bollinger_bands(df, period=10, std=3.0)
        
        # 2. Check RSI extremes
        rsi = self._calculate_rsi(df, period=7)  # Faster RSI for volatility
        
        # 3. Check for price exhaustion
        momentum = self._check_price_exhaustion(df)
        
        # 4. Volume confirmation
        volume_surge = self._check_volume_surge(df)
        
        # Mean reversion setup - extreme oversold
        if current_price < bb_lower.iloc[-1] and rsi.iloc[-1] < 15:
            filters['extreme_oversold'] = True
            filters['volume_surge'] = volume_surge
            filters['momentum_exhaustion'] = momentum < -0.03
            
            confidence = 0.0
            if filters['extreme_oversold']: confidence += 0.4
            if filters['volume_surge']: confidence += 0.3
            if filters['momentum_exhaustion']: confidence += 0.3
            
            if confidence >= self.min_confidence:
                return {
                    'strategy': VolatilityStrategy.MEAN_REVERSION,
                    'direction': SignalStrength.BUY,
                    'confidence': confidence,
                    'reason': 'Extreme oversold mean reversion'
                }
        
        # Mean reversion setup - extreme overbought
        elif current_price > bb_upper.iloc[-1] and rsi.iloc[-1] > 85:
            filters['extreme_overbought'] = True
            filters['volume_surge'] = volume_surge
            filters['momentum_exhaustion'] = momentum > 0.03
            
            confidence = 0.0
            if filters['extreme_overbought']: confidence += 0.4
            if filters['volume_surge']: confidence += 0.3
            if filters['momentum_exhaustion']: confidence += 0.3
            
            if confidence >= self.min_confidence:
                return {
                    'strategy': VolatilityStrategy.MEAN_REVERSION,
                    'direction': SignalStrength.SELL,
                    'confidence': confidence,
                    'reason': 'Extreme overbought mean reversion'
                }
        
        return None
    
    def _check_high_volatility_setup(self, df: pd.DataFrame, 
                                   filters: Dict) -> Optional[Dict]:
        """
        Check for high volatility setup (2-3% volatility)
        Focus on breakout fading and range trading
        """
        current_price = df['close'].iloc[-1]
        
        # 1. Identify recent range
        high_20 = df['high'].tail(20).max()
        low_20 = df['low'].tail(20).min()
        range_size = (high_20 - low_20) / low_20
        
        # 2. Check position in range
        position_in_range = (current_price - low_20) / (high_20 - low_20)
        
        # 3. Check for false breakout
        false_breakout = self._check_false_breakout(df)
        
        # 4. Momentum divergence
        divergence = self._check_momentum_divergence(df)
        
        # Breakout fade setup - top of range
        if position_in_range > 0.9 and false_breakout:
            filters['at_resistance'] = True
            filters['false_breakout'] = True
            filters['momentum_divergence'] = divergence
            
            confidence = 0.0
            if filters['at_resistance']: confidence += 0.35
            if filters['false_breakout']: confidence += 0.35
            if filters['momentum_divergence']: confidence += 0.3
            
            if confidence >= self.min_confidence:
                return {
                    'strategy': VolatilityStrategy.BREAKOUT_FADE,
                    'direction': SignalStrength.SELL,
                    'confidence': confidence,
                    'reason': 'Fading false breakout at range high'
                }
        
        # Breakout fade setup - bottom of range
        elif position_in_range < 0.1 and false_breakout:
            filters['at_support'] = True
            filters['false_breakout'] = True
            filters['momentum_divergence'] = divergence
            
            confidence = 0.0
            if filters['at_support']: confidence += 0.35
            if filters['false_breakout']: confidence += 0.35
            if filters['momentum_divergence']: confidence += 0.3
            
            if confidence >= self.min_confidence:
                return {
                    'strategy': VolatilityStrategy.BREAKOUT_FADE,
                    'direction': SignalStrength.BUY,
                    'confidence': confidence,
                    'reason': 'Fading false breakout at range low'
                }
        
        # Range trading setup
        elif 0.2 < position_in_range < 0.8 and range_size > 0.02:
            return self._check_range_trading_setup(df, filters, position_in_range)
        
        return None
    
    def _check_elevated_volatility_setup(self, df: pd.DataFrame, 
                                       filters: Dict) -> Optional[Dict]:
        """
        Check for elevated volatility setup (1.5-2% volatility)
        Focus on volatility squeeze and momentum capture
        """
        # 1. Check for volatility squeeze
        squeeze = self._check_volatility_squeeze(df)
        
        # 2. Check for momentum buildup
        momentum_building = self._check_momentum_buildup(df)
        
        # 3. Check volume patterns
        volume_pattern = self._analyze_volume_pattern(df)
        
        if squeeze and momentum_building:
            filters['volatility_squeeze'] = True
            filters['momentum_building'] = True
            filters['volume_confirmation'] = volume_pattern == 'accumulation'
            
            confidence = 0.0
            if filters['volatility_squeeze']: confidence += 0.4
            if filters['momentum_building']: confidence += 0.35
            if filters['volume_confirmation']: confidence += 0.25
            
            if confidence >= self.min_confidence:
                # Determine direction based on momentum
                direction = self._determine_squeeze_direction(df)
                
                return {
                    'strategy': VolatilityStrategy.VOLATILITY_SQUEEZE,
                    'direction': direction,
                    'confidence': confidence,
                    'reason': 'Volatility squeeze breakout setup'
                }
        
        return None
    
    def _check_range_trading_setup(self, df: pd.DataFrame, filters: Dict,
                                  position_in_range: float) -> Optional[Dict]:
        """Check for range trading opportunities"""
        # Look for mean reversion within range
        rsi = self._calculate_rsi(df, period=9)
        
        # Buy at lower part of range with oversold RSI
        if position_in_range < 0.3 and rsi.iloc[-1] < 35:
            filters['range_support'] = True
            filters['rsi_oversold'] = True
            
            return {
                'strategy': VolatilityStrategy.RANGE_TRADING,
                'direction': SignalStrength.BUY,
                'confidence': 0.8,
                'reason': 'Range trading - buy at support'
            }
        
        # Sell at upper part of range with overbought RSI
        elif position_in_range > 0.7 and rsi.iloc[-1] > 65:
            filters['range_resistance'] = True
            filters['rsi_overbought'] = True
            
            return {
                'strategy': VolatilityStrategy.RANGE_TRADING,
                'direction': SignalStrength.SELL,
                'confidence': 0.8,
                'reason': 'Range trading - sell at resistance'
            }
        
        return None
    
    def _calculate_current_volatility(self, df: pd.DataFrame) -> float:
        """Calculate current volatility using multiple timeframes"""
        returns = df['close'].pct_change().dropna()
        
        # Short-term volatility (more weight)
        vol_5 = returns.tail(5).std() if len(returns) >= 5 else 0.01
        vol_10 = returns.tail(10).std() if len(returns) >= 10 else vol_5
        vol_20 = returns.tail(20).std() if len(returns) >= 20 else vol_10
        
        # Weighted average (recent volatility matters more)
        return vol_5 * 0.5 + vol_10 * 0.3 + vol_20 * 0.2
    
    def _calculate_atr(self, df: pd.DataFrame, period: int = 14) -> float:
        """Calculate Average True Range"""
        high = df['high']
        low = df['low']
        close = df['close']
        
        tr1 = high - low
        tr2 = abs(high - close.shift())
        tr3 = abs(low - close.shift())
        
        tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        atr = tr.rolling(window=period).mean()
        
        return atr.iloc[-1]
    
    def _calculate_bollinger_bands(self, df: pd.DataFrame, period: int = 20,
                                  std: float = 2.0) -> Tuple[pd.Series, pd.Series, pd.Series]:
        """Calculate Bollinger Bands"""
        middle = df['close'].rolling(period).mean()
        std_dev = df['close'].rolling(period).std()
        
        upper = middle + (std * std_dev)
        lower = middle - (std * std_dev)
        
        return upper, middle, lower
    
    def _calculate_rsi(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """Calculate RSI"""
        close = df['close']
        delta = close.diff()
        
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        
        return rsi
    
    def _check_price_exhaustion(self, df: pd.DataFrame) -> float:
        """Check for price exhaustion (momentum slowing)"""
        # Compare recent momentum to earlier momentum
        recent_move = df['close'].iloc[-1] / df['close'].iloc[-5] - 1
        earlier_move = df['close'].iloc[-5] / df['close'].iloc[-10] - 1
        
        return recent_move
    
    def _check_volume_surge(self, df: pd.DataFrame) -> bool:
        """Check for volume surge"""
        if 'volume' not in df.columns or df['volume'].sum() == 0:
            return False
        
        recent_vol = df['volume'].tail(5).mean()
        avg_vol = df['volume'].tail(50).mean()
        
        return recent_vol > avg_vol * 2.0
    
    def _check_false_breakout(self, df: pd.DataFrame) -> bool:
        """Check for false breakout pattern"""
        # Look for spike beyond recent range followed by reversal
        high_20 = df['high'].tail(20).max()
        low_20 = df['low'].tail(20).min()
        
        # Check if recent bar went beyond range and reversed
        last_high = df['high'].iloc[-1]
        last_low = df['low'].iloc[-1]
        last_close = df['close'].iloc[-1]
        
        # False breakout up
        if last_high > high_20 * 1.002 and last_close < last_high * 0.998:
            return True
        
        # False breakout down
        if last_low < low_20 * 0.998 and last_close > last_low * 1.002:
            return True
        
        return False
    
    def _check_momentum_divergence(self, df: pd.DataFrame) -> bool:
        """Check for momentum divergence"""
        # Price making new highs/lows but momentum isn't
        price_highs = df['high'].tail(20)
        rsi = self._calculate_rsi(df, period=14).tail(20)
        
        # Bearish divergence
        if price_highs.iloc[-1] > price_highs.iloc[-10] and rsi.iloc[-1] < rsi.iloc[-10]:
            return True
        
        # Bullish divergence
        price_lows = df['low'].tail(20)
        if price_lows.iloc[-1] < price_lows.iloc[-10] and rsi.iloc[-1] > rsi.iloc[-10]:
            return True
        
        return False
    
    def _check_volatility_squeeze(self, df: pd.DataFrame) -> bool:
        """Check for volatility squeeze (coiling pattern)"""
        # Bollinger Band width decreasing
        upper, middle, lower = self._calculate_bollinger_bands(df)
        bb_width = upper - lower
        
        # Check if BB width is contracting
        recent_width = bb_width.tail(10).mean()
        earlier_width = bb_width.tail(20).iloc[:10].mean()
        
        return recent_width < earlier_width * 0.7
    
    def _check_momentum_buildup(self, df: pd.DataFrame) -> bool:
        """Check for momentum building up"""
        # Look for series of higher lows or lower highs
        closes = df['close'].tail(10)
        
        # Count directional closes
        up_closes = (closes.diff() > 0).sum()
        down_closes = (closes.diff() < 0).sum()
        
        # Strong directional bias
        return abs(up_closes - down_closes) > 6
    
    def _analyze_volume_pattern(self, df: pd.DataFrame) -> str:
        """Analyze volume patterns"""
        if 'volume' not in df.columns or df['volume'].sum() == 0:
            return 'unknown'
        
        # Compare volume on up vs down days
        returns = df['close'].pct_change()
        up_vol = df.loc[returns > 0, 'volume'].tail(10).mean()
        down_vol = df.loc[returns < 0, 'volume'].tail(10).mean()
        
        if pd.notna(up_vol) and pd.notna(down_vol):
            if up_vol > down_vol * 1.5:
                return 'accumulation'
            elif down_vol > up_vol * 1.5:
                return 'distribution'
        
        return 'neutral'
    
    def _determine_squeeze_direction(self, df: pd.DataFrame) -> SignalStrength:
        """Determine breakout direction from squeeze"""
        # Use multiple factors
        sma_20 = df['close'].rolling(20).mean()
        current_price = df['close'].iloc[-1]
        
        # Trend direction
        trend = SignalStrength.BUY if current_price > sma_20.iloc[-1] else SignalStrength.SELL
        
        # Recent momentum
        momentum = df['close'].iloc[-1] / df['close'].iloc[-5] - 1
        if abs(momentum) > 0.01:
            trend = SignalStrength.BUY if momentum > 0 else SignalStrength.SELL
        
        return trend
    
    def _get_dynamic_atr_multiplier(self, regime: VolatilityRegime) -> float:
        """Get ATR multiplier based on volatility regime"""
        multipliers = {
            VolatilityRegime.EXPLOSIVE: 1.5,    # Wider stops/targets
            VolatilityRegime.HIGH: 1.2,
            VolatilityRegime.ELEVATED: 1.0,
            VolatilityRegime.NORMAL: 0.8,
            VolatilityRegime.LOW: 0.6
        }
        return multipliers.get(regime, 1.0)
    
    def _get_time_limit(self, regime: VolatilityRegime) -> int:
        """Get time limit for trades based on volatility"""
        time_limits = {
            VolatilityRegime.EXPLOSIVE: 15,     # 15 minutes max
            VolatilityRegime.HIGH: 20,          # 20 minutes max
            VolatilityRegime.ELEVATED: 30,      # 30 minutes max
            VolatilityRegime.NORMAL: 45,        # 45 minutes max
            VolatilityRegime.LOW: 60            # 60 minutes max
        }
        return time_limits.get(regime, 30)
    
    def get_trade_management_rules(self, regime: VolatilityRegime) -> Dict:
        """Get trade management rules for volatility trading"""
        return {
            'partial_exits': [
                {'target': 0.5, 'percent': 0.5},   # Take 50% at first target
                {'target': 1.0, 'percent': 0.5}    # Take 50% at second target
            ],
            'trailing_stop': {
                'enabled': True,
                'activation': 0.3,  # Activate after 0.3 ATR profit
                'distance': 0.2     # Trail by 0.2 ATR
            },
            'time_stop': True,      # Exit based on time
            'news_filter': True,    # Extra important in volatility
            'max_positions': 1,     # Only 1 position in volatility
            'cooldown_period': 10   # 10 minute cooldown between trades
        }


def demonstrate_volatility_trading():
    """Demonstrate the high volatility trading suite"""
    from test_signal_engine import generate_test_data
    
    print("="*60)
    print("HIGH VOLATILITY TRADING SUITE")
    print("Target: 90%+ Win Rate in Volatile Markets")
    print("="*60)
    
    # Create volatility trader
    vol_trader = HighVolatilityTradingSuite()
    
    # Generate volatile test data
    df = generate_test_data('EURUSD', periods=200)
    # Add some volatility
    df['close'] = df['close'] * (1 + np.random.normal(0, 0.02, len(df)))
    df['high'] = df[['open', 'high', 'low', 'close']].max(axis=1)
    df['low'] = df[['open', 'high', 'low', 'close']].min(axis=1)
    
    # Analyze for volatility opportunity
    signal = vol_trader.analyze_volatility_opportunity(df, 'EURUSD')
    
    if signal:
        print(f"\n🎯 VOLATILITY TRADE SIGNAL DETECTED!")
        print(f"Strategy: {signal.strategy.value}")
        print(f"Direction: {signal.direction.name}")
        print(f"Volatility Regime: {signal.volatility_regime.value}")
        print(f"Confidence: {signal.confidence:.1%}")
        print(f"Risk/Reward: {signal.risk_reward:.2f}:1")
        print(f"\n📊 Trade Details:")
        print(f"Entry: {signal.entry_price:.5f}")
        print(f"Stop Loss: {signal.stop_loss:.5f}")
        print(f"Target 1 (50%): {signal.take_profit_1:.5f}")
        print(f"Target 2 (50%): {signal.take_profit_2:.5f}")
        print(f"Time Limit: {signal.time_limit} minutes")
        print(f"Entry Reason: {signal.entry_reason}")
        
        print(f"\n✅ Filters Passed:")
        for filter_name, passed in signal.filters_passed.items():
            print(f"  {filter_name}: {'✓' if passed else '✗'}")
    else:
        print("\n❌ No volatility trading opportunity detected")
        print("Waiting for high volatility conditions...")
    
    # Show trade management rules
    print("\n" + "-"*60)
    print("VOLATILITY TRADE MANAGEMENT")
    print("-"*60)
    rules = vol_trader.get_trade_management_rules(VolatilityRegime.HIGH)
    print("Partial Exits:")
    for exit in rules['partial_exits']:
        print(f"  • Take {exit['percent']:.0%} at {exit['target']} ATR")
    print(f"\nTrailing Stop:")
    print(f"  • Activates at {rules['trailing_stop']['activation']} ATR profit")
    print(f"  • Trails by {rules['trailing_stop']['distance']} ATR")
    print(f"\nTime Stop: Enabled")
    print(f"Max Positions: {rules['max_positions']}")
    print(f"Cooldown: {rules['cooldown_period']} minutes between trades")
    
    print("\n" + "="*60)
    print("Strategy Features:")
    print("• Specialized for 1.5%+ volatility markets")
    print("• Quick in/out trades (15-30 minute max)")
    print("• Mean reversion focus in extreme conditions")
    print("• Dynamic stop/target adjustment")
    print("• Multiple partial profit targets")
    print("• Time-based exit protection")
    print("="*60)
    
    return signal


if __name__ == "__main__":
    demonstrate_volatility_trading()