# Indicator modules for QuantumTrader Pro
from .base import Indicator, IndicatorResult, SignalStrength
from .chaos_indicators import (
    AlligatorIndicator,
    AwesomeOscillator,
    AcceleratorOscillator,
    FractalsIndicator,
    WilliamsMFI,
    ChaosSignalCombiner
)
from .elliott_wave import ElliottWaveDetector
from .signal_engine import SignalEngine, SignalWeight

__all__ = [
    'Indicator',
    'IndicatorResult', 
    'SignalStrength',
    'AlligatorIndicator',
    'AwesomeOscillator',
    'AcceleratorOscillator',
    'FractalsIndicator',
    'WilliamsMFI',
    'ChaosSignalCombiner',
    'ElliottWaveDetector',
    'SignalEngine',
    'SignalWeight'
]