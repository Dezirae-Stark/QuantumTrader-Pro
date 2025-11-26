"""
Base classes for modular indicator system
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from enum import Enum
import pandas as pd
import numpy as np


class SignalStrength(Enum):
    """Signal strength levels"""
    STRONG_BUY = 2
    BUY = 1
    NEUTRAL = 0
    SELL = -1
    STRONG_SELL = -2


@dataclass
class IndicatorResult:
    """Standard result format for all indicators"""
    timestamp: datetime
    symbol: str
    indicator_name: str
    signal: SignalStrength
    confidence: float  # 0.0 to 1.0
    value: float  # Primary indicator value
    components: Dict[str, float]  # Additional values (e.g., upper/lower bands)
    metadata: Dict[str, any]  # Extra information
    
    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'timestamp': self.timestamp.isoformat(),
            'symbol': self.symbol,
            'indicator_name': self.indicator_name,
            'signal': self.signal.name,
            'signal_value': self.signal.value,
            'confidence': self.confidence,
            'value': self.value,
            'components': self.components,
            'metadata': self.metadata
        }


class Indicator(ABC):
    """Base class for all technical indicators"""
    
    def __init__(self, name: str, enabled: bool = True):
        self.name = name
        self.enabled = enabled
        self.last_calculation = None
        self.cache = {}
        
    @abstractmethod
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        """
        Calculate indicator values and generate signal
        
        Args:
            df: DataFrame with OHLCV data
            symbol: Trading symbol
            
        Returns:
            IndicatorResult with signal and confidence
        """
        pass
    
    @abstractmethod
    def get_required_periods(self) -> int:
        """Return minimum number of periods needed for calculation"""
        pass
    
    def validate_data(self, df: pd.DataFrame) -> bool:
        """Validate that DataFrame has required columns and data"""
        required_columns = ['open', 'high', 'low', 'close', 'volume']
        
        # Check columns
        for col in required_columns:
            if col not in df.columns:
                return False
        
        # Check minimum periods
        if len(df) < self.get_required_periods():
            return False
        
        # Check for NaN values
        if df[required_columns].isna().any().any():
            return False
        
        return True
    
    def _determine_signal(self, current: float, previous: float, 
                         threshold: float = 0.0) -> SignalStrength:
        """Helper method to determine signal from values"""
        diff = current - previous
        diff_pct = diff / abs(previous) if previous != 0 else 0
        
        if diff_pct > threshold * 2:
            return SignalStrength.STRONG_BUY
        elif diff_pct > threshold:
            return SignalStrength.BUY
        elif diff_pct < -threshold * 2:
            return SignalStrength.STRONG_SELL
        elif diff_pct < -threshold:
            return SignalStrength.SELL
        else:
            return SignalStrength.NEUTRAL
    
    def _calculate_confidence(self, signal: SignalStrength, 
                            *factors: float) -> float:
        """Calculate confidence based on signal strength and other factors"""
        base_confidence = {
            SignalStrength.STRONG_BUY: 0.8,
            SignalStrength.BUY: 0.6,
            SignalStrength.NEUTRAL: 0.5,
            SignalStrength.SELL: 0.6,
            SignalStrength.STRONG_SELL: 0.8
        }
        
        confidence = base_confidence.get(signal, 0.5)
        
        # Adjust based on additional factors
        if factors:
            factor_avg = np.mean([f for f in factors if f is not None])
            confidence = confidence * 0.7 + factor_avg * 0.3
        
        return np.clip(confidence, 0.0, 1.0)


class CompositeIndicator(Indicator):
    """Base class for indicators that combine multiple sub-indicators"""
    
    def __init__(self, name: str, indicators: List[Indicator], enabled: bool = True):
        super().__init__(name, enabled)
        self.indicators = indicators
        
    def get_required_periods(self) -> int:
        """Return maximum required periods from all sub-indicators"""
        return max(ind.get_required_periods() for ind in self.indicators)
    
    def calculate_all(self, df: pd.DataFrame, symbol: str) -> List[IndicatorResult]:
        """Calculate all sub-indicators and return their results"""
        results = []
        for indicator in self.indicators:
            if indicator.enabled:
                result = indicator.calculate(df, symbol)
                if result:
                    results.append(result)
        return results