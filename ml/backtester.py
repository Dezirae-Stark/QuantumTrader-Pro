#!/usr/bin/env python3
"""
Backtesting framework for signal engine and indicators
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Tuple
import json
import logging
from dataclasses import dataclass, asdict
from indicators.signal_engine import SignalEngine, SignalStrength
from technical_predictor import TechnicalPredictor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class Trade:
    """Represents a single trade"""
    entry_time: datetime
    exit_time: Optional[datetime]
    symbol: str
    direction: str  # 'long' or 'short'
    entry_price: float
    exit_price: Optional[float] = None
    size: float = 1.0
    pnl: float = 0.0
    pnl_pct: float = 0.0
    max_drawdown: float = 0.0
    entry_signal: str = ""
    exit_signal: str = ""
    entry_confidence: float = 0.0
    
    def close(self, exit_price: float, exit_time: datetime):
        """Close the trade and calculate P&L"""
        self.exit_price = exit_price
        self.exit_time = exit_time
        
        if self.direction == 'long':
            self.pnl = (exit_price - self.entry_price) * self.size
            self.pnl_pct = ((exit_price - self.entry_price) / self.entry_price) * 100
        else:  # short
            self.pnl = (self.entry_price - exit_price) * self.size
            self.pnl_pct = ((self.entry_price - exit_price) / self.entry_price) * 100


@dataclass
class BacktestResult:
    """Results from a backtest run"""
    start_date: datetime
    end_date: datetime
    initial_capital: float
    final_capital: float
    total_return: float
    total_return_pct: float
    trades: List[Trade]
    win_rate: float
    profit_factor: float
    sharpe_ratio: float
    max_drawdown: float
    max_drawdown_pct: float
    total_trades: int
    winning_trades: int
    losing_trades: int
    avg_win: float
    avg_loss: float
    best_trade: float
    worst_trade: float
    avg_trade_duration: timedelta
    exposure_time_pct: float
    indicator_performance: Dict[str, Dict]


class SignalBacktester:
    """Backtesting framework for signal engine"""
    
    def __init__(self, signal_engine: Optional[SignalEngine] = None, 
                 initial_capital: float = 10000.0):
        self.signal_engine = signal_engine or SignalEngine()
        self.initial_capital = initial_capital
        self.capital = initial_capital
        self.trades: List[Trade] = []
        self.equity_curve: List[float] = []
        self.current_position: Optional[Trade] = None
        
        # Risk management parameters
        self.position_size = 0.02  # 2% of capital per trade
        self.stop_loss_pct = 0.02   # 2% stop loss
        self.take_profit_pct = 0.04 # 4% take profit
        self.max_positions = 1      # Maximum concurrent positions
        
    def run(self, df: pd.DataFrame, symbol: str = 'UNKNOWN',
            start_date: Optional[datetime] = None,
            end_date: Optional[datetime] = None) -> BacktestResult:
        """Run backtest on historical data"""
        logger.info(f"Starting backtest for {symbol}")
        
        # Filter date range if specified
        if start_date:
            df = df[df.index >= start_date]
        if end_date:
            df = df[df.index <= end_date]
            
        # Reset state
        self.capital = self.initial_capital
        self.trades = []
        self.equity_curve = [self.initial_capital]
        self.current_position = None
        
        # Track indicator contributions
        indicator_stats = {ind.indicator.name: {
            'signals': 0,
            'correct': 0,
            'total_pnl': 0.0
        } for ind in self.signal_engine.configurations}
        
        # Process each bar
        min_periods = self.signal_engine.get_required_periods()
        
        for i in range(min_periods, len(df)):
            # Get data up to current bar
            current_data = df.iloc[:i+1]
            current_bar = df.iloc[i]
            current_time = df.index[i]
            
            # Check stop loss and take profit for open position
            if self.current_position:
                self._check_exit_conditions(current_bar, current_time)
            
            # Get signal from engine
            try:
                analysis = self.signal_engine.analyze(current_data, symbol)
                
                # Track which indicators contributed
                for ind_name, ind_data in analysis.contributing_signals.items():
                    indicator_stats[ind_name]['signals'] += 1
                
                # Process signal
                self._process_signal(analysis, current_bar, current_time, indicator_stats)
                
            except Exception as e:
                logger.warning(f"Error analyzing bar {i}: {e}")
                continue
            
            # Update equity
            self._update_equity(current_bar)
            
        # Close any open positions at end
        if self.current_position:
            self._close_position(df.iloc[-1]['close'], df.index[-1], 'End of backtest')
            
        # Calculate results
        return self._calculate_results(df, indicator_stats)
    
    def _process_signal(self, analysis, current_bar, current_time, indicator_stats):
        """Process trading signal"""
        signal = analysis.signal
        confidence = analysis.confidence
        probability = analysis.probability
        
        # Entry logic
        if not self.current_position:
            if signal in [SignalStrength.STRONG_BUY, SignalStrength.BUY] and probability > 60:
                # Open long position
                self._open_position(
                    'long', current_bar['close'], current_time,
                    f"{signal.name} (P={probability:.1f}%)", confidence
                )
            elif signal in [SignalStrength.STRONG_SELL, SignalStrength.SELL] and probability > 60:
                # Open short position
                self._open_position(
                    'short', current_bar['close'], current_time,
                    f"{signal.name} (P={probability:.1f}%)", confidence
                )
                
        # Exit logic for existing position
        elif self.current_position:
            # Exit on opposite signal
            if self.current_position.direction == 'long' and \
               signal in [SignalStrength.STRONG_SELL, SignalStrength.SELL]:
                self._close_position(current_bar['close'], current_time, signal.name)
            elif self.current_position.direction == 'short' and \
                 signal in [SignalStrength.STRONG_BUY, SignalStrength.BUY]:
                self._close_position(current_bar['close'], current_time, signal.name)
    
    def _open_position(self, direction: str, price: float, time: datetime, 
                      signal: str, confidence: float):
        """Open a new position"""
        # Calculate position size based on risk
        risk_amount = self.capital * self.position_size
        stop_distance = price * self.stop_loss_pct
        position_size = risk_amount / stop_distance
        
        self.current_position = Trade(
            entry_time=time,
            exit_time=None,
            symbol='UNKNOWN',
            direction=direction,
            entry_price=price,
            size=position_size,
            entry_signal=signal,
            entry_confidence=confidence
        )
        
        logger.info(f"Opened {direction} position at {price:.5f} - {signal}")
    
    def _close_position(self, price: float, time: datetime, reason: str):
        """Close current position"""
        if not self.current_position:
            return
            
        self.current_position.close(price, time)
        self.current_position.exit_signal = reason
        
        # Update capital
        self.capital += self.current_position.pnl
        
        # Record trade
        self.trades.append(self.current_position)
        
        logger.info(f"Closed position at {price:.5f} - P&L: {self.current_position.pnl:.2f} "
                   f"({self.current_position.pnl_pct:.2f}%) - {reason}")
        
        self.current_position = None
    
    def _check_exit_conditions(self, current_bar, current_time):
        """Check stop loss and take profit"""
        if not self.current_position:
            return
            
        entry_price = self.current_position.entry_price
        current_price = current_bar['close']
        
        if self.current_position.direction == 'long':
            # Track max drawdown before checking exits
            if self.current_position:
                drawdown = (entry_price - current_bar['low']) / entry_price
                self.current_position.max_drawdown = max(self.current_position.max_drawdown, drawdown)
            
            # Check stop loss
            if current_price <= entry_price * (1 - self.stop_loss_pct):
                self._close_position(current_price, current_time, 'Stop Loss')
                return
            # Check take profit
            elif current_price >= entry_price * (1 + self.take_profit_pct):
                self._close_position(current_price, current_time, 'Take Profit')
                return
            
        else:  # short
            # Track max drawdown before checking exits
            if self.current_position:
                drawdown = (current_bar['high'] - entry_price) / entry_price
                self.current_position.max_drawdown = max(self.current_position.max_drawdown, drawdown)
            
            # Check stop loss
            if current_price >= entry_price * (1 + self.stop_loss_pct):
                self._close_position(current_price, current_time, 'Stop Loss')
                return
            # Check take profit
            elif current_price <= entry_price * (1 - self.take_profit_pct):
                self._close_position(current_price, current_time, 'Take Profit')
                return
    
    def _update_equity(self, current_bar):
        """Update equity curve"""
        equity = self.capital
        
        # Add unrealized P&L
        if self.current_position:
            current_price = current_bar['close']
            if self.current_position.direction == 'long':
                unrealized = (current_price - self.current_position.entry_price) * \
                            self.current_position.size
            else:
                unrealized = (self.current_position.entry_price - current_price) * \
                            self.current_position.size
            equity += unrealized
            
        self.equity_curve.append(equity)
    
    def _calculate_results(self, df: pd.DataFrame, 
                          indicator_stats: Dict) -> BacktestResult:
        """Calculate backtest statistics"""
        if not self.trades:
            return BacktestResult(
                start_date=df.index[0],
                end_date=df.index[-1],
                initial_capital=self.initial_capital,
                final_capital=self.capital,
                total_return=0,
                total_return_pct=0,
                trades=[],
                win_rate=0,
                profit_factor=0,
                sharpe_ratio=0,
                max_drawdown=0,
                max_drawdown_pct=0,
                total_trades=0,
                winning_trades=0,
                losing_trades=0,
                avg_win=0,
                avg_loss=0,
                best_trade=0,
                worst_trade=0,
                avg_trade_duration=timedelta(0),
                exposure_time_pct=0,
                indicator_performance=indicator_stats
            )
        
        # Basic statistics
        winning_trades = [t for t in self.trades if t.pnl > 0]
        losing_trades = [t for t in self.trades if t.pnl <= 0]
        
        total_return = self.capital - self.initial_capital
        total_return_pct = (total_return / self.initial_capital) * 100
        
        win_rate = len(winning_trades) / len(self.trades) if self.trades else 0
        
        # Profit factor
        total_wins = sum(t.pnl for t in winning_trades)
        total_losses = abs(sum(t.pnl for t in losing_trades))
        profit_factor = total_wins / total_losses if total_losses > 0 else float('inf')
        
        # Average win/loss
        avg_win = np.mean([t.pnl for t in winning_trades]) if winning_trades else 0
        avg_loss = np.mean([t.pnl for t in losing_trades]) if losing_trades else 0
        
        # Best/worst trades
        best_trade = max(t.pnl for t in self.trades) if self.trades else 0
        worst_trade = min(t.pnl for t in self.trades) if self.trades else 0
        
        # Trade duration
        durations = [(t.exit_time - t.entry_time) for t in self.trades if t.exit_time]
        avg_duration = sum(durations, timedelta(0)) / len(durations) if durations else timedelta(0)
        
        # Exposure time
        total_time = (df.index[-1] - df.index[0]).total_seconds()
        exposure_time = sum(d.total_seconds() for d in durations)
        exposure_pct = (exposure_time / total_time * 100) if total_time > 0 else 0
        
        # Sharpe ratio (simplified)
        equity_returns = pd.Series(self.equity_curve).pct_change().dropna()
        if len(equity_returns) > 0:
            sharpe_ratio = (equity_returns.mean() / equity_returns.std()) * np.sqrt(252) \
                          if equity_returns.std() > 0 else 0
        else:
            sharpe_ratio = 0
        
        # Max drawdown
        equity_series = pd.Series(self.equity_curve)
        rolling_max = equity_series.expanding().max()
        drawdown_series = (equity_series - rolling_max) / rolling_max
        max_drawdown = abs(drawdown_series.min())
        max_drawdown_pct = max_drawdown * 100
        
        # Update indicator stats with P&L attribution
        for trade in self.trades:
            # Simple attribution - could be enhanced
            main_indicator = trade.entry_signal.split()[0] if trade.entry_signal else 'Unknown'
            for ind_name in indicator_stats:
                if ind_name in trade.entry_signal:
                    indicator_stats[ind_name]['total_pnl'] += trade.pnl
                    if trade.pnl > 0:
                        indicator_stats[ind_name]['correct'] += 1
        
        return BacktestResult(
            start_date=df.index[0],
            end_date=df.index[-1],
            initial_capital=self.initial_capital,
            final_capital=self.capital,
            total_return=total_return,
            total_return_pct=total_return_pct,
            trades=self.trades,
            win_rate=win_rate,
            profit_factor=profit_factor,
            sharpe_ratio=sharpe_ratio,
            max_drawdown=max_drawdown,
            max_drawdown_pct=max_drawdown_pct,
            total_trades=len(self.trades),
            winning_trades=len(winning_trades),
            losing_trades=len(losing_trades),
            avg_win=avg_win,
            avg_loss=avg_loss,
            best_trade=best_trade,
            worst_trade=worst_trade,
            avg_trade_duration=avg_duration,
            exposure_time_pct=exposure_pct,
            indicator_performance=indicator_stats
        )
    
    def save_results(self, result: BacktestResult, filename: str):
        """Save backtest results to file"""
        # Convert to dict
        result_dict = asdict(result)
        
        # Convert datetime objects
        result_dict['start_date'] = result.start_date.isoformat()
        result_dict['end_date'] = result.end_date.isoformat()
        result_dict['avg_trade_duration'] = str(result.avg_trade_duration)
        
        # Convert trades
        result_dict['trades'] = []
        for trade in result.trades:
            trade_dict = asdict(trade)
            trade_dict['entry_time'] = trade.entry_time.isoformat()
            if trade.exit_time:
                trade_dict['exit_time'] = trade.exit_time.isoformat()
            result_dict['trades'].append(trade_dict)
        
        # Save to file
        with open(filename, 'w') as f:
            json.dump(result_dict, f, indent=2)
        
        logger.info(f"Results saved to {filename}")
    
    def print_summary(self, result: BacktestResult):
        """Print backtest summary"""
        print("\n" + "="*60)
        print("BACKTEST RESULTS SUMMARY")
        print("="*60)
        print(f"Period: {result.start_date.date()} to {result.end_date.date()}")
        print(f"Initial Capital: ${result.initial_capital:,.2f}")
        print(f"Final Capital: ${result.final_capital:,.2f}")
        print(f"Total Return: ${result.total_return:,.2f} ({result.total_return_pct:.2f}%)")
        print(f"\nTotal Trades: {result.total_trades}")
        print(f"Win Rate: {result.win_rate:.1%}")
        print(f"Profit Factor: {result.profit_factor:.2f}")
        print(f"Sharpe Ratio: {result.sharpe_ratio:.2f}")
        print(f"Max Drawdown: {result.max_drawdown_pct:.2f}%")
        print(f"\nAverage Win: ${result.avg_win:.2f}")
        print(f"Average Loss: ${result.avg_loss:.2f}")
        print(f"Best Trade: ${result.best_trade:.2f}")
        print(f"Worst Trade: ${result.worst_trade:.2f}")
        print(f"Avg Trade Duration: {result.avg_trade_duration}")
        print(f"Market Exposure: {result.exposure_time_pct:.1f}%")
        
        print("\n" + "-"*60)
        print("INDICATOR PERFORMANCE")
        print("-"*60)
        for ind_name, stats in result.indicator_performance.items():
            if stats['signals'] > 0:
                accuracy = (stats['correct'] / stats['signals']) * 100 if stats['signals'] > 0 else 0
                print(f"{ind_name:.<25} "
                      f"Signals: {stats['signals']:>4} "
                      f"Accuracy: {accuracy:>5.1f}% "
                      f"P&L: ${stats['total_pnl']:>8.2f}")
        print("="*60 + "\n")


def run_backtest_example():
    """Example of running a backtest"""
    import sys
    sys.path.append('.')  # Add current directory to path
    
    # Generate test data
    from test_signal_engine import generate_test_data
    
    print("Generating test data...")
    df = generate_test_data('EURUSD', periods=1000)
    
    # Create signal engine with custom weights
    engine = SignalEngine(custom_weights={
        "Alligator": 1.2,
        "Elliott Wave": 0.9,
        "Awesome Oscillator": 0.8,
        "Fractals": 0.7,
        "Williams MFI": 0.6
    })
    
    # Create backtester
    backtester = SignalBacktester(signal_engine=engine, initial_capital=10000)
    
    # Configure risk parameters
    backtester.position_size = 0.02  # 2% risk per trade
    backtester.stop_loss_pct = 0.02  # 2% stop loss
    backtester.take_profit_pct = 0.04  # 4% take profit
    
    print("Running backtest...")
    result = backtester.run(df, symbol='EURUSD')
    
    # Print summary
    backtester.print_summary(result)
    
    # Save results
    backtester.save_results(result, 'backtest_results.json')
    
    return result


if __name__ == "__main__":
    run_backtest_example()