"""
Elliott Wave Detection Engine
Identifies impulse and corrective wave patterns in price data
"""
import pandas as pd
import numpy as np
from datetime import datetime
from typing import List, Optional, Tuple, Dict
from dataclasses import dataclass
from enum import Enum
from .base import Indicator, IndicatorResult, SignalStrength


class WaveType(Enum):
    """Types of Elliott Waves"""
    IMPULSE_1 = "1"
    IMPULSE_2 = "2"
    IMPULSE_3 = "3"
    IMPULSE_4 = "4"
    IMPULSE_5 = "5"
    CORRECTIVE_A = "A"
    CORRECTIVE_B = "B"
    CORRECTIVE_C = "C"
    UNKNOWN = "?"


class TrendDirection(Enum):
    """Overall trend direction"""
    UP = 1
    DOWN = -1
    SIDEWAYS = 0


@dataclass
class WavePoint:
    """Represents a significant price point in wave structure"""
    index: int
    price: float
    time: pd.Timestamp
    is_high: bool  # True for high, False for low
    
    
@dataclass
class Wave:
    """Represents an Elliott Wave"""
    wave_type: WaveType
    start_point: WavePoint
    end_point: WavePoint
    confidence: float
    retracement: float  # Fibonacci retracement level
    extension: float    # Fibonacci extension level
    
    @property
    def length(self) -> float:
        """Wave length in price terms"""
        return abs(self.end_point.price - self.start_point.price)
    
    @property
    def duration(self) -> int:
        """Wave duration in bars"""
        return self.end_point.index - self.start_point.index
    
    @property
    def direction(self) -> TrendDirection:
        """Wave direction"""
        if self.end_point.price > self.start_point.price:
            return TrendDirection.UP
        elif self.end_point.price < self.start_point.price:
            return TrendDirection.DOWN
        return TrendDirection.SIDEWAYS


class ElliottWaveDetector(Indicator):
    """
    Elliott Wave pattern detection using swing highs/lows and Fibonacci ratios
    """
    
    def __init__(self, swing_period: int = 5, min_wave_size: float = 0.001,
                 enabled: bool = True):
        super().__init__("Elliott Wave", enabled)
        self.swing_period = swing_period
        self.min_wave_size = min_wave_size  # Minimum wave size as percentage
        
        # Fibonacci ratios for wave relationships
        self.fib_ratios = {
            'retracement': [0.236, 0.382, 0.5, 0.618, 0.786],
            'extension': [1.0, 1.272, 1.414, 1.618, 2.0, 2.618]
        }
        
        # Elliott Wave rules
        self.wave_rules = {
            'wave2_max_retrace': 0.99,  # Wave 2 cannot retrace more than 100% of wave 1
            'wave3_min_extend': 1.0,     # Wave 3 must be at least 100% of wave 1
            'wave4_max_overlap': 0.0,    # Wave 4 cannot overlap wave 1 (in trend)
            'wave5_typical_extend': 1.0  # Wave 5 typically equals wave 1
        }
        
    def get_required_periods(self) -> int:
        return max(50, self.swing_period * 10)
    
    def calculate(self, df: pd.DataFrame, symbol: str) -> IndicatorResult:
        if not self.validate_data(df):
            return None
            
        # Find swing points
        swing_highs, swing_lows = self._find_swing_points(df)
        all_swings = self._merge_swing_points(swing_highs, swing_lows)
        
        if len(all_swings) < 8:  # Need at least 8 swings for a complete wave
            return self._create_neutral_result(symbol, df)
            
        # Detect wave patterns
        impulse_waves = self._detect_impulse_waves(all_swings, df)
        corrective_waves = self._detect_corrective_waves(all_swings, df)
        
        # Get current wave position
        current_wave = self._identify_current_wave(impulse_waves, corrective_waves, df)
        
        # Generate trading signal
        signal, confidence = self._generate_signal(current_wave, impulse_waves, 
                                                  corrective_waves, df)
        
        # Prepare components and metadata
        components = self._prepare_components(current_wave, all_swings, df)
        metadata = self._prepare_metadata(impulse_waves, corrective_waves, current_wave)
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=df['close'].iloc[-1],
            components=components,
            metadata=metadata
        )
    
    def _find_swing_points(self, df: pd.DataFrame) -> Tuple[List[WavePoint], List[WavePoint]]:
        """Find swing highs and lows"""
        highs = []
        lows = []
        
        for i in range(self.swing_period, len(df) - self.swing_period):
            # Check for swing high
            if self._is_swing_high(df, i):
                highs.append(WavePoint(
                    index=i,
                    price=df['high'].iloc[i],
                    time=df.index[i],
                    is_high=True
                ))
                
            # Check for swing low
            if self._is_swing_low(df, i):
                lows.append(WavePoint(
                    index=i,
                    price=df['low'].iloc[i],
                    time=df.index[i],
                    is_high=False
                ))
                
        return highs, lows
    
    def _is_swing_high(self, df: pd.DataFrame, index: int) -> bool:
        """Check if index is a swing high"""
        high = df['high'].iloc[index]
        
        # Check bars before
        for i in range(index - self.swing_period, index):
            if df['high'].iloc[i] >= high:
                return False
                
        # Check bars after
        for i in range(index + 1, index + self.swing_period + 1):
            if i < len(df) and df['high'].iloc[i] > high:
                return False
                
        return True
    
    def _is_swing_low(self, df: pd.DataFrame, index: int) -> bool:
        """Check if index is a swing low"""
        low = df['low'].iloc[index]
        
        # Check bars before
        for i in range(index - self.swing_period, index):
            if df['low'].iloc[i] <= low:
                return False
                
        # Check bars after
        for i in range(index + 1, index + self.swing_period + 1):
            if i < len(df) and df['low'].iloc[i] < low:
                return False
                
        return True
    
    def _merge_swing_points(self, highs: List[WavePoint], 
                           lows: List[WavePoint]) -> List[WavePoint]:
        """Merge and sort swing points chronologically"""
        all_points = highs + lows
        all_points.sort(key=lambda p: p.index)
        
        # Filter out points that are too close
        filtered = []
        for point in all_points:
            if not filtered:
                filtered.append(point)
            else:
                last_point = filtered[-1]
                price_diff = abs(point.price - last_point.price) / last_point.price
                
                if price_diff >= self.min_wave_size:
                    # Ensure alternating highs and lows
                    if point.is_high != last_point.is_high:
                        filtered.append(point)
                    elif price_diff > self.min_wave_size * 2:
                        # Replace if significantly different
                        if (point.is_high and point.price > last_point.price) or \
                           (not point.is_high and point.price < last_point.price):
                            filtered[-1] = point
                            
        return filtered
    
    def _detect_impulse_waves(self, swings: List[WavePoint], 
                             df: pd.DataFrame) -> List[List[Wave]]:
        """Detect 5-wave impulse patterns"""
        impulse_patterns = []
        
        # Need at least 6 points for a 5-wave pattern (5 waves = 6 points)
        for i in range(len(swings) - 5):
            waves = self._try_impulse_pattern(swings[i:i+6], df)
            if waves:
                impulse_patterns.append(waves)
                
        return impulse_patterns
    
    def _try_impulse_pattern(self, points: List[WavePoint], 
                            df: pd.DataFrame) -> Optional[List[Wave]]:
        """Try to fit an impulse wave pattern to 6 points"""
        if len(points) != 6:
            return None
            
        # Determine overall trend
        if points[0].price < points[5].price:
            # Uptrend impulse
            return self._validate_uptrend_impulse(points)
        else:
            # Downtrend impulse  
            return self._validate_downtrend_impulse(points)
    
    def _validate_uptrend_impulse(self, points: List[WavePoint]) -> Optional[List[Wave]]:
        """Validate uptrend impulse pattern"""
        # Expected pattern: Low, High, Low, High, Low, High
        if not (not points[0].is_high and points[1].is_high and 
                not points[2].is_high and points[3].is_high and
                not points[4].is_high and points[5].is_high):
            return None
            
        waves = []
        
        # Wave 1: points[0] to points[1]
        wave1 = Wave(
            wave_type=WaveType.IMPULSE_1,
            start_point=points[0],
            end_point=points[1],
            confidence=1.0,
            retracement=0.0,
            extension=1.0
        )
        waves.append(wave1)
        
        # Wave 2: points[1] to points[2]
        wave2_retrace = (points[1].price - points[2].price) / wave1.length
        if wave2_retrace > self.wave_rules['wave2_max_retrace']:
            return None
            
        wave2 = Wave(
            wave_type=WaveType.IMPULSE_2,
            start_point=points[1],
            end_point=points[2],
            confidence=self._get_fib_confidence(wave2_retrace, 'retracement'),
            retracement=wave2_retrace,
            extension=0.0
        )
        waves.append(wave2)
        
        # Wave 3: points[2] to points[3]
        wave3_extend = (points[3].price - points[2].price) / wave1.length
        if wave3_extend < self.wave_rules['wave3_min_extend']:
            return None
            
        wave3 = Wave(
            wave_type=WaveType.IMPULSE_3,
            start_point=points[2],
            end_point=points[3],
            confidence=self._get_fib_confidence(wave3_extend, 'extension'),
            retracement=0.0,
            extension=wave3_extend
        )
        waves.append(wave3)
        
        # Wave 4: points[3] to points[4]
        # Check wave 4 doesn't overlap wave 1
        if points[4].price <= points[1].price:
            return None
            
        wave4_retrace = (points[3].price - points[4].price) / (points[3].price - points[2].price)
        wave4 = Wave(
            wave_type=WaveType.IMPULSE_4,
            start_point=points[3],
            end_point=points[4],
            confidence=self._get_fib_confidence(wave4_retrace, 'retracement'),
            retracement=wave4_retrace,
            extension=0.0
        )
        waves.append(wave4)
        
        # Wave 5: points[4] to points[5]
        wave5_extend = (points[5].price - points[4].price) / wave1.length
        wave5 = Wave(
            wave_type=WaveType.IMPULSE_5,
            start_point=points[4],
            end_point=points[5],
            confidence=self._get_fib_confidence(wave5_extend, 'extension'),
            retracement=0.0,
            extension=wave5_extend
        )
        waves.append(wave5)
        
        # Calculate overall pattern confidence
        total_confidence = sum(w.confidence for w in waves) / len(waves)
        
        # Apply confidence to all waves
        for wave in waves:
            wave.confidence *= total_confidence
            
        return waves if total_confidence > 0.5 else None
    
    def _validate_downtrend_impulse(self, points: List[WavePoint]) -> Optional[List[Wave]]:
        """Validate downtrend impulse pattern (inverse of uptrend)"""
        # Invert the logic for downtrend
        # Expected pattern: High, Low, High, Low, High, Low
        if not (points[0].is_high and not points[1].is_high and 
                points[2].is_high and not points[3].is_high and
                points[4].is_high and not points[5].is_high):
            return None
            
        # Similar validation but for downtrend
        waves = []
        
        # Wave 1: points[0] to points[1] (down)
        wave1 = Wave(
            wave_type=WaveType.IMPULSE_1,
            start_point=points[0],
            end_point=points[1],
            confidence=1.0,
            retracement=0.0,
            extension=1.0
        )
        waves.append(wave1)
        
        # Continue with similar logic for waves 2-5...
        # (Implementation similar to uptrend but inverted)
        
        return waves
    
    def _detect_corrective_waves(self, swings: List[WavePoint], 
                                df: pd.DataFrame) -> List[List[Wave]]:
        """Detect A-B-C corrective patterns"""
        corrective_patterns = []
        
        # Need at least 4 points for A-B-C pattern
        for i in range(len(swings) - 3):
            waves = self._try_corrective_pattern(swings[i:i+4], df)
            if waves:
                corrective_patterns.append(waves)
                
        return corrective_patterns
    
    def _try_corrective_pattern(self, points: List[WavePoint], 
                               df: pd.DataFrame) -> Optional[List[Wave]]:
        """Try to fit a corrective wave pattern to 4 points"""
        if len(points) != 4:
            return None
            
        waves = []
        
        # Wave A
        wave_a = Wave(
            wave_type=WaveType.CORRECTIVE_A,
            start_point=points[0],
            end_point=points[1],
            confidence=1.0,
            retracement=0.0,
            extension=1.0
        )
        waves.append(wave_a)
        
        # Wave B - typically retraces 50-78.6% of wave A
        wave_b_retrace = abs(points[2].price - points[1].price) / wave_a.length
        wave_b = Wave(
            wave_type=WaveType.CORRECTIVE_B,
            start_point=points[1],
            end_point=points[2],
            confidence=self._get_fib_confidence(wave_b_retrace, 'retracement'),
            retracement=wave_b_retrace,
            extension=0.0
        )
        waves.append(wave_b)
        
        # Wave C - typically 100-161.8% of wave A
        wave_c_extend = abs(points[3].price - points[2].price) / wave_a.length
        wave_c = Wave(
            wave_type=WaveType.CORRECTIVE_C,
            start_point=points[2],
            end_point=points[3],
            confidence=self._get_fib_confidence(wave_c_extend, 'extension'),
            retracement=0.0,
            extension=wave_c_extend
        )
        waves.append(wave_c)
        
        # Calculate pattern confidence
        total_confidence = sum(w.confidence for w in waves) / len(waves)
        
        for wave in waves:
            wave.confidence *= total_confidence
            
        return waves if total_confidence > 0.5 else None
    
    def _get_fib_confidence(self, ratio: float, ratio_type: str) -> float:
        """Get confidence based on how close ratio is to Fibonacci levels"""
        fib_levels = self.fib_ratios.get(ratio_type, [])
        
        if not fib_levels:
            return 0.5
            
        # Find closest Fibonacci level
        min_distance = float('inf')
        for level in fib_levels:
            distance = abs(ratio - level)
            if distance < min_distance:
                min_distance = distance
                
        # Convert distance to confidence (closer = higher confidence)
        # Within 5% of Fib level = high confidence
        if min_distance <= 0.05:
            return 1.0
        elif min_distance <= 0.10:
            return 0.8
        elif min_distance <= 0.15:
            return 0.6
        else:
            return 0.4
    
    def _identify_current_wave(self, impulse_patterns: List[List[Wave]], 
                              corrective_patterns: List[List[Wave]],
                              df: pd.DataFrame) -> Optional[Wave]:
        """Identify which wave we're currently in"""
        current_idx = len(df) - 1
        
        # Check impulse patterns
        for pattern in impulse_patterns:
            for wave in pattern:
                if wave.start_point.index <= current_idx <= wave.end_point.index:
                    return wave
                    
        # Check corrective patterns
        for pattern in corrective_patterns:
            for wave in pattern:
                if wave.start_point.index <= current_idx <= wave.end_point.index:
                    return wave
                    
        return None
    
    def _generate_signal(self, current_wave: Optional[Wave], 
                        impulse_patterns: List[List[Wave]],
                        corrective_patterns: List[List[Wave]], 
                        df: pd.DataFrame) -> Tuple[SignalStrength, float]:
        """Generate trading signal based on wave analysis"""
        if not current_wave:
            return SignalStrength.NEUTRAL, 0.5
            
        # Get latest pattern
        latest_pattern = None
        if impulse_patterns:
            latest_pattern = impulse_patterns[-1]
        elif corrective_patterns:
            latest_pattern = corrective_patterns[-1]
            
        if not latest_pattern:
            return SignalStrength.NEUTRAL, 0.5
            
        # Determine signal based on wave type and position
        if current_wave.wave_type == WaveType.IMPULSE_2:
            # End of wave 2 = start of wave 3 (strongest move)
            if self._near_wave_end(current_wave, df):
                direction = latest_pattern[0].direction
                if direction == TrendDirection.UP:
                    return SignalStrength.STRONG_BUY, current_wave.confidence
                else:
                    return SignalStrength.STRONG_SELL, current_wave.confidence
                    
        elif current_wave.wave_type == WaveType.IMPULSE_4:
            # End of wave 4 = start of wave 5
            if self._near_wave_end(current_wave, df):
                direction = latest_pattern[0].direction
                if direction == TrendDirection.UP:
                    return SignalStrength.BUY, current_wave.confidence * 0.8
                else:
                    return SignalStrength.SELL, current_wave.confidence * 0.8
                    
        elif current_wave.wave_type == WaveType.IMPULSE_5:
            # End of wave 5 = potential reversal
            if self._near_wave_end(current_wave, df):
                direction = latest_pattern[0].direction
                if direction == TrendDirection.UP:
                    return SignalStrength.SELL, current_wave.confidence * 0.7
                else:
                    return SignalStrength.BUY, current_wave.confidence * 0.7
                    
        elif current_wave.wave_type == WaveType.CORRECTIVE_C:
            # End of correction = resume trend
            if self._near_wave_end(current_wave, df):
                # Determine original trend from impulse
                for pattern in impulse_patterns:
                    if pattern[-1].end_point.index < current_wave.start_point.index:
                        direction = pattern[0].direction
                        if direction == TrendDirection.UP:
                            return SignalStrength.BUY, current_wave.confidence
                        else:
                            return SignalStrength.SELL, current_wave.confidence
                            
        return SignalStrength.NEUTRAL, 0.5
    
    def _near_wave_end(self, wave: Wave, df: pd.DataFrame) -> bool:
        """Check if we're near the end of a wave"""
        current_idx = len(df) - 1
        wave_progress = (current_idx - wave.start_point.index) / wave.duration
        
        # Consider near end if > 80% through wave
        return wave_progress > 0.8
    
    def _prepare_components(self, current_wave: Optional[Wave], 
                           swings: List[WavePoint],
                           df: pd.DataFrame) -> dict:
        """Prepare components for result"""
        components = {
            'current_price': df['close'].iloc[-1],
            'swing_count': len(swings)
        }
        
        if current_wave:
            components.update({
                'wave_type': current_wave.wave_type.value,
                'wave_start': current_wave.start_point.price,
                'wave_end': current_wave.end_point.price,
                'wave_progress': self._calculate_wave_progress(current_wave, df)
            })
            
        if swings:
            components['last_swing_high'] = max(s.price for s in swings if s.is_high)
            components['last_swing_low'] = min(s.price for s in swings if not s.is_high)
            
        return components
    
    def _prepare_metadata(self, impulse_patterns: List[List[Wave]], 
                         corrective_patterns: List[List[Wave]],
                         current_wave: Optional[Wave]) -> dict:
        """Prepare metadata for result"""
        metadata = {
            'impulse_pattern_count': len(impulse_patterns),
            'corrective_pattern_count': len(corrective_patterns),
            'current_wave': current_wave.wave_type.value if current_wave else None
        }
        
        if impulse_patterns:
            latest_impulse = impulse_patterns[-1]
            metadata['latest_impulse'] = {
                'direction': latest_impulse[0].direction.name,
                'confidence': sum(w.confidence for w in latest_impulse) / len(latest_impulse),
                'wave_labels': [w.wave_type.value for w in latest_impulse]
            }
            
        if corrective_patterns:
            latest_corrective = corrective_patterns[-1]
            metadata['latest_corrective'] = {
                'confidence': sum(w.confidence for w in latest_corrective) / len(latest_corrective),
                'wave_labels': [w.wave_type.value for w in latest_corrective]
            }
            
        return metadata
    
    def _calculate_wave_progress(self, wave: Wave, df: pd.DataFrame) -> float:
        """Calculate how far through the current wave we are"""
        current_idx = len(df) - 1
        return (current_idx - wave.start_point.index) / wave.duration
    
    def _create_neutral_result(self, symbol: str, df: pd.DataFrame) -> IndicatorResult:
        """Create neutral result when no waves detected"""
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=SignalStrength.NEUTRAL,
            confidence=0.5,
            value=df['close'].iloc[-1],
            components={
                'current_price': df['close'].iloc[-1],
                'swing_count': 0
            },
            metadata={
                'message': 'Insufficient swing points for wave analysis'
            }
        )