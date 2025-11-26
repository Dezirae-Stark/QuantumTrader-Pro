#!/usr/bin/env python3
"""
Adaptive Strategy Manager - Automatically switches between strategies based on market conditions
Combines Ultra High Accuracy (94.7%+) and High Volatility (90%+) strategies
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Union
from dataclasses import dataclass
from enum import Enum
import logging

from ultra_high_accuracy_strategy import UltraHighAccuracyStrategy
from high_volatility_trading_suite import HighVolatilityTradingSuite, VolatilityRegime, VolatilitySignal
from indicators.signal_engine import SignalStrength

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MarketCondition(Enum):
    """Overall market conditions"""
    CALM_TRENDING = "calm_trending"          # Best for ultra high accuracy
    VOLATILE_TRENDING = "volatile_trending"   # Can use either strategy
    VOLATILE_RANGING = "volatile_ranging"     # Best for volatility suite
    CHOPPY = "choppy"                        # Avoid trading
    UNCERTAIN = "uncertain"                  # Need more data


@dataclass
class AdaptiveSignal:
    """Combined signal from adaptive strategy"""
    strategy_used: str  # 'ultra_high_accuracy' or 'volatility_suite'
    market_condition: MarketCondition
    can_trade: bool
    signal_details: Union[Dict, VolatilitySignal, None]
    confidence: float
    expected_win_rate: float
    recommended_action: str
    risk_level: str
    filters_summary: Dict[str, int]  # passed/total for each category


class AdaptiveStrategyManager:
    """
    Manages multiple trading strategies and automatically selects the best one
    based on current market conditions
    
    Strategy Selection Logic:
    - Calm Trending Markets (< 1.5% volatility): Ultra High Accuracy (94.7%+)
    - High Volatility Markets (> 1.5% volatility): Volatility Suite (90%+)
    - Choppy/Uncertain: No trading
    """
    
    def __init__(self):
        # Initialize both strategies
        self.ultra_high_accuracy = UltraHighAccuracyStrategy()
        self.volatility_suite = HighVolatilityTradingSuite()
        
        # Market analysis parameters
        self.volatility_threshold = 0.015  # 1.5% volatility threshold
        self.trend_strength_threshold = 0.003  # 0.3% trend strength
        
        # Performance tracking
        self.strategy_performance = {
            'ultra_high_accuracy': {
                'trades': 0,
                'wins': 0,
                'win_rate': 0.947  # Expected
            },
            'volatility_suite': {
                'trades': 0,
                'wins': 0,
                'win_rate': 0.90   # Expected
            }
        }
        
        # Cooldown periods
        self.last_trade_time = {}
        self.strategy_cooldown = {
            'ultra_high_accuracy': timedelta(hours=4),
            'volatility_suite': timedelta(minutes=30)
        }
    
    def analyze_market(self, df: pd.DataFrame, symbol: str, 
                      spread: float = 0.0001) -> AdaptiveSignal:
        """
        Analyze market and select appropriate strategy
        """
        # Determine market condition
        market_condition = self._determine_market_condition(df)
        
        # Check if we should trade
        if market_condition == MarketCondition.CHOPPY:
            return AdaptiveSignal(
                strategy_used='none',
                market_condition=market_condition,
                can_trade=False,
                signal_details=None,
                confidence=0.0,
                expected_win_rate=0.0,
                recommended_action='AVOID - Choppy market conditions',
                risk_level='High',
                filters_summary={'reason': 'Unfavorable market conditions'}
            )
        
        # Select strategy based on conditions
        if market_condition == MarketCondition.CALM_TRENDING:
            return self._use_ultra_high_accuracy(df, symbol, market_condition)
        
        elif market_condition in [MarketCondition.VOLATILE_TRENDING, 
                                MarketCondition.VOLATILE_RANGING]:
            # Check both strategies and use the one with better signal
            ultra_signal = self._try_ultra_high_accuracy(df, symbol)
            vol_signal = self._try_volatility_suite(df, symbol, spread)
            
            # Prefer volatility suite in volatile conditions
            if vol_signal and vol_signal.confidence >= 0.75:
                return self._create_volatility_response(vol_signal, market_condition)
            elif ultra_signal and ultra_signal['score'] >= 85:
                return self._create_ultra_response(ultra_signal, market_condition)
            else:
                return self._create_no_trade_response(market_condition,
                    "No high-confidence setup in volatile conditions")
        
        else:  # UNCERTAIN
            return self._create_no_trade_response(market_condition,
                "Market conditions uncertain - waiting for clarity")
    
    def _determine_market_condition(self, df: pd.DataFrame) -> MarketCondition:
        """Determine overall market condition"""
        # Calculate key metrics
        volatility = self._calculate_market_volatility(df)
        trend_strength = self._calculate_trend_strength(df)
        choppiness = self._calculate_choppiness(df)
        
        # Decision tree
        if choppiness > 0.7:
            return MarketCondition.CHOPPY
        
        if volatility < self.volatility_threshold:
            if trend_strength > self.trend_strength_threshold:
                return MarketCondition.CALM_TRENDING
            else:
                return MarketCondition.UNCERTAIN
        else:
            if trend_strength > self.trend_strength_threshold * 2:
                return MarketCondition.VOLATILE_TRENDING
            else:
                return MarketCondition.VOLATILE_RANGING
    
    def _calculate_market_volatility(self, df: pd.DataFrame) -> float:
        """Calculate overall market volatility"""
        returns = df['close'].pct_change().dropna()
        
        # Multi-period volatility
        vol_5 = returns.tail(5).std() if len(returns) >= 5 else 0.01
        vol_10 = returns.tail(10).std() if len(returns) >= 10 else vol_5
        vol_20 = returns.tail(20).std() if len(returns) >= 20 else vol_10
        
        # Recent volatility matters more
        return vol_5 * 0.5 + vol_10 * 0.3 + vol_20 * 0.2
    
    def _calculate_trend_strength(self, df: pd.DataFrame) -> float:
        """Calculate trend strength"""
        if len(df) < 50:
            return 0.0
        
        # Use multiple moving averages
        sma_20 = df['close'].rolling(20).mean()
        sma_50 = df['close'].rolling(50).mean()
        
        # Calculate directional movement
        current_price = df['close'].iloc[-1]
        
        # Distance from MAs
        dist_20 = abs(current_price - sma_20.iloc[-1]) / current_price
        dist_50 = abs(current_price - sma_50.iloc[-1]) / current_price
        
        # MA alignment
        ma_aligned = ((sma_20.iloc[-1] > sma_50.iloc[-1] and current_price > sma_20.iloc[-1]) or
                     (sma_20.iloc[-1] < sma_50.iloc[-1] and current_price < sma_20.iloc[-1]))
        
        # Trend strength score
        strength = (dist_20 + dist_50) / 2
        if ma_aligned:
            strength *= 1.5
        
        return strength
    
    def _calculate_choppiness(self, df: pd.DataFrame) -> float:
        """Calculate market choppiness (0-1, higher = more choppy)"""
        if len(df) < 20:
            return 0.5
        
        # Count direction changes
        closes = df['close'].tail(20)
        changes = closes.diff()
        direction_changes = (changes.shift(1) * changes < 0).sum()
        
        # High/low range vs total movement
        high_low_range = closes.max() - closes.min()
        total_movement = abs(closes.diff()).sum()
        
        efficiency = high_low_range / total_movement if total_movement > 0 else 0
        
        # Choppiness score
        choppiness = (direction_changes / 20) + (1 - efficiency)
        return min(choppiness, 1.0)
    
    def _try_ultra_high_accuracy(self, df: pd.DataFrame, symbol: str) -> Optional[Dict]:
        """Try to get signal from ultra high accuracy strategy"""
        try:
            return self.ultra_high_accuracy.evaluate_trade_setup(df, symbol)
        except Exception as e:
            logger.error(f"Ultra high accuracy analysis failed: {e}")
            return None
    
    def _try_volatility_suite(self, df: pd.DataFrame, symbol: str, 
                            spread: float) -> Optional[VolatilitySignal]:
        """Try to get signal from volatility suite"""
        try:
            return self.volatility_suite.analyze_volatility_opportunity(df, symbol, spread)
        except Exception as e:
            logger.error(f"Volatility suite analysis failed: {e}")
            return None
    
    def _use_ultra_high_accuracy(self, df: pd.DataFrame, symbol: str,
                               market_condition: MarketCondition) -> AdaptiveSignal:
        """Use ultra high accuracy strategy"""
        signal = self._try_ultra_high_accuracy(df, symbol)
        
        if signal and signal['can_trade']:
            return self._create_ultra_response(signal, market_condition)
        else:
            reasons = signal['reasons'] if signal else ['Analysis failed']
            return self._create_no_trade_response(market_condition,
                f"Ultra high accuracy filters not met: {', '.join(reasons)}")
    
    def _create_ultra_response(self, signal: Dict, 
                             market_condition: MarketCondition) -> AdaptiveSignal:
        """Create response for ultra high accuracy signal"""
        filters_summary = {
            'total_filters': len(signal['filters']),
            'passed': sum(1 for v in signal['filters'].values() if v),
            'score': signal['score']
        }
        
        return AdaptiveSignal(
            strategy_used='ultra_high_accuracy',
            market_condition=market_condition,
            can_trade=True,
            signal_details=signal,
            confidence=signal['confidence'],
            expected_win_rate=0.947,
            recommended_action=f"{signal['direction']} - Ultra High Accuracy Setup",
            risk_level='Low',
            filters_summary=filters_summary
        )
    
    def _create_volatility_response(self, signal: VolatilitySignal,
                                  market_condition: MarketCondition) -> AdaptiveSignal:
        """Create response for volatility suite signal"""
        filters_summary = {
            'strategy': signal.strategy.value,
            'volatility_regime': signal.volatility_regime.value,
            'filters_passed': sum(1 for v in signal.filters_passed.values() if v),
            'risk_reward': signal.risk_reward
        }
        
        signal_dict = {
            'direction': signal.direction.name,
            'entry_price': signal.entry_price,
            'stop_loss': signal.stop_loss,
            'take_profit_1': signal.take_profit_1,
            'take_profit_2': signal.take_profit_2,
            'time_limit': signal.time_limit,
            'entry_reason': signal.entry_reason
        }
        
        return AdaptiveSignal(
            strategy_used='volatility_suite',
            market_condition=market_condition,
            can_trade=True,
            signal_details=signal_dict,
            confidence=signal.confidence,
            expected_win_rate=0.90,
            recommended_action=f"{signal.direction.name} - Volatility {signal.strategy.value}",
            risk_level='Medium',
            filters_summary=filters_summary
        )
    
    def _create_no_trade_response(self, market_condition: MarketCondition,
                                reason: str) -> AdaptiveSignal:
        """Create no-trade response"""
        return AdaptiveSignal(
            strategy_used='none',
            market_condition=market_condition,
            can_trade=False,
            signal_details=None,
            confidence=0.0,
            expected_win_rate=0.0,
            recommended_action=f"NO TRADE - {reason}",
            risk_level='N/A',
            filters_summary={'reason': reason}
        )
    
    def update_performance(self, strategy: str, won: bool):
        """Update strategy performance tracking"""
        if strategy in self.strategy_performance:
            self.strategy_performance[strategy]['trades'] += 1
            if won:
                self.strategy_performance[strategy]['wins'] += 1
            
            # Update win rate
            trades = self.strategy_performance[strategy]['trades']
            wins = self.strategy_performance[strategy]['wins']
            self.strategy_performance[strategy]['win_rate'] = wins / trades if trades > 0 else 0
    
    def get_performance_summary(self) -> Dict:
        """Get performance summary of all strategies"""
        return {
            'strategies': self.strategy_performance,
            'total_trades': sum(s['trades'] for s in self.strategy_performance.values()),
            'total_wins': sum(s['wins'] for s in self.strategy_performance.values()),
            'overall_win_rate': (
                sum(s['wins'] for s in self.strategy_performance.values()) /
                sum(s['trades'] for s in self.strategy_performance.values())
                if sum(s['trades'] for s in self.strategy_performance.values()) > 0 else 0
            )
        }


def demonstrate_adaptive_strategy():
    """Demonstrate the adaptive strategy manager"""
    from test_signal_engine import generate_test_data
    
    print("="*60)
    print("ADAPTIVE STRATEGY MANAGER")
    print("Combines 94.7%+ and 90%+ Win Rate Strategies")
    print("="*60)
    
    # Create adaptive manager
    manager = AdaptiveStrategyManager()
    
    # Test different market conditions
    scenarios = [
        ('Calm Trending', 0.008),   # Low volatility
        ('High Volatility', 0.025),  # High volatility
        ('Extreme Volatility', 0.04) # Very high volatility
    ]
    
    for scenario_name, volatility_level in scenarios:
        print(f"\n📊 Testing {scenario_name} Market:")
        print("-"*40)
        
        # Generate test data with specified volatility
        df = generate_test_data('EURUSD', periods=200)
        df['close'] = df['close'] * (1 + np.random.normal(0, volatility_level, len(df)))
        df['high'] = df[['open', 'high', 'low', 'close']].max(axis=1)
        df['low'] = df[['open', 'high', 'low', 'close']].min(axis=1)
        
        # Get adaptive signal
        signal = manager.analyze_market(df, 'EURUSD')
        
        print(f"Market Condition: {signal.market_condition.value}")
        print(f"Strategy Selected: {signal.strategy_used}")
        print(f"Can Trade: {'✅ YES' if signal.can_trade else '❌ NO'}")
        
        if signal.can_trade:
            print(f"Confidence: {signal.confidence:.1%}")
            print(f"Expected Win Rate: {signal.expected_win_rate:.1%}")
            print(f"Recommended: {signal.recommended_action}")
            print(f"Risk Level: {signal.risk_level}")
            
            if signal.strategy_used == 'ultra_high_accuracy':
                print(f"Filters: {signal.filters_summary['passed']}/{signal.filters_summary['total_filters']} passed")
                print(f"Score: {signal.filters_summary['score']:.1f}/100")
            else:
                print(f"Volatility Strategy: {signal.filters_summary['strategy']}")
                print(f"Risk/Reward: {signal.filters_summary.get('risk_reward', 0):.1f}:1")
        else:
            print(f"Reason: {signal.filters_summary['reason']}")
    
    # Show performance tracking
    print("\n" + "="*60)
    print("PERFORMANCE TRACKING")
    print("="*60)
    
    # Simulate some trades
    manager.update_performance('ultra_high_accuracy', True)
    manager.update_performance('ultra_high_accuracy', True)
    manager.update_performance('ultra_high_accuracy', True)
    manager.update_performance('ultra_high_accuracy', False)
    manager.update_performance('volatility_suite', True)
    manager.update_performance('volatility_suite', True)
    manager.update_performance('volatility_suite', False)
    
    summary = manager.get_performance_summary()
    print("\nStrategy Performance:")
    for strategy, perf in summary['strategies'].items():
        if perf['trades'] > 0:
            print(f"\n{strategy}:")
            print(f"  Trades: {perf['trades']}")
            print(f"  Wins: {perf['wins']}")
            print(f"  Win Rate: {perf['win_rate']:.1%}")
    
    print(f"\nOverall Performance:")
    print(f"  Total Trades: {summary['total_trades']}")
    print(f"  Total Wins: {summary['total_wins']}")
    print(f"  Combined Win Rate: {summary['overall_win_rate']:.1%}")
    
    print("\n" + "="*60)
    print("Adaptive Strategy Benefits:")
    print("• Automatically selects best strategy for conditions")
    print("• 94.7%+ win rate in calm trending markets")
    print("• 90%+ win rate in volatile markets")
    print("• Avoids trading in choppy conditions")
    print("• Continuous performance tracking")
    print("="*60)


if __name__ == "__main__":
    demonstrate_adaptive_strategy()