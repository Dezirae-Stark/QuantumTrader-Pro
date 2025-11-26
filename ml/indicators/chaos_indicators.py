"""
Bill Williams Chaos Theory Indicators
Based on Trading Chaos and New Trading Dimensions books
"""
import pandas as pd
import numpy as np
from datetime import datetime
from typing import Optional, List, Tuple
from .base import Indicator, IndicatorResult, SignalStrength, CompositeIndicator


class AlligatorIndicator(Indicator):
    """
    Bill Williams Alligator Indicator
    Three smoothed moving averages:
    - Jaw (Blue): 13-period SMMA, shifted 8 bars
    - Teeth (Red): 8-period SMMA, shifted 5 bars  
    - Lips (Green): 5-period SMMA, shifted 3 bars
    """
    
    def __init__(self, jaw_period: int = 13, teeth_period: int = 8, 
                 lips_period: int = 5, enabled: bool = True):
        super().__init__("Alligator", enabled)
        self.jaw_period = jaw_period
        self.jaw_shift = 8
        self.teeth_period = teeth_period
        self.teeth_shift = 5
        self.lips_period = lips_period
        self.lips_shift = 3
        
    def get_required_periods(self) -> int:
        return self.jaw_period + self.jaw_shift + 10
    
    def _smma(self, data: pd.Series, period: int) -> pd.Series:
        """Smoothed Moving Average (SMMA)"""
        smma = pd.Series(index=data.index, dtype=float)
        smma.iloc[period-1] = data.iloc[:period].mean()
        
        for i in range(period, len(data)):
            smma.iloc[i] = (smma.iloc[i-1] * (period - 1) + data.iloc[i]) / period
            
        return smma
    
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Calculate median price (HL/2)
        median_price = (df['high'] + df['low']) / 2
        
        # Calculate SMAs
        jaw = self._smma(median_price, self.jaw_period).shift(self.jaw_shift)
        teeth = self._smma(median_price, self.teeth_period).shift(self.teeth_shift)
        lips = self._smma(median_price, self.lips_period).shift(self.lips_shift)
        
        # Get current values
        current_idx = -1
        current_price = df['close'].iloc[current_idx]
        jaw_val = jaw.iloc[current_idx]
        teeth_val = teeth.iloc[current_idx]
        lips_val = lips.iloc[current_idx]
        
        # Determine trend and signal
        signal = self._analyze_alligator(current_price, jaw_val, teeth_val, lips_val)
        
        # Calculate distances
        jaw_dist = abs(current_price - jaw_val) / current_price if jaw_val else 0
        teeth_dist = abs(current_price - teeth_val) / current_price if teeth_val else 0
        lips_dist = abs(current_price - lips_val) / current_price if lips_val else 0
        
        # Confidence based on line separation and price position
        separation = self._calculate_separation(jaw_val, teeth_val, lips_val)
        confidence = self._calculate_confidence(signal, separation, 
                                              min(jaw_dist, teeth_dist, lips_dist))
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=lips_val,  # Use lips as primary value
            components={
                'jaw': jaw_val,
                'teeth': teeth_val,
                'lips': lips_val,
                'price': current_price,
                'separation': separation
            },
            metadata={
                'is_sleeping': bool(separation < 0.001),  # Alligator sleeping
                'trend_strength': float(separation * 100)
            }
        )
    
    def _analyze_alligator(self, price: float, jaw: float, teeth: float, 
                          lips: float) -> SignalStrength:
        """Analyze Alligator lines for trading signal"""
        if not all([jaw, teeth, lips]):
            return SignalStrength.NEUTRAL
            
        # Bullish alignment: lips > teeth > jaw
        if lips > teeth > jaw:
            if price > lips:
                return SignalStrength.STRONG_BUY
            elif price > teeth:
                return SignalStrength.BUY
                
        # Bearish alignment: lips < teeth < jaw
        elif lips < teeth < jaw:
            if price < lips:
                return SignalStrength.STRONG_SELL
            elif price < teeth:
                return SignalStrength.SELL
                
        return SignalStrength.NEUTRAL
    
    def _calculate_separation(self, jaw: float, teeth: float, lips: float) -> float:
        """Calculate normalized separation between lines"""
        if not all([jaw, teeth, lips]):
            return 0.0
            
        max_val = max(jaw, teeth, lips)
        min_val = min(jaw, teeth, lips)
        
        return (max_val - min_val) / max_val if max_val > 0 else 0.0


class AwesomeOscillator(Indicator):
    """
    Bill Williams Awesome Oscillator (AO)
    Measures market momentum: SMA5(median) - SMA34(median)
    """
    
    def __init__(self, fast_period: int = 5, slow_period: int = 34, 
                 enabled: bool = True):
        super().__init__("Awesome Oscillator", enabled)
        self.fast_period = fast_period
        self.slow_period = slow_period
        
    def get_required_periods(self) -> int:
        return self.slow_period + 5
    
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Calculate median price
        median_price = (df['high'] + df['low']) / 2
        
        # Calculate AO
        fast_sma = median_price.rolling(window=self.fast_period).mean()
        slow_sma = median_price.rolling(window=self.slow_period).mean()
        ao = fast_sma - slow_sma
        
        # Get recent values for signal detection
        ao_current = ao.iloc[-1]
        ao_prev = ao.iloc[-2]
        ao_prev2 = ao.iloc[-3]
        
        # Detect patterns
        signal = self._detect_ao_patterns(ao_current, ao_prev, ao_prev2, 
                                         ao.iloc[-10:])
        
        # Calculate momentum change
        momentum_change = ao_current - ao_prev
        momentum_strength = abs(ao_current) / df['close'].iloc[-1]
        
        confidence = self._calculate_confidence(signal, momentum_strength)
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=ao_current,
            components={
                'previous': ao_prev,
                'momentum_change': momentum_change,
                'zero_line': 0
            },
            metadata={
                'color': 'green' if ao_current > ao_prev else 'red',
                'twin_peaks_buy': self._check_twin_peaks_buy(ao.iloc[-20:]),
                'twin_peaks_sell': self._check_twin_peaks_sell(ao.iloc[-20:])
            }
        )
    
    def _detect_ao_patterns(self, current: float, prev: float, prev2: float,
                           recent_ao: pd.Series) -> SignalStrength:
        """Detect AO trading patterns"""
        
        # Zero line cross
        if prev < 0 < current:
            return SignalStrength.BUY
        elif prev > 0 > current:
            return SignalStrength.SELL
            
        # Saucer patterns
        saucer_buy = self._check_saucer_buy(current, prev, prev2)
        if saucer_buy:
            return SignalStrength.STRONG_BUY
            
        saucer_sell = self._check_saucer_sell(current, prev, prev2)
        if saucer_sell:
            return SignalStrength.STRONG_SELL
            
        # Twin peaks
        if self._check_twin_peaks_buy(recent_ao):
            return SignalStrength.BUY
        elif self._check_twin_peaks_sell(recent_ao):
            return SignalStrength.SELL
            
        return SignalStrength.NEUTRAL
    
    def _check_saucer_buy(self, current: float, prev: float, prev2: float) -> bool:
        """Check for bullish saucer pattern"""
        # Three consecutive bars: red, red (lower), green (higher)
        return (prev2 > prev and  # First red bar
                prev < 0 and      # Second red bar (lower)
                current > prev and # Green bar (higher)
                current < 0)      # Still below zero
    
    def _check_saucer_sell(self, current: float, prev: float, prev2: float) -> bool:
        """Check for bearish saucer pattern"""
        # Three consecutive bars: green, green (higher), red (lower)
        return (prev2 < prev and  # First green bar
                prev > 0 and      # Second green bar (higher)
                current < prev and # Red bar (lower)
                current > 0)      # Still above zero
    
    def _check_twin_peaks_buy(self, ao_series: pd.Series) -> bool:
        """Check for bullish twin peaks pattern"""
        if len(ao_series) < 10:
            return False
            
        # Find peaks below zero
        peaks = []
        for i in range(1, len(ao_series) - 1):
            if (ao_series.iloc[i] < 0 and 
                ao_series.iloc[i] < ao_series.iloc[i-1] and 
                ao_series.iloc[i] < ao_series.iloc[i+1]):
                peaks.append((i, ao_series.iloc[i]))
                
        # Check if we have two peaks with second higher than first
        if len(peaks) >= 2:
            if peaks[-1][1] > peaks[-2][1]:  # Second peak higher
                return True
                
        return False
    
    def _check_twin_peaks_sell(self, ao_series: pd.Series) -> bool:
        """Check for bearish twin peaks pattern"""
        if len(ao_series) < 10:
            return False
            
        # Find peaks above zero
        peaks = []
        for i in range(1, len(ao_series) - 1):
            if (ao_series.iloc[i] > 0 and 
                ao_series.iloc[i] > ao_series.iloc[i-1] and 
                ao_series.iloc[i] > ao_series.iloc[i+1]):
                peaks.append((i, ao_series.iloc[i]))
                
        # Check if we have two peaks with second lower than first
        if len(peaks) >= 2:
            if peaks[-1][1] < peaks[-2][1]:  # Second peak lower
                return True
                
        return False


class AcceleratorOscillator(Indicator):
    """
    Bill Williams Accelerator/Decelerator Oscillator (AC)
    Measures acceleration of the Awesome Oscillator
    AC = AO - SMA5(AO)
    """
    
    def __init__(self, ao_fast: int = 5, ao_slow: int = 34, 
                 ac_period: int = 5, enabled: bool = True):
        super().__init__("Accelerator Oscillator", enabled)
        self.ao_fast = ao_fast
        self.ao_slow = ao_slow
        self.ac_period = ac_period
        
    def get_required_periods(self) -> int:
        return self.ao_slow + self.ac_period + 5
    
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Calculate AO first
        median_price = (df['high'] + df['low']) / 2
        fast_sma = median_price.rolling(window=self.ao_fast).mean()
        slow_sma = median_price.rolling(window=self.ao_slow).mean()
        ao = fast_sma - slow_sma
        
        # Calculate AC
        ao_sma = ao.rolling(window=self.ac_period).mean()
        ac = ao - ao_sma
        
        # Get recent values
        ac_current = ac.iloc[-1]
        ac_prev = ac.iloc[-2]
        ac_prev2 = ac.iloc[-3]
        
        # Determine signal
        signal = self._analyze_ac_signal(ac_current, ac_prev, ac_prev2)
        
        # Calculate acceleration strength
        acceleration = ac_current - ac_prev
        accel_strength = abs(ac_current) / df['close'].iloc[-1]
        
        confidence = self._calculate_confidence(signal, accel_strength)
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=ac_current,
            components={
                'previous': ac_prev,
                'acceleration': acceleration,
                'ao_value': ao.iloc[-1]
            },
            metadata={
                'color': 'green' if ac_current > ac_prev else 'red',
                'consecutive_bars': self._count_consecutive_bars(ac.iloc[-5:])
            }
        )
    
    def _analyze_ac_signal(self, current: float, prev: float, prev2: float) -> SignalStrength:
        """Analyze AC for trading signals"""
        
        # Count consecutive bars of same color
        if current > prev and prev > prev2:
            # Two consecutive green bars
            if current > 0:
                return SignalStrength.STRONG_BUY
            else:
                return SignalStrength.BUY
                
        elif current < prev and prev < prev2:
            # Two consecutive red bars
            if current < 0:
                return SignalStrength.STRONG_SELL
            else:
                return SignalStrength.SELL
                
        # Zero line cross
        if prev < 0 < current:
            return SignalStrength.BUY
        elif prev > 0 > current:
            return SignalStrength.SELL
            
        return SignalStrength.NEUTRAL
    
    def _count_consecutive_bars(self, ac_series: pd.Series) -> dict:
        """Count consecutive green/red bars"""
        if len(ac_series) < 2:
            return {'green': 0, 'red': 0}
            
        green = 0
        red = 0
        
        for i in range(1, len(ac_series)):
            if ac_series.iloc[i] > ac_series.iloc[i-1]:
                green += 1
                red = 0
            else:
                red += 1
                green = 0
                
        return {'green': green, 'red': red}


class FractalsIndicator(Indicator):
    """
    Bill Williams Fractals
    Identifies market turning points
    """
    
    def __init__(self, period: int = 5, enabled: bool = True):
        super().__init__("Fractals", enabled)
        self.period = period  # Must be odd number
        if period % 2 == 0:
            self.period = period + 1
            
    def get_required_periods(self) -> int:
        return self.period * 2
    
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Find fractals
        up_fractals = self._find_up_fractals(df)
        down_fractals = self._find_down_fractals(df)
        
        # Get most recent fractals
        recent_up = self._get_recent_fractal(up_fractals)
        recent_down = self._get_recent_fractal(down_fractals)
        
        # Current price
        current_price = df['close'].iloc[-1]
        
        # Generate signal based on fractal breakouts
        signal = self._analyze_fractal_breakout(current_price, recent_up, recent_down)
        
        # Calculate distances to fractals
        up_dist = abs(current_price - recent_up) / current_price if recent_up else 1.0
        down_dist = abs(current_price - recent_down) / current_price if recent_down else 1.0
        
        confidence = self._calculate_confidence(signal, min(up_dist, down_dist))
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=current_price,
            components={
                'up_fractal': recent_up,
                'down_fractal': recent_down,
                'up_distance': up_dist,
                'down_distance': down_dist
            },
            metadata={
                'total_up_fractals': len(up_fractals),
                'total_down_fractals': len(down_fractals),
                'fractal_period': self.period
            }
        )
    
    def _find_up_fractals(self, df: pd.DataFrame) -> List[Tuple[int, float]]:
        """Find bullish fractals (highs)"""
        fractals = []
        half = self.period // 2
        
        for i in range(half, len(df) - half):
            high = df['high'].iloc[i]
            is_fractal = True
            
            # Check if middle bar is highest
            for j in range(i - half, i + half + 1):
                if j != i and df['high'].iloc[j] >= high:
                    is_fractal = False
                    break
                    
            if is_fractal:
                fractals.append((i, high))
                
        return fractals
    
    def _find_down_fractals(self, df: pd.DataFrame) -> List[Tuple[int, float]]:
        """Find bearish fractals (lows)"""
        fractals = []
        half = self.period // 2
        
        for i in range(half, len(df) - half):
            low = df['low'].iloc[i]
            is_fractal = True
            
            # Check if middle bar is lowest
            for j in range(i - half, i + half + 1):
                if j != i and df['low'].iloc[j] <= low:
                    is_fractal = False
                    break
                    
            if is_fractal:
                fractals.append((i, low))
                
        return fractals
    
    def _get_recent_fractal(self, fractals: List[Tuple[int, float]]) -> Optional[float]:
        """Get most recent fractal value"""
        if not fractals:
            return None
        return fractals[-1][1]
    
    def _analyze_fractal_breakout(self, price: float, up_fractal: Optional[float],
                                  down_fractal: Optional[float]) -> SignalStrength:
        """Analyze price relative to fractals"""
        if up_fractal and price > up_fractal:
            return SignalStrength.STRONG_BUY
        elif down_fractal and price < down_fractal:
            return SignalStrength.STRONG_SELL
        elif up_fractal and down_fractal:
            # Price between fractals
            range_size = up_fractal - down_fractal
            position = (price - down_fractal) / range_size
            
            if position > 0.7:
                return SignalStrength.BUY
            elif position < 0.3:
                return SignalStrength.SELL
                
        return SignalStrength.NEUTRAL


class WilliamsMFI(Indicator):
    """
    Bill Williams Market Facilitation Index (MFI)
    Measures efficiency of price movement
    MFI = (High - Low) / Volume
    """
    
    def __init__(self, enabled: bool = True):
        super().__init__("Williams MFI", enabled)
        
    def get_required_periods(self) -> int:
        return 10
    
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Calculate MFI
        mfi = (df['high'] - df['low']) / (df['volume'] + 1)  # +1 to avoid division by zero
        
        # Get recent values
        current_mfi = mfi.iloc[-1]
        prev_mfi = mfi.iloc[-2]
        
        current_volume = df['volume'].iloc[-1]
        prev_volume = df['volume'].iloc[-2]
        
        # Determine market state (4 possible states)
        market_state = self._determine_market_state(
            current_mfi > prev_mfi,
            current_volume > prev_volume
        )
        
        # Generate signal based on market state
        signal = self._analyze_market_state(market_state, df)
        
        # Calculate efficiency
        avg_mfi = mfi.iloc[-20:].mean()
        efficiency = current_mfi / avg_mfi if avg_mfi > 0 else 1.0
        
        confidence = self._calculate_confidence(signal, efficiency)
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=current_mfi,
            components={
                'previous_mfi': prev_mfi,
                'volume': current_volume,
                'prev_volume': prev_volume,
                'avg_mfi': avg_mfi
            },
            metadata={
                'market_state': market_state,
                'efficiency': efficiency,
                'mfi_change': (current_mfi - prev_mfi) / prev_mfi if prev_mfi > 0 else 0,
                'volume_change': (current_volume - prev_volume) / prev_volume if prev_volume > 0 else 0
            }
        )
    
    def _determine_market_state(self, mfi_up: bool, volume_up: bool) -> str:
        """Determine one of four market states"""
        if mfi_up and volume_up:
            return "Green"  # Real move (trend continuation)
        elif mfi_up and not volume_up:
            return "Fade"   # Fading move (possible end of trend)
        elif not mfi_up and not volume_up:
            return "Fake"   # Fake move (no participation)
        else:  # not mfi_up and volume_up
            return "Squat"  # Market squat (preparing for move)
    
    def _analyze_market_state(self, state: str, df: pd.DataFrame) -> SignalStrength:
        """Generate signal based on market state and price action"""
        close_current = df['close'].iloc[-1]
        close_prev = df['close'].iloc[-2]
        price_up = close_current > close_prev
        
        if state == "Green":
            # Real move - follow the trend
            return SignalStrength.STRONG_BUY if price_up else SignalStrength.STRONG_SELL
        elif state == "Fade":
            # Fading move - prepare for reversal
            return SignalStrength.SELL if price_up else SignalStrength.BUY
        elif state == "Squat":
            # Preparing for move - wait for breakout
            return SignalStrength.BUY if price_up else SignalStrength.SELL
        else:  # Fake
            # No real participation
            return SignalStrength.NEUTRAL


class ChaosSignalCombiner(CompositeIndicator):
    """
    Combines all Bill Williams Chaos indicators into a unified signal
    """
    
    def __init__(self, enabled: bool = True):
        indicators = [
            AlligatorIndicator(),
            AwesomeOscillator(),
            AcceleratorOscillator(),
            FractalsIndicator(),
            WilliamsMFI()
        ]
        super().__init__("Chaos Signal Combiner", indicators, enabled)
        
        # Weights for each indicator
        self.weights = {
            "Alligator": 0.25,
            "Awesome Oscillator": 0.20,
            "Accelerator Oscillator": 0.20,
            "Fractals": 0.20,
            "Williams MFI": 0.15
        }
        
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Calculate all indicators
        results = self.calculate_all(df, symbol)
        
        if not results:
            return None
            
        # Combine signals
        weighted_signal = 0.0
        weighted_confidence = 0.0
        total_weight = 0.0
        
        components = {}
        metadata = {'individual_signals': {}}
        
        for result in results:
            weight = self.weights.get(result.indicator_name, 0.1)
            weighted_signal += result.signal.value * weight * result.confidence
            weighted_confidence += result.confidence * weight
            total_weight += weight
            
            # Store individual results
            components[result.indicator_name] = result.value
            metadata['individual_signals'][result.indicator_name] = {
                'signal': result.signal.name,
                'confidence': result.confidence
            }
        
        # Normalize
        if total_weight > 0:
            final_signal_value = weighted_signal / total_weight
            final_confidence = weighted_confidence / total_weight
        else:
            final_signal_value = 0
            final_confidence = 0.5
        
        # Convert to signal strength
        if final_signal_value >= 1.5:
            signal = SignalStrength.STRONG_BUY
        elif final_signal_value >= 0.5:
            signal = SignalStrength.BUY
        elif final_signal_value <= -1.5:
            signal = SignalStrength.STRONG_SELL
        elif final_signal_value <= -0.5:
            signal = SignalStrength.SELL
        else:
            signal = SignalStrength.NEUTRAL
            
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=final_confidence,
            value=final_signal_value,
            components=components,
            metadata=metadata
        )