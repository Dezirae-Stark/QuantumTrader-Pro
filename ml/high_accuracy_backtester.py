#!/usr/bin/env python3
"""
High Accuracy Backtester - Targeting 94.7%+ Win Rate
Tests the enhanced trading engine with strict entry criteria
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import json
import logging

from high_accuracy_engine import HighAccuracyEngine, EnhancedSignal
from indicators.base import SignalStrength
from backtester import Trade, BacktestResult

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class HighAccuracyBacktester:
    """Backtester for high accuracy trading strategy"""
    
    def __init__(self, initial_capital: float = 10000.0):
        self.engine = HighAccuracyEngine()
        self.initial_capital = initial_capital
        self.capital = initial_capital
        self.trades: List[Trade] = []
        self.equity_curve: List[float] = []
        self.current_position: Optional[Trade] = None
        
        # Conservative risk management for high win rate
        self.position_size_pct = 0.01      # 1% risk per trade (very conservative)
        self.stop_loss_atr_mult = 0.5      # 0.5 ATR stop (tight)
        self.take_profit_atr_mult = 2.0    # 2.0 ATR target (4:1 RR with tight stop)
        self.max_daily_trades = 3          # Limit trades per day
        self.daily_trade_count = {}        # Track daily trades
        
        # Performance tracking
        self.signals_analyzed = 0
        self.signals_filtered = 0
        self.entry_scores: List[float] = []
        
    def run(self, df: pd.DataFrame, symbol: str = 'UNKNOWN',
            spread: float = 0.0001) -> Dict:
        """Run high accuracy backtest"""
        logger.info(f"Starting high accuracy backtest for {symbol}")
        
        # Reset state
        self.capital = self.initial_capital
        self.trades = []
        self.equity_curve = [self.initial_capital]
        self.current_position = None
        self.signals_analyzed = 0
        self.signals_filtered = 0
        self.entry_scores = []
        self.daily_trade_count = {}
        
        # Process each bar
        min_periods = self.engine.signal_engine.get_required_periods()
        
        for i in range(min_periods, len(df)):
            # Get data up to current bar
            current_data = df.iloc[:i+1]
            current_bar = df.iloc[i]
            current_time = df.index[i]
            current_date = current_time.date()
            
            # Check position exit conditions first
            if self.current_position:
                self._check_exit_conditions(current_bar, current_time, current_data)
            
            # Skip if we've hit daily trade limit
            if self.daily_trade_count.get(current_date, 0) >= self.max_daily_trades:
                continue
            
            # Skip if we have an open position (one trade at a time)
            if self.current_position:
                continue
            
            try:
                # Get enhanced signal
                signal = self.engine.analyze_enhanced(current_data, symbol, spread)
                self.signals_analyzed += 1
                self.entry_scores.append(signal.entry_score)
                
                # Check if we should enter
                should_enter, reason = self.engine.should_enter_trade(signal)
                
                if should_enter:
                    self._open_position(signal, current_bar, current_time, current_data)
                    self.daily_trade_count[current_date] = self.daily_trade_count.get(current_date, 0) + 1
                else:
                    self.signals_filtered += 1
                    logger.debug(f"Signal filtered: {reason}")
                    
            except Exception as e:
                logger.warning(f"Error analyzing bar {i}: {e}")
                continue
            
            # Update equity
            self._update_equity(current_bar)
        
        # Close any open position
        if self.current_position:
            self._close_position(df.iloc[-1]['close'], df.index[-1], 'End of backtest')
        
        # Calculate enhanced results
        return self._calculate_results(df)
    
    def _open_position(self, signal: EnhancedSignal, current_bar, current_time, df):
        """Open position with enhanced signal"""
        price = current_bar['close']
        
        # Calculate position size based on volatility
        atr = self._calculate_atr(df).iloc[-1]
        stop_distance = atr * self.stop_loss_atr_mult
        
        # Risk-based position sizing
        risk_amount = self.capital * self.position_size_pct
        position_size = risk_amount / stop_distance
        
        # Determine direction
        if signal.primary_signal in [SignalStrength.BUY, SignalStrength.STRONG_BUY]:
            direction = 'long'
            stop_price = price - stop_distance
            target_price = price + (atr * self.take_profit_atr_mult)
        else:
            direction = 'short'
            stop_price = price + stop_distance
            target_price = price - (atr * self.take_profit_atr_mult)
        
        self.current_position = Trade(
            entry_time=current_time,
            exit_time=None,
            symbol='UNKNOWN',
            direction=direction,
            entry_price=price,
            size=position_size,
            entry_signal=f"{signal.primary_signal.name} Score:{signal.entry_score:.1f}%",
            entry_confidence=signal.confidence
        )
        
        # Store additional info
        self.current_position.stop_price = stop_price
        self.current_position.target_price = target_price
        self.current_position.entry_filters = signal.filters_passed
        
        logger.info(f"Opened {direction} at {price:.5f} | "
                   f"Score: {signal.entry_score:.1f}% | "
                   f"Filters: {len(signal.filters_passed)}/{len(signal.confirmations)}")
    
    def _check_exit_conditions(self, current_bar, current_time, df):
        """Check exit conditions with trailing stop"""
        if not self.current_position:
            return
        
        price = current_bar['close']
        high = current_bar['high']
        low = current_bar['low']
        
        # Update trailing stop
        if self.current_position.direction == 'long':
            # Check if we've moved favorably
            if price > self.current_position.entry_price:
                # Calculate new trailing stop based on recent ATR
                atr = self._calculate_atr(df).iloc[-1]
                new_stop = price - (atr * self.stop_loss_atr_mult * 0.7)  # Tighter trailing
                
                if hasattr(self.current_position, 'stop_price'):
                    self.current_position.stop_price = max(self.current_position.stop_price, new_stop)
            
            # Check exits
            if low <= self.current_position.stop_price:
                self._close_position(self.current_position.stop_price, current_time, 'Stop Loss')
            elif high >= self.current_position.target_price:
                self._close_position(self.current_position.target_price, current_time, 'Take Profit')
                
        else:  # short
            # Check if we've moved favorably
            if price < self.current_position.entry_price:
                # Calculate new trailing stop
                atr = self._calculate_atr(df).iloc[-1]
                new_stop = price + (atr * self.stop_loss_atr_mult * 0.7)
                
                if hasattr(self.current_position, 'stop_price'):
                    self.current_position.stop_price = min(self.current_position.stop_price, new_stop)
            
            # Check exits
            if high >= self.current_position.stop_price:
                self._close_position(self.current_position.stop_price, current_time, 'Stop Loss')
            elif low <= self.current_position.target_price:
                self._close_position(self.current_position.target_price, current_time, 'Take Profit')
    
    def _close_position(self, price: float, time: datetime, reason: str):
        """Close position and record results"""
        if not self.current_position:
            return
        
        self.current_position.close(price, time)
        self.current_position.exit_signal = reason
        
        # Update capital
        self.capital += self.current_position.pnl
        
        # Record trade
        self.trades.append(self.current_position)
        
        # Log result
        result = "WIN" if self.current_position.pnl > 0 else "LOSS"
        logger.info(f"Closed {result} at {price:.5f} | "
                   f"P&L: {self.current_position.pnl:.2f} ({self.current_position.pnl_pct:.2f}%) | "
                   f"{reason}")
        
        self.current_position = None
    
    def _update_equity(self, current_bar):
        """Update equity curve"""
        equity = self.capital
        
        # Add unrealized P&L
        if self.current_position:
            current_price = current_bar['close']
            if self.current_position.direction == 'long':
                unrealized = (current_price - self.current_position.entry_price) * self.current_position.size
            else:
                unrealized = (self.current_position.entry_price - current_price) * self.current_position.size
            equity += unrealized
        
        self.equity_curve.append(equity)
    
    def _calculate_results(self, df: pd.DataFrame) -> Dict:
        """Calculate comprehensive results"""
        # Basic trade statistics
        if not self.trades:
            win_rate = 0
            avg_win = 0
            avg_loss = 0
            profit_factor = 0
        else:
            winning_trades = [t for t in self.trades if t.pnl > 0]
            losing_trades = [t for t in self.trades if t.pnl <= 0]
            
            win_rate = len(winning_trades) / len(self.trades) * 100
            
            avg_win = np.mean([t.pnl for t in winning_trades]) if winning_trades else 0
            avg_loss = np.mean([abs(t.pnl) for t in losing_trades]) if losing_trades else 0
            
            total_wins = sum(t.pnl for t in winning_trades)
            total_losses = abs(sum(t.pnl for t in losing_trades))
            profit_factor = total_wins / total_losses if total_losses > 0 else float('inf')
        
        # Calculate returns
        total_return = self.capital - self.initial_capital
        total_return_pct = (total_return / self.initial_capital) * 100
        
        # Sharpe ratio
        equity_series = pd.Series(self.equity_curve)
        equity_returns = equity_series.pct_change().dropna()
        sharpe_ratio = (equity_returns.mean() / equity_returns.std()) * np.sqrt(252 * 24) if len(equity_returns) > 0 and equity_returns.std() > 0 else 0
        
        # Max drawdown
        rolling_max = equity_series.expanding().max()
        drawdown_series = (equity_series - rolling_max) / rolling_max
        max_drawdown_pct = abs(drawdown_series.min()) * 100
        
        # Signal analysis
        avg_entry_score = np.mean(self.entry_scores) if self.entry_scores else 0
        signal_filter_rate = (self.signals_filtered / self.signals_analyzed * 100) if self.signals_analyzed > 0 else 0
        
        # Compile results
        results = {
            'performance': {
                'initial_capital': self.initial_capital,
                'final_capital': self.capital,
                'total_return': total_return,
                'total_return_pct': total_return_pct,
                'win_rate': win_rate,
                'profit_factor': profit_factor,
                'sharpe_ratio': sharpe_ratio,
                'max_drawdown_pct': max_drawdown_pct,
                'total_trades': len(self.trades),
                'winning_trades': len([t for t in self.trades if t.pnl > 0]),
                'losing_trades': len([t for t in self.trades if t.pnl <= 0]),
                'avg_win': avg_win,
                'avg_loss': avg_loss,
                'best_trade': max(t.pnl for t in self.trades) if self.trades else 0,
                'worst_trade': min(t.pnl for t in self.trades) if self.trades else 0
            },
            'signal_analysis': {
                'signals_analyzed': self.signals_analyzed,
                'signals_filtered': self.signals_filtered,
                'signal_filter_rate': signal_filter_rate,
                'avg_entry_score': avg_entry_score,
                'min_entry_score': min(self.entry_scores) if self.entry_scores else 0,
                'max_entry_score': max(self.entry_scores) if self.entry_scores else 0
            },
            'trades': [self._trade_to_dict(t) for t in self.trades],
            'equity_curve': self.equity_curve
        }
        
        return results
    
    def _trade_to_dict(self, trade: Trade) -> Dict:
        """Convert trade to dictionary"""
        return {
            'entry_time': trade.entry_time.isoformat(),
            'exit_time': trade.exit_time.isoformat() if trade.exit_time else None,
            'direction': trade.direction,
            'entry_price': trade.entry_price,
            'exit_price': trade.exit_price,
            'pnl': trade.pnl,
            'pnl_pct': trade.pnl_pct,
            'entry_signal': trade.entry_signal,
            'exit_signal': trade.exit_signal,
            'entry_confidence': trade.entry_confidence,
            'filters_passed': getattr(trade, 'entry_filters', [])
        }
    
    def _calculate_atr(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """Calculate ATR"""
        high = df['high']
        low = df['low']
        close = df['close']
        
        tr1 = high - low
        tr2 = abs(high - close.shift())
        tr3 = abs(low - close.shift())
        
        tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        atr = tr.rolling(window=period).mean()
        
        return atr
    
    def print_results(self, results: Dict):
        """Print formatted results"""
        perf = results['performance']
        signals = results['signal_analysis']
        
        print("\n" + "="*60)
        print("HIGH ACCURACY BACKTEST RESULTS")
        print("="*60)
        print(f"Win Rate: {perf['win_rate']:.1f}% " + 
              ("✅" if perf['win_rate'] >= 94.7 else "❌"))
        print(f"Total Return: ${perf['total_return']:.2f} ({perf['total_return_pct']:.2f}%)")
        print(f"Sharpe Ratio: {perf['sharpe_ratio']:.2f}")
        print(f"Max Drawdown: {perf['max_drawdown_pct']:.2f}%")
        print(f"\nTotal Trades: {perf['total_trades']}")
        print(f"Winning Trades: {perf['winning_trades']}")
        print(f"Losing Trades: {perf['losing_trades']}")
        print(f"Profit Factor: {perf['profit_factor']:.2f}")
        print(f"\nAverage Win: ${perf['avg_win']:.2f}")
        print(f"Average Loss: ${perf['avg_loss']:.2f}")
        print(f"Best Trade: ${perf['best_trade']:.2f}")
        print(f"Worst Trade: ${perf['worst_trade']:.2f}")
        
        print("\n" + "-"*60)
        print("SIGNAL ANALYSIS")
        print("-"*60)
        print(f"Signals Analyzed: {signals['signals_analyzed']}")
        print(f"Signals Filtered: {signals['signals_filtered']} ({signals['signal_filter_rate']:.1f}%)")
        print(f"Average Entry Score: {signals['avg_entry_score']:.1f}%")
        print(f"Entry Score Range: {signals['min_entry_score']:.1f}% - {signals['max_entry_score']:.1f}%")
        print("="*60 + "\n")


def run_high_accuracy_test():
    """Test the high accuracy trading system"""
    from test_signal_engine import generate_test_data
    
    print("Testing High Accuracy Trading Engine")
    print("Target: 94.7%+ Win Rate\n")
    
    # Generate test data
    df = generate_test_data('EURUSD', periods=2000)
    
    # Run backtest
    backtester = HighAccuracyBacktester(initial_capital=10000)
    results = backtester.run(df, 'EURUSD', spread=0.0001)
    
    # Print results
    backtester.print_results(results)
    
    # Save results
    with open('high_accuracy_results.json', 'w') as f:
        # Remove non-serializable data
        save_results = {
            'performance': results['performance'],
            'signal_analysis': results['signal_analysis'],
            'trades': results['trades']
        }
        json.dump(save_results, f, indent=2)
    
    return results


if __name__ == "__main__":
    run_high_accuracy_test()