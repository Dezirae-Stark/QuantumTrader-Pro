#!/usr/bin/env python3
"""
Comprehensive backtesting analysis with multiple parameter sets
"""
import pandas as pd
import numpy as np
from datetime import datetime
import matplotlib.pyplot as plt
from backtester import SignalBacktester, BacktestResult
from indicators.signal_engine import SignalEngine
import json

def run_parameter_sweep():
    """Test different parameter combinations"""
    from test_signal_engine import generate_test_data
    
    # Generate longer test data
    print("Generating test data...")
    df = generate_test_data('EURUSD', periods=2000)  # ~3 months of hourly data
    
    # Parameter sets to test
    param_sets = [
        {
            'name': 'Conservative',
            'position_size': 0.01,  # 1% risk
            'stop_loss': 0.02,      # 2% SL
            'take_profit': 0.04,    # 4% TP
            'min_probability': 65,
            'weights': {
                "Alligator": 1.5,
                "Elliott Wave": 0.7,
                "Awesome Oscillator": 0.6,
                "Fractals": 0.8,
                "Williams MFI": 0.5
            }
        },
        {
            'name': 'Balanced',
            'position_size': 0.02,  # 2% risk
            'stop_loss': 0.02,      # 2% SL
            'take_profit': 0.04,    # 4% TP
            'min_probability': 60,
            'weights': {
                "Alligator": 1.0,
                "Elliott Wave": 0.9,
                "Awesome Oscillator": 0.8,
                "Fractals": 0.8,
                "Williams MFI": 0.7
            }
        },
        {
            'name': 'Aggressive',
            'position_size': 0.03,  # 3% risk
            'stop_loss': 0.015,     # 1.5% SL
            'take_profit': 0.05,    # 5% TP
            'min_probability': 55,
            'weights': {
                "Alligator": 0.8,
                "Elliott Wave": 1.2,
                "Awesome Oscillator": 1.0,
                "Fractals": 0.9,
                "Williams MFI": 0.8
            }
        },
        {
            'name': 'Trend Following',
            'position_size': 0.02,
            'stop_loss': 0.025,     # 2.5% SL
            'take_profit': 0.06,    # 6% TP
            'min_probability': 60,
            'weights': {
                "Alligator": 2.0,      # Heavy trend weight
                "Elliott Wave": 0.5,
                "Awesome Oscillator": 0.4,
                "Fractals": 0.6,
                "Williams MFI": 0.3
            }
        },
        {
            'name': 'Pattern Based',
            'position_size': 0.02,
            'stop_loss': 0.02,
            'take_profit': 0.04,
            'min_probability': 62,
            'weights': {
                "Alligator": 0.5,
                "Elliott Wave": 2.0,   # Heavy pattern weight
                "Awesome Oscillator": 0.5,
                "Fractals": 1.5,       # Heavy pattern weight
                "Williams MFI": 0.5
            }
        }
    ]
    
    results = []
    
    for params in param_sets:
        print(f"\nTesting {params['name']} strategy...")
        
        # Create signal engine with custom weights
        engine = SignalEngine(custom_weights=params['weights'])
        
        # Create backtester
        backtester = SignalBacktester(signal_engine=engine, initial_capital=10000)
        
        # Set parameters
        backtester.position_size = params['position_size']
        backtester.stop_loss_pct = params['stop_loss']
        backtester.take_profit_pct = params['take_profit']
        
        # Run backtest
        result = backtester.run(df, symbol='EURUSD')
        
        # Store result with parameters
        results.append({
            'name': params['name'],
            'params': params,
            'result': result
        })
        
        # Print summary
        print(f"\n{params['name']} Results:")
        print(f"Return: {result.total_return_pct:.2f}%")
        print(f"Win Rate: {result.win_rate:.1%}")
        print(f"Profit Factor: {result.profit_factor:.2f}")
        print(f"Sharpe Ratio: {result.sharpe_ratio:.2f}")
        print(f"Max Drawdown: {result.max_drawdown_pct:.2f}%")
        print(f"Total Trades: {result.total_trades}")
    
    return results, df

def compare_strategies(results):
    """Create comparison table of strategies"""
    print("\n" + "="*80)
    print("STRATEGY COMPARISON")
    print("="*80)
    print(f"{'Strategy':<20} {'Return%':<10} {'Win%':<10} {'PF':<10} {'Sharpe':<10} {'MaxDD%':<10} {'Trades':<10}")
    print("-"*80)
    
    for r in results:
        result = r['result']
        print(f"{r['name']:<20} "
              f"{result.total_return_pct:<10.2f} "
              f"{result.win_rate*100:<10.1f} "
              f"{result.profit_factor:<10.2f} "
              f"{result.sharpe_ratio:<10.2f} "
              f"{result.max_drawdown_pct:<10.2f} "
              f"{result.total_trades:<10}")
    print("="*80)

def plot_equity_curves(results, df):
    """Plot equity curves for all strategies"""
    try:
        import matplotlib.pyplot as plt
        
        plt.figure(figsize=(12, 8))
        
        for r in results:
            # Recreate equity curve
            backtester = SignalBacktester(
                signal_engine=SignalEngine(custom_weights=r['params']['weights']),
                initial_capital=10000
            )
            backtester.position_size = r['params']['position_size']
            backtester.stop_loss_pct = r['params']['stop_loss']
            backtester.take_profit_pct = r['params']['take_profit']
            
            # Run to get equity curve
            _ = backtester.run(df, symbol='EURUSD')
            
            # Plot
            dates = df.index[:len(backtester.equity_curve)]
            plt.plot(dates, backtester.equity_curve, label=r['name'], linewidth=2)
        
        plt.xlabel('Date')
        plt.ylabel('Equity ($)')
        plt.title('Strategy Equity Curves Comparison')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig('equity_curves.png', dpi=300)
        print("\nEquity curves saved to equity_curves.png")
        
    except ImportError:
        print("\nMatplotlib not available, skipping equity curve plot")

def analyze_indicator_contribution(results):
    """Analyze which indicators contribute most to profits"""
    print("\n" + "="*60)
    print("INDICATOR CONTRIBUTION ANALYSIS")
    print("="*60)
    
    # Aggregate indicator stats across all strategies
    indicator_totals = {}
    
    for r in results:
        print(f"\n{r['name']} Strategy:")
        print("-"*40)
        
        for ind_name, stats in r['result'].indicator_performance.items():
            if stats['signals'] > 0:
                print(f"{ind_name:.<25} P&L: ${stats['total_pnl']:>8.2f}")
                
                if ind_name not in indicator_totals:
                    indicator_totals[ind_name] = {'pnl': 0, 'count': 0}
                indicator_totals[ind_name]['pnl'] += stats['total_pnl']
                indicator_totals[ind_name]['count'] += 1
    
    # Show aggregated results
    print("\n" + "="*60)
    print("OVERALL INDICATOR PERFORMANCE (Average across strategies)")
    print("-"*60)
    
    sorted_indicators = sorted(indicator_totals.items(), 
                             key=lambda x: x[1]['pnl']/x[1]['count'], 
                             reverse=True)
    
    for ind_name, totals in sorted_indicators:
        avg_pnl = totals['pnl'] / totals['count']
        print(f"{ind_name:.<30} Avg P&L: ${avg_pnl:>10.2f}")

def main():
    """Run comprehensive backtesting analysis"""
    print("="*60)
    print("COMPREHENSIVE BACKTESTING ANALYSIS")
    print("="*60)
    
    # Run parameter sweep
    results, df = run_parameter_sweep()
    
    # Compare strategies
    compare_strategies(results)
    
    # Analyze indicator contributions
    analyze_indicator_contribution(results)
    
    # Plot equity curves
    plot_equity_curves(results, df)
    
    # Find best strategy
    best_strategy = max(results, key=lambda x: x['result'].sharpe_ratio)
    print(f"\n🏆 Best Strategy (by Sharpe Ratio): {best_strategy['name']}")
    print(f"   Return: {best_strategy['result'].total_return_pct:.2f}%")
    print(f"   Sharpe: {best_strategy['result'].sharpe_ratio:.2f}")
    print(f"   Win Rate: {best_strategy['result'].win_rate:.1%}")
    
    # Save detailed results
    with open('backtest_comparison.json', 'w') as f:
        summary = []
        for r in results:
            summary.append({
                'name': r['name'],
                'params': r['params'],
                'metrics': {
                    'total_return_pct': r['result'].total_return_pct,
                    'win_rate': r['result'].win_rate,
                    'profit_factor': r['result'].profit_factor,
                    'sharpe_ratio': r['result'].sharpe_ratio,
                    'max_drawdown_pct': r['result'].max_drawdown_pct,
                    'total_trades': r['result'].total_trades
                }
            })
        json.dump(summary, f, indent=2)
    
    print("\nDetailed results saved to backtest_comparison.json")

if __name__ == "__main__":
    main()