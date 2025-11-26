#!/usr/bin/env python3
"""
Test script for the advanced signal engine and indicators
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
from technical_predictor import TechnicalPredictor

def generate_test_data(symbol='EURUSD', periods=200):
    """Generate realistic test market data"""
    # Base price
    base_price = 1.0800 if symbol == 'EURUSD' else 1.0000
    
    # Generate time series
    dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
    
    # Generate realistic price movements
    np.random.seed(42)
    returns = np.random.normal(0.0001, 0.002, periods)
    
    # Add trend component
    trend = np.sin(np.linspace(0, 4*np.pi, periods)) * 0.01
    
    # Generate prices
    prices = [base_price]
    for i in range(1, periods):
        change = returns[i] + trend[i] * 0.1
        new_price = prices[-1] * (1 + change)
        prices.append(new_price)
    
    # Create OHLCV data
    df = pd.DataFrame({
        'timestamp': dates,
        'open': prices,
        'high': [p * (1 + abs(np.random.normal(0, 0.001))) for p in prices],
        'low': [p * (1 - abs(np.random.normal(0, 0.001))) for p in prices],
        'close': [p * (1 + np.random.normal(0, 0.0005)) for p in prices],
        'volume': np.random.randint(1000, 10000, periods)
    })
    
    df.set_index('timestamp', inplace=True)
    return df

def test_individual_indicators(predictor, df, symbol):
    """Test each indicator individually"""
    print("\n=== Testing Individual Indicators ===")
    
    # Get list of indicators
    indicators = [config.indicator for config in predictor.signal_engine.configurations]
    
    for indicator in indicators:
        try:
            result = indicator.calculate(df, symbol)
            if result:
                print(f"\n{indicator.name}:")
                print(f"  Signal: {result.signal.name}")
                print(f"  Confidence: {result.confidence:.2%}")
                print(f"  Value: {result.value:.5f}")
                if result.components:
                    print(f"  Components: {list(result.components.keys())}")
                if result.metadata:
                    print(f"  Metadata: {json.dumps(result.metadata, indent=4)}")
        except Exception as e:
            print(f"\nError testing {indicator.name}: {e}")

def test_signal_engine(predictor, df, symbol):
    """Test the complete signal engine"""
    print("\n\n=== Testing Complete Signal Engine ===")
    
    try:
        # Get comprehensive analysis
        analysis = predictor.get_advanced_signals(df, symbol)
        
        if analysis['status'] == 'success':
            signal = analysis['current_signal']
            print(f"\nCurrent Signal Analysis:")
            print(f"  Signal: {signal['signal']} (value: {signal['signal_value']})")
            print(f"  Confidence: {signal['confidence']:.2%}")
            print(f"  Probability: {signal['probability']:.1f}%")
            print(f"  Market Condition: {signal['market_condition']}")
            print(f"  Recommended Action: {signal['recommended_action']}")
            print(f"  Risk Level: {signal['risk_level']}")
            print(f"  Indicators Used: {signal['indicators_used']}")
            
            # Show contributing indicators
            print("\nContributing Indicators:")
            for name, data in analysis['contributing_indicators'].items():
                print(f"  {name}:")
                print(f"    Signal: {data['signal']} ({data['signal_value']})")
                print(f"    Confidence: {data['confidence']:.2%}")
                print(f"    Weight: {data['weight']}")
                print(f"    Category: {data['category']}")
            
            # Show statistics
            if analysis.get('statistics'):
                stats = analysis['statistics']
                print("\nHistorical Statistics:")
                print(f"  Total Signals: {stats.get('total_signals', 0)}")
                print(f"  Buy Signals: {stats.get('buy_signals', 0)}")
                print(f"  Sell Signals: {stats.get('sell_signals', 0)}")
                print(f"  Average Confidence: {stats.get('avg_confidence', 0):.2%}")
                print(f"  Average Probability: {stats.get('avg_probability', 0):.1f}%")
                
                if stats.get('market_conditions'):
                    print(f"  Market Condition Distribution:")
                    for condition, pct in stats['market_conditions'].items():
                        print(f"    {condition}: {pct:.1%}")
        else:
            print(f"\nSignal analysis failed: {analysis}")
            
    except Exception as e:
        print(f"\nError in signal engine test: {e}")

def test_predictions(predictor, df, symbol):
    """Test prediction integration with signal engine"""
    print("\n\n=== Testing Predictions with Signal Engine ===")
    
    try:
        predictions = predictor.predict_next_candles(df, n_candles=5)
        
        for pred in predictions:
            print(f"\nCandle {pred['candle']}:")
            print(f"  Price: {pred['predicted_price']:.5f}")
            print(f"  Direction: {pred['direction']}")
            print(f"  Confidence: {pred['confidence']:.2%}")
            print(f"  Range: [{pred['lower_bound']:.5f}, {pred['upper_bound']:.5f}]")
            
            if pred.get('signal_engine'):
                se = pred['signal_engine']
                print(f"  Signal Engine:")
                print(f"    Signal: {se['signal']}")
                print(f"    Probability: {se['probability']:.1f}%")
                print(f"    Market: {se['market_condition']}")
                print(f"    Risk: {se['risk_level']}")
                
    except Exception as e:
        print(f"\nError in prediction test: {e}")

def test_indicator_toggling(predictor, df, symbol):
    """Test enabling/disabling indicators"""
    print("\n\n=== Testing Indicator Toggle ===")
    
    # Disable some indicators
    predictor.toggle_indicator("Elliott Wave", False)
    predictor.toggle_indicator("Williams MFI", False)
    
    print("\nAfter disabling Elliott Wave and Williams MFI:")
    analysis = predictor.get_advanced_signals(df, symbol)
    
    if analysis['status'] == 'success':
        print(f"  Indicators Used: {analysis['current_signal']['indicators_used']}")
        print(f"  Active Indicators: {list(analysis['contributing_indicators'].keys())}")
    
    # Re-enable
    predictor.toggle_indicator("Elliott Wave", True)
    predictor.toggle_indicator("Williams MFI", True)
    print("\n✓ Indicators re-enabled")

def main():
    """Main test function"""
    print("=== Advanced Signal Engine Test Suite ===")
    
    # Create predictor
    predictor = TechnicalPredictor()
    
    # Generate test data
    symbol = 'EURUSD'
    df = generate_test_data(symbol, periods=200)
    print(f"\nGenerated {len(df)} periods of test data for {symbol}")
    print(f"Price range: {df['close'].min():.5f} - {df['close'].max():.5f}")
    
    # Run tests
    test_individual_indicators(predictor, df, symbol)
    test_signal_engine(predictor, df, symbol)
    test_predictions(predictor, df, symbol)
    test_indicator_toggling(predictor, df, symbol)
    
    print("\n\n=== All Tests Completed ===")

if __name__ == "__main__":
    main()