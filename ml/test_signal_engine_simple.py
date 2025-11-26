#!/usr/bin/env python3
"""
Simple test to verify signal engine structure (without running)
"""
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_imports():
    """Test that our modules can be imported"""
    print("Testing module imports...")
    
    try:
        from indicators.base import Indicator, IndicatorResult, SignalStrength
        print("✓ Base indicators imported")
    except ImportError as e:
        print(f"✗ Failed to import base: {e}")
        
    try:
        from indicators.chaos_indicators import (
            AlligatorIndicator,
            AwesomeOscillator,
            AcceleratorOscillator,
            FractalsIndicator,
            WilliamsMFI
        )
        print("✓ Chaos indicators imported")
    except ImportError as e:
        print(f"✗ Failed to import chaos indicators: {e}")
        
    try:
        from indicators.elliott_wave import ElliottWaveDetector
        print("✓ Elliott Wave detector imported")
    except ImportError as e:
        print(f"✗ Failed to import Elliott Wave: {e}")
        
    try:
        from indicators.signal_engine import SignalEngine, SignalWeight
        print("✓ Signal engine imported")
    except ImportError as e:
        print(f"✗ Failed to import signal engine: {e}")

def test_structure():
    """Test basic structure of the signal engine"""
    print("\nTesting signal engine structure...")
    
    try:
        from indicators.signal_engine import SignalEngine
        
        # Create engine
        engine = SignalEngine()
        print("✓ Signal engine created")
        
        # Check configurations
        print(f"✓ Found {len(engine.configurations)} indicators configured")
        
        # List indicators
        print("\nConfigured indicators:")
        for config in engine.configurations:
            print(f"  - {config.indicator.name}: weight={config.weight}, category={config.category.name}")
            
        # Test methods exist
        methods = ['analyze', 'add_indicator', 'remove_indicator', 
                  'toggle_indicator', 'get_required_periods']
        for method in methods:
            if hasattr(engine, method):
                print(f"✓ Method '{method}' exists")
            else:
                print(f"✗ Method '{method}' missing")
                
    except Exception as e:
        print(f"✗ Error testing structure: {e}")

def main():
    """Main test function"""
    print("=== Signal Engine Structure Test ===\n")
    
    test_imports()
    test_structure()
    
    print("\n✓ Structure test completed!")
    print("\nNote: Full functional testing requires installing ML dependencies:")
    print("  cd ml && pip install -r requirements.txt")

if __name__ == "__main__":
    main()