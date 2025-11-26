"""
Modular Signal Engine Architecture
Integrates multiple indicators into a unified probability layer
"""
import pandas as pd
import numpy as np
from datetime import datetime
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
from .base import Indicator, IndicatorResult, SignalStrength
from .chaos_indicators import (
    AlligatorIndicator,
    AwesomeOscillator,
    AcceleratorOscillator,
    FractalsIndicator,
    WilliamsMFI
)
from .elliott_wave import ElliottWaveDetector


class SignalWeight(Enum):
    """Weight categories for different indicator types"""
    PRIMARY = 1.0      # Primary trend indicators
    SECONDARY = 0.7    # Momentum/oscillator indicators
    CONFIRMING = 0.5   # Confirming indicators
    PATTERN = 0.8      # Pattern-based indicators
    VOLUME = 0.6       # Volume-based indicators


@dataclass
class SignalConfiguration:
    """Configuration for a single indicator in the engine"""
    indicator: Indicator
    weight: float
    category: SignalWeight
    enabled: bool = True
    min_confidence: float = 0.3  # Minimum confidence to include signal
    
    
@dataclass
class CombinedSignal:
    """Combined signal from multiple indicators"""
    timestamp: datetime
    symbol: str
    signal: SignalStrength
    confidence: float
    probability: float  # 0-100%
    indicators_used: int
    contributing_signals: Dict[str, Dict]
    market_condition: str
    recommended_action: str
    risk_level: str


class SignalEngine:
    """
    Modular signal engine that combines multiple indicators
    into a unified trading signal with probability assessment
    """
    
    def __init__(self, custom_weights: Optional[Dict[str, float]] = None):
        # Initialize default indicator configurations
        self.configurations = self._create_default_configurations()
        
        # Apply custom weights if provided
        if custom_weights:
            self._apply_custom_weights(custom_weights)
            
        # Market condition tracker
        self.market_conditions = {
            'trending': 0.0,
            'ranging': 0.0,
            'volatile': 0.0,
            'calm': 0.0
        }
        
        # Risk management parameters
        self.risk_thresholds = {
            'low': 0.7,      # > 70% confidence
            'medium': 0.5,   # 50-70% confidence
            'high': 0.3      # < 50% confidence
        }
        
    def _create_default_configurations(self) -> List[SignalConfiguration]:
        """Create default indicator configurations"""
        return [
            # Trend indicators
            SignalConfiguration(
                indicator=AlligatorIndicator(),
                weight=1.0,
                category=SignalWeight.PRIMARY
            ),
            
            # Momentum indicators
            SignalConfiguration(
                indicator=AwesomeOscillator(),
                weight=0.7,
                category=SignalWeight.SECONDARY
            ),
            SignalConfiguration(
                indicator=AcceleratorOscillator(),
                weight=0.7,
                category=SignalWeight.SECONDARY
            ),
            
            # Pattern indicators
            SignalConfiguration(
                indicator=FractalsIndicator(),
                weight=0.8,
                category=SignalWeight.PATTERN
            ),
            SignalConfiguration(
                indicator=ElliottWaveDetector(),
                weight=0.8,
                category=SignalWeight.PATTERN
            ),
            
            # Volume indicators
            SignalConfiguration(
                indicator=WilliamsMFI(),
                weight=0.6,
                category=SignalWeight.VOLUME
            )
        ]
    
    def _apply_custom_weights(self, custom_weights: Dict[str, float]):
        """Apply custom weights to indicators"""
        for config in self.configurations:
            if config.indicator.name in custom_weights:
                config.weight = custom_weights[config.indicator.name]
    
    def add_indicator(self, indicator: Indicator, weight: float = 0.5,
                     category: SignalWeight = SignalWeight.CONFIRMING):
        """Add a custom indicator to the engine"""
        self.configurations.append(SignalConfiguration(
            indicator=indicator,
            weight=weight,
            category=category
        ))
    
    def remove_indicator(self, name: str):
        """Remove an indicator by name"""
        self.configurations = [c for c in self.configurations 
                              if c.indicator.name != name]
    
    def toggle_indicator(self, name: str, enabled: bool):
        """Enable or disable an indicator"""
        for config in self.configurations:
            if config.indicator.name == name:
                config.enabled = enabled
                break
    
    def get_required_periods(self) -> int:
        """Get maximum required periods from all enabled indicators"""
        enabled_configs = [c for c in self.configurations if c.enabled]
        if not enabled_configs:
            return 50  # Default minimum
        return max(c.indicator.get_required_periods() for c in enabled_configs)
    
    def analyze(self, df: pd.DataFrame, symbol: str) -> CombinedSignal:
        """
        Analyze market data using all enabled indicators
        Returns a combined signal with probability assessment
        """
        # Validate data
        if len(df) < self.get_required_periods():
            raise ValueError(f"Insufficient data: need at least {self.get_required_periods()} periods")
        
        # Calculate all indicator signals
        results = self._calculate_all_indicators(df, symbol)
        
        if not results:
            return self._create_neutral_signal(symbol)
        
        # Analyze market condition
        market_condition = self._analyze_market_condition(df, results)
        
        # Combine signals with adaptive weighting
        combined = self._combine_signals(results, market_condition)
        
        # Calculate probability
        probability = self._calculate_probability(combined, results)
        
        # Determine recommended action
        action = self._determine_action(combined['signal'], probability)
        
        # Assess risk level
        risk_level = self._assess_risk(combined['confidence'], probability)
        
        # Prepare contributing signals
        contributing = self._prepare_contributing_signals(results)
        
        return CombinedSignal(
            timestamp=datetime.now(),
            symbol=symbol,
            signal=combined['signal'],
            confidence=combined['confidence'],
            probability=probability,
            indicators_used=len(results),
            contributing_signals=contributing,
            market_condition=market_condition,
            recommended_action=action,
            risk_level=risk_level
        )
    
    def _calculate_all_indicators(self, df: pd.DataFrame, 
                                 symbol: str) -> List[Tuple[SignalConfiguration, IndicatorResult]]:
        """Calculate signals from all enabled indicators"""
        results = []
        
        for config in self.configurations:
            if not config.enabled:
                continue
                
            try:
                result = config.indicator.calculate(df, symbol)
                if result and result.confidence >= config.min_confidence:
                    results.append((config, result))
            except Exception as e:
                print(f"Error calculating {config.indicator.name}: {e}")
                continue
                
        return results
    
    def _analyze_market_condition(self, df: pd.DataFrame, 
                                 results: List[Tuple[SignalConfiguration, IndicatorResult]]) -> str:
        """Analyze current market condition"""
        # Calculate volatility
        returns = df['close'].pct_change().dropna()
        volatility = returns.std()
        avg_volatility = returns.rolling(20).std().mean()
        
        # Calculate trend strength using ADX concept
        high_low = df['high'] - df['low']
        high_close = abs(df['high'] - df['close'].shift())
        low_close = abs(df['low'] - df['close'].shift())
        true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        atr = true_range.rolling(14).mean().iloc[-1]
        
        # Analyze indicator agreement
        signals = [r.signal.value for _, r in results]
        signal_std = np.std(signals) if signals else 0
        
        # Update market conditions
        if volatility > avg_volatility * 1.5:
            self.market_conditions['volatile'] = 0.8
            self.market_conditions['calm'] = 0.2
        else:
            self.market_conditions['volatile'] = 0.2
            self.market_conditions['calm'] = 0.8
            
        if signal_std < 0.5:  # High agreement = trending
            self.market_conditions['trending'] = 0.8
            self.market_conditions['ranging'] = 0.2
        else:
            self.market_conditions['trending'] = 0.2
            self.market_conditions['ranging'] = 0.8
            
        # Determine primary condition
        primary_condition = max(self.market_conditions.items(), 
                               key=lambda x: x[1])[0]
        
        return primary_condition
    
    def _combine_signals(self, results: List[Tuple[SignalConfiguration, IndicatorResult]], 
                        market_condition: str) -> Dict:
        """Combine signals with adaptive weighting based on market condition"""
        if not results:
            return {'signal': SignalStrength.NEUTRAL, 'confidence': 0.5}
        
        # Adjust weights based on market condition
        adjusted_weights = self._adjust_weights_for_market(results, market_condition)
        
        # Calculate weighted signal
        total_weight = 0
        weighted_signal = 0
        weighted_confidence = 0
        
        for i, (config, result) in enumerate(results):
            weight = adjusted_weights[i]
            total_weight += weight
            weighted_signal += result.signal.value * weight * result.confidence
            weighted_confidence += result.confidence * weight
        
        if total_weight > 0:
            final_signal_value = weighted_signal / total_weight
            final_confidence = weighted_confidence / total_weight
        else:
            final_signal_value = 0
            final_confidence = 0.5
        
        # Convert to signal strength
        signal = self._value_to_signal_strength(final_signal_value)
        
        return {
            'signal': signal,
            'confidence': final_confidence,
            'raw_value': final_signal_value
        }
    
    def _adjust_weights_for_market(self, results: List[Tuple[SignalConfiguration, IndicatorResult]], 
                                  condition: str) -> List[float]:
        """Adjust indicator weights based on market condition"""
        adjusted = []
        
        for config, result in results:
            base_weight = config.weight
            
            # Adjust based on market condition
            if condition == 'trending':
                if config.category == SignalWeight.PRIMARY:
                    base_weight *= 1.2  # Boost trend indicators
                elif config.category == SignalWeight.SECONDARY:
                    base_weight *= 0.8  # Reduce oscillators
            elif condition == 'ranging':
                if config.category == SignalWeight.SECONDARY:
                    base_weight *= 1.2  # Boost oscillators
                elif config.category == SignalWeight.PRIMARY:
                    base_weight *= 0.8  # Reduce trend indicators
            elif condition == 'volatile':
                if config.category == SignalWeight.VOLUME:
                    base_weight *= 1.1  # Slight boost to volume
                    
            adjusted.append(base_weight)
            
        return adjusted
    
    def _value_to_signal_strength(self, value: float) -> SignalStrength:
        """Convert numerical value to SignalStrength enum"""
        if value >= 1.5:
            return SignalStrength.STRONG_BUY
        elif value >= 0.5:
            return SignalStrength.BUY
        elif value <= -1.5:
            return SignalStrength.STRONG_SELL
        elif value <= -0.5:
            return SignalStrength.SELL
        else:
            return SignalStrength.NEUTRAL
    
    def _calculate_probability(self, combined: Dict, 
                              results: List[Tuple[SignalConfiguration, IndicatorResult]]) -> float:
        """Calculate probability of signal success (0-100%)"""
        base_probability = 50.0  # Start neutral
        
        # Adjust based on confidence
        confidence_boost = (combined['confidence'] - 0.5) * 40  # ±20%
        base_probability += confidence_boost
        
        # Adjust based on indicator agreement
        if results:
            signals = [r.signal.value for _, r in results]
            agreement = 1 - (np.std(signals) / 2)  # 0-1 scale
            agreement_boost = (agreement - 0.5) * 30  # ±15%
            base_probability += agreement_boost
        
        # Adjust based on signal strength
        strength_boost = abs(combined['raw_value']) * 10  # up to ±20%
        if combined['raw_value'] > 0:
            base_probability += strength_boost
        else:
            base_probability -= strength_boost
            
        # Apply market condition modifier
        if self.market_conditions['trending'] > 0.6:
            base_probability *= 1.1  # 10% boost in trending markets
        elif self.market_conditions['volatile'] > 0.6:
            base_probability *= 0.9  # 10% reduction in volatile markets
            
        # Ensure within bounds
        return np.clip(base_probability, 0, 100)
    
    def _determine_action(self, signal: SignalStrength, probability: float) -> str:
        """Determine recommended action based on signal and probability"""
        if signal == SignalStrength.STRONG_BUY:
            if probability >= 70:
                return "Strong Buy - Enter Long Position"
            else:
                return "Buy - Consider Long Position with Reduced Size"
        elif signal == SignalStrength.BUY:
            if probability >= 60:
                return "Buy - Enter Small Long Position"
            else:
                return "Weak Buy - Wait for Confirmation"
        elif signal == SignalStrength.STRONG_SELL:
            if probability >= 70:
                return "Strong Sell - Enter Short Position"
            else:
                return "Sell - Consider Short Position with Reduced Size"
        elif signal == SignalStrength.SELL:
            if probability >= 60:
                return "Sell - Enter Small Short Position"
            else:
                return "Weak Sell - Wait for Confirmation"
        else:
            return "Neutral - No Clear Direction, Stay Out"
    
    def _assess_risk(self, confidence: float, probability: float) -> str:
        """Assess risk level of the signal"""
        combined_score = (confidence + probability/100) / 2
        
        if combined_score >= self.risk_thresholds['low']:
            return "Low Risk"
        elif combined_score >= self.risk_thresholds['medium']:
            return "Medium Risk"
        else:
            return "High Risk"
    
    def _prepare_contributing_signals(self, 
                                     results: List[Tuple[SignalConfiguration, IndicatorResult]]) -> Dict:
        """Prepare detailed information about contributing signals"""
        contributing = {}
        
        for config, result in results:
            contributing[result.indicator_name] = {
                'signal': result.signal.name,
                'signal_value': result.signal.value,
                'confidence': result.confidence,
                'weight': config.weight,
                'category': config.category.name,
                'value': result.value,
                'components': result.components,
                'metadata': result.metadata
            }
            
        return contributing
    
    def _create_neutral_signal(self, symbol: str) -> CombinedSignal:
        """Create a neutral signal when no indicators are available"""
        return CombinedSignal(
            timestamp=datetime.now(),
            symbol=symbol,
            signal=SignalStrength.NEUTRAL,
            confidence=0.5,
            probability=50.0,
            indicators_used=0,
            contributing_signals={},
            market_condition='unknown',
            recommended_action='No Signal - Insufficient Data',
            risk_level='High Risk'
        )
    
    def get_signal_statistics(self, df: pd.DataFrame, symbol: str, 
                             lookback_periods: int = 100) -> Dict:
        """Calculate historical statistics for signal accuracy"""
        if len(df) < lookback_periods + self.get_required_periods():
            return {}
            
        stats = {
            'total_signals': 0,
            'buy_signals': 0,
            'sell_signals': 0,
            'neutral_signals': 0,
            'avg_confidence': 0.0,
            'avg_probability': 0.0,
            'signal_changes': 0,
            'market_conditions': {}
        }
        
        # Track signals over lookback period
        signals = []
        for i in range(lookback_periods):
            end_idx = len(df) - i
            if end_idx < self.get_required_periods():
                break
                
            period_df = df.iloc[:end_idx]
            try:
                signal = self.analyze(period_df, symbol)
                signals.append(signal)
            except:
                continue
                
        if not signals:
            return stats
            
        # Calculate statistics
        stats['total_signals'] = len(signals)
        stats['buy_signals'] = sum(1 for s in signals 
                                  if s.signal in [SignalStrength.BUY, SignalStrength.STRONG_BUY])
        stats['sell_signals'] = sum(1 for s in signals 
                                   if s.signal in [SignalStrength.SELL, SignalStrength.STRONG_SELL])
        stats['neutral_signals'] = sum(1 for s in signals 
                                      if s.signal == SignalStrength.NEUTRAL)
        
        stats['avg_confidence'] = np.mean([s.confidence for s in signals])
        stats['avg_probability'] = np.mean([s.probability for s in signals])
        
        # Count signal changes
        for i in range(1, len(signals)):
            if signals[i].signal != signals[i-1].signal:
                stats['signal_changes'] += 1
                
        # Market condition distribution
        conditions = [s.market_condition for s in signals]
        for condition in set(conditions):
            stats['market_conditions'][condition] = conditions.count(condition) / len(conditions)
            
        return stats