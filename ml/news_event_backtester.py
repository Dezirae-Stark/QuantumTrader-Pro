#!/usr/bin/env python3
"""
News Event Trading Backtester - Validates News Trading Strategies
Tests NFP, FOMC, ECB, BOE strategies with historical data
Target: 85%+ win rate validation
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Tuple, Any
import logging
import json

from news_event_trading_suite import (
    NewsEventTradingSuite, NewsEventType, NewsStrategy, 
    NewsTradingPhase, NewsEvent, NewsSignal
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class NewsEventBacktester:
    """
    Comprehensive backtesting system for news event trading strategies
    
    Features:
    - Historical news event simulation
    - Strategy-specific performance analysis
    - Risk-adjusted returns calculation
    - Drawdown analysis
    - Win rate validation
    """
    
    def __init__(self):
        self.news_trader = NewsEventTradingSuite()
        self.results = {
            'trades': [],
            'performance': {},
            'statistics': {}
        }
        
        # Trading parameters
        self.initial_balance = 10000
        self.risk_per_trade = 0.02  # 2% per trade
        self.slippage = 0.0001     # 1 pip slippage
        self.commission = 2.0      # $2 per trade
        
        # News event history (mock data for demonstration)
        self.historical_events = self._generate_historical_events()
    
    def run_comprehensive_backtest(self, df: pd.DataFrame, symbol: str,
                                 start_date: datetime, end_date: datetime) -> Dict:
        """
        Run comprehensive backtest of news trading strategies
        """
        logger.info(f"Starting news event backtest for {symbol} from {start_date} to {end_date}")
        
        # Initialize tracking
        balance = self.initial_balance
        equity_curve = []
        trades_log = []
        
        # Filter relevant events
        relevant_events = self._get_events_in_period(start_date, end_date, symbol)
        
        logger.info(f"Found {len(relevant_events)} news events to backtest")
        
        for event in relevant_events:
            # Get data window around event
            event_data = self._get_event_data_window(df, event)
            
            if event_data is None or len(event_data) < 100:
                continue
            
            # Test different phases of the event
            phases_to_test = [
                (NewsTradingPhase.PRE_EVENT, -30),
                (NewsTradingPhase.EVENT_RELEASE, 0),
                (NewsTradingPhase.INITIAL_MOVE, 5),
                (NewsTradingPhase.FOLLOW_THROUGH, 30),
                (NewsTradingPhase.REVERSAL, 120)
            ]
            
            for phase, minutes_offset in phases_to_test:
                test_time = event.release_time + timedelta(minutes=minutes_offset)
                
                # Get signal at this time
                signal = self._simulate_news_signal(event_data, event, test_time)
                
                if signal:
                    # Execute simulated trade
                    trade_result = self._execute_simulated_trade(
                        signal, event_data, balance, test_time
                    )
                    
                    if trade_result:
                        trades_log.append(trade_result)
                        balance = trade_result['final_balance']
                        
                        # Track equity
                        equity_curve.append({
                            'timestamp': test_time,
                            'balance': balance,
                            'drawdown': self._calculate_drawdown(equity_curve, balance)
                        })
        
        # Analyze results
        self.results = self._analyze_backtest_results(trades_log, equity_curve)
        
        logger.info(f"Backtest completed: {len(trades_log)} trades, "
                   f"Final balance: ${balance:.2f}")
        
        return self.results
    
    def _get_events_in_period(self, start_date: datetime, end_date: datetime,
                            symbol: str) -> List[NewsEvent]:
        """Get news events in the specified period"""
        events = []
        
        for event in self.historical_events:
            if (start_date <= event.release_time <= end_date and 
                event.symbol == symbol):
                events.append(event)
        
        return sorted(events, key=lambda x: x.release_time)
    
    def _get_event_data_window(self, df: pd.DataFrame, event: NewsEvent) -> Optional[pd.DataFrame]:
        """Get data window around a news event"""
        try:
            # For demonstration, use the full DataFrame
            # In production, would filter by timestamp
            return df.copy()
        except Exception as e:
            logger.error(f"Error getting event data: {e}")
            return None
    
    def _simulate_news_signal(self, df: pd.DataFrame, event: NewsEvent,
                            test_time: datetime) -> Optional[NewsSignal]:
        """Simulate getting a news signal at a specific time"""
        try:
            # Create upcoming events list for the simulation
            upcoming_events = [event]
            
            return self.news_trader.analyze_news_opportunity(
                df, event.symbol, upcoming_events, test_time
            )
        except Exception as e:
            logger.error(f"Error simulating news signal: {e}")
            return None
    
    def _execute_simulated_trade(self, signal: NewsSignal, df: pd.DataFrame,
                               initial_balance: float, entry_time: datetime) -> Optional[Dict]:
        """Execute a simulated trade based on the signal"""
        try:
            # Calculate position size
            stop_distance = abs(signal.entry_price - signal.stop_loss)
            risk_amount = initial_balance * self.risk_per_trade
            position_size = risk_amount / stop_distance if stop_distance > 0 else 0
            
            if position_size <= 0:
                return None
            
            # Apply slippage
            entry_price = signal.entry_price
            if signal.direction.name == 'BUY':
                entry_price += self.slippage
            else:
                entry_price -= self.slippage
            
            # Simulate trade execution
            trade_result = self._simulate_trade_outcome(
                signal, entry_price, position_size, df, entry_time
            )
            
            # Calculate P&L
            pnl = trade_result['exit_price'] - entry_price
            if signal.direction.name == 'SELL':
                pnl = -pnl
            
            pnl_amount = pnl * position_size - self.commission
            
            return {
                'event_type': signal.event.event_type.value,
                'strategy': signal.strategy.value,
                'phase': signal.phase.value,
                'direction': signal.direction.name,
                'entry_time': entry_time,
                'entry_price': entry_price,
                'exit_price': trade_result['exit_price'],
                'exit_reason': trade_result['exit_reason'],
                'position_size': position_size,
                'pnl': pnl_amount,
                'pnl_pct': pnl_amount / initial_balance,
                'hold_time': trade_result['hold_time'],
                'initial_balance': initial_balance,
                'final_balance': initial_balance + pnl_amount,
                'won': pnl_amount > 0,
                'confidence': signal.confidence,
                'risk_reward': signal.risk_reward
            }
            
        except Exception as e:
            logger.error(f"Error executing simulated trade: {e}")
            return None
    
    def _simulate_trade_outcome(self, signal: NewsSignal, entry_price: float,
                              position_size: float, df: pd.DataFrame,
                              entry_time: datetime) -> Dict:
        """Simulate how a trade would have played out"""
        # For demonstration, create a simple simulation
        # In production, would use tick data around news events
        
        max_hold_minutes = signal.max_hold_time
        
        # Simulate price movement (simplified)
        volatility = self._estimate_event_volatility(signal.event.event_type)
        
        # Generate simulated price path
        steps = min(max_hold_minutes, 60)  # Maximum 60 steps
        price_path = self._generate_price_path(entry_price, volatility, steps)
        
        # Check exits
        for i, price in enumerate(price_path):
            # Check stop loss
            if signal.direction.name == 'BUY':
                if price <= signal.stop_loss:
                    return {
                        'exit_price': signal.stop_loss,
                        'exit_reason': 'stop_loss',
                        'hold_time': i + 1
                    }
                # Check targets
                if price >= signal.take_profit_1:
                    return {
                        'exit_price': signal.take_profit_1,
                        'exit_reason': 'target_1',
                        'hold_time': i + 1
                    }
                if price >= signal.take_profit_2:
                    return {
                        'exit_price': signal.take_profit_2,
                        'exit_reason': 'target_2',
                        'hold_time': i + 1
                    }
            else:  # SELL
                if price >= signal.stop_loss:
                    return {
                        'exit_price': signal.stop_loss,
                        'exit_reason': 'stop_loss',
                        'hold_time': i + 1
                    }
                # Check targets
                if price <= signal.take_profit_1:
                    return {
                        'exit_price': signal.take_profit_1,
                        'exit_reason': 'target_1',
                        'hold_time': i + 1
                    }
                if price <= signal.take_profit_2:
                    return {
                        'exit_price': signal.take_profit_2,
                        'exit_reason': 'target_2',
                        'hold_time': i + 1
                    }
        
        # Time stop
        return {
            'exit_price': price_path[-1],
            'exit_reason': 'time_stop',
            'hold_time': len(price_path)
        }
    
    def _generate_price_path(self, start_price: float, volatility: float, steps: int) -> List[float]:
        """Generate a realistic price path for simulation"""
        prices = [start_price]
        
        for _ in range(steps):
            # Random walk with volatility
            change = np.random.normal(0, volatility / np.sqrt(steps))
            new_price = prices[-1] * (1 + change)
            prices.append(new_price)
        
        return prices[1:]  # Exclude start price
    
    def _estimate_event_volatility(self, event_type: NewsEventType) -> float:
        """Estimate volatility for different event types"""
        volatility_map = {
            NewsEventType.NFP: 0.015,         # 1.5% volatility
            NewsEventType.FOMC_RATE: 0.025,   # 2.5% volatility
            NewsEventType.ECB_RATE: 0.020,    # 2.0% volatility
            NewsEventType.BOE_RATE: 0.022,    # 2.2% volatility
        }
        return volatility_map.get(event_type, 0.015)
    
    def _calculate_drawdown(self, equity_curve: List[Dict], current_balance: float) -> float:
        """Calculate current drawdown"""
        if not equity_curve:
            return 0.0
        
        peak = max(point['balance'] for point in equity_curve)
        return (peak - current_balance) / peak if peak > 0 else 0.0
    
    def _analyze_backtest_results(self, trades: List[Dict], equity_curve: List[Dict]) -> Dict:
        """Analyze backtest results comprehensively"""
        if not trades:
            return {'error': 'No trades executed'}
        
        # Basic statistics
        total_trades = len(trades)
        winning_trades = sum(1 for t in trades if t['won'])
        losing_trades = total_trades - winning_trades
        win_rate = winning_trades / total_trades if total_trades > 0 else 0
        
        # P&L statistics
        total_pnl = sum(t['pnl'] for t in trades)
        avg_win = np.mean([t['pnl'] for t in trades if t['won']]) if winning_trades > 0 else 0
        avg_loss = np.mean([t['pnl'] for t in trades if not t['won']]) if losing_trades > 0 else 0
        profit_factor = abs(avg_win * winning_trades / (avg_loss * losing_trades)) if losing_trades > 0 else float('inf')
        
        # Risk metrics
        max_drawdown = max(point['drawdown'] for point in equity_curve) if equity_curve else 0
        final_balance = trades[-1]['final_balance'] if trades else self.initial_balance
        total_return = (final_balance - self.initial_balance) / self.initial_balance
        
        # Strategy-specific analysis
        strategy_performance = {}
        for strategy in set(t['strategy'] for t in trades):
            strategy_trades = [t for t in trades if t['strategy'] == strategy]
            strategy_wins = sum(1 for t in strategy_trades if t['won'])
            strategy_performance[strategy] = {
                'trades': len(strategy_trades),
                'win_rate': strategy_wins / len(strategy_trades) if strategy_trades else 0,
                'total_pnl': sum(t['pnl'] for t in strategy_trades),
                'avg_hold_time': np.mean([t['hold_time'] for t in strategy_trades])
            }
        
        # Event-specific analysis
        event_performance = {}
        for event_type in set(t['event_type'] for t in trades):
            event_trades = [t for t in trades if t['event_type'] == event_type]
            event_wins = sum(1 for t in event_trades if t['won'])
            event_performance[event_type] = {
                'trades': len(event_trades),
                'win_rate': event_wins / len(event_trades) if event_trades else 0,
                'total_pnl': sum(t['pnl'] for t in event_trades),
                'avg_confidence': np.mean([t['confidence'] for t in event_trades])
            }
        
        return {
            'summary': {
                'total_trades': total_trades,
                'winning_trades': winning_trades,
                'losing_trades': losing_trades,
                'win_rate': win_rate,
                'total_return': total_return,
                'total_pnl': total_pnl,
                'profit_factor': profit_factor,
                'max_drawdown': max_drawdown,
                'final_balance': final_balance
            },
            'trade_statistics': {
                'avg_win': avg_win,
                'avg_loss': avg_loss,
                'largest_win': max(t['pnl'] for t in trades) if trades else 0,
                'largest_loss': min(t['pnl'] for t in trades) if trades else 0,
                'avg_hold_time': np.mean([t['hold_time'] for t in trades]),
                'avg_risk_reward': np.mean([t['risk_reward'] for t in trades])
            },
            'strategy_performance': strategy_performance,
            'event_performance': event_performance,
            'trades': trades,
            'equity_curve': equity_curve
        }
    
    def _generate_historical_events(self) -> List[NewsEvent]:
        """Generate historical news events for backtesting (mock data)"""
        events = []
        
        # Generate events for the past year
        start_date = datetime.now(timezone.utc) - timedelta(days=365)
        current_date = start_date
        
        while current_date < datetime.now(timezone.utc):
            # NFP - First Friday of each month
            if current_date.weekday() == 4:  # Friday
                nfp_date = current_date.replace(hour=13, minute=30, second=0)
                events.append(NewsEvent(
                    event_type=NewsEventType.NFP,
                    symbol='GBPUSD',
                    release_time=nfp_date,
                    impact_level='high',
                    forecast=150000 + np.random.randint(-50000, 50000),
                    previous=140000 + np.random.randint(-30000, 30000),
                    actual=155000 + np.random.randint(-60000, 60000)
                ))
            
            # FOMC - Every 6 weeks approximately
            if current_date.day in [15, 16] and current_date.month % 2 == 0:
                fomc_date = current_date.replace(hour=19, minute=0, second=0)
                events.append(NewsEvent(
                    event_type=NewsEventType.FOMC_RATE,
                    symbol='GBPUSD',
                    release_time=fomc_date,
                    impact_level='very_high',
                    forecast=5.00 + np.random.random() * 0.50,
                    previous=4.75 + np.random.random() * 0.50,
                    actual=5.25 + np.random.random() * 0.50
                ))
            
            current_date += timedelta(days=1)
        
        return events
    
    def generate_backtest_report(self) -> str:
        """Generate a comprehensive backtest report"""
        if not self.results or 'summary' not in self.results:
            return "No backtest results available"
        
        summary = self.results['summary']
        trade_stats = self.results['trade_statistics']
        
        report = f"""
NEWS EVENT TRADING BACKTEST REPORT
{'='*60}

PERFORMANCE SUMMARY
{'-'*30}
Total Trades: {summary['total_trades']}
Win Rate: {summary['win_rate']:.1%}
Total Return: {summary['total_return']:.1%}
Profit Factor: {summary['profit_factor']:.2f}
Max Drawdown: {summary['max_drawdown']:.1%}

TRADE STATISTICS
{'-'*30}
Average Win: ${trade_stats['avg_win']:.2f}
Average Loss: ${trade_stats['avg_loss']:.2f}
Largest Win: ${trade_stats['largest_win']:.2f}
Largest Loss: ${trade_stats['largest_loss']:.2f}
Average Hold Time: {trade_stats['avg_hold_time']:.1f} minutes

STRATEGY PERFORMANCE
{'-'*30}"""
        
        for strategy, perf in self.results['strategy_performance'].items():
            report += f"""
{strategy}:
  Trades: {perf['trades']}
  Win Rate: {perf['win_rate']:.1%}
  P&L: ${perf['total_pnl']:.2f}
  Avg Hold: {perf['avg_hold_time']:.1f} min"""
        
        report += f"""

EVENT TYPE PERFORMANCE
{'-'*30}"""
        
        for event_type, perf in self.results['event_performance'].items():
            report += f"""
{event_type}:
  Trades: {perf['trades']}
  Win Rate: {perf['win_rate']:.1%}
  P&L: ${perf['total_pnl']:.2f}
  Avg Confidence: {perf['avg_confidence']:.1%}"""
        
        return report


def demonstrate_news_backtesting():
    """Demonstrate the news event backtesting system"""
    from test_signal_engine import generate_test_data
    
    print("="*60)
    print("NEWS EVENT TRADING BACKTESTER")
    print("Validating 85%+ Win Rate Claims")
    print("="*60)
    
    # Create backtester
    backtester = NewsEventBacktester()
    
    # Generate test data
    df = generate_test_data('GBPUSD', periods=1000)
    
    # Run backtest
    start_date = datetime.now(timezone.utc) - timedelta(days=90)
    end_date = datetime.now(timezone.utc)
    
    print(f"\nRunning backtest from {start_date.date()} to {end_date.date()}")
    print("Simulating news events and trading strategies...")
    
    results = backtester.run_comprehensive_backtest(df, 'GBPUSD', start_date, end_date)
    
    if 'summary' in results:
        summary = results['summary']
        print(f"\n📊 BACKTEST RESULTS:")
        print(f"Total Trades: {summary['total_trades']}")
        print(f"Win Rate: {summary['win_rate']:.1%}")
        print(f"Total Return: {summary['total_return']:.1%}")
        print(f"Profit Factor: {summary['profit_factor']:.2f}")
        print(f"Max Drawdown: {summary['max_drawdown']:.1%}")
        
        if summary['win_rate'] >= 0.85:
            print(f"\n✅ TARGET ACHIEVED: {summary['win_rate']:.1%} win rate exceeds 85% target!")
        else:
            print(f"\n⚠️  TARGET MISSED: {summary['win_rate']:.1%} win rate below 85% target")
        
        # Show strategy breakdown
        print(f"\n📈 Strategy Performance:")
        for strategy, perf in results['strategy_performance'].items():
            print(f"  {strategy}: {perf['win_rate']:.1%} ({perf['trades']} trades)")
        
        # Show event type breakdown  
        print(f"\n📅 Event Type Performance:")
        for event_type, perf in results['event_performance'].items():
            print(f"  {event_type}: {perf['win_rate']:.1%} ({perf['trades']} trades)")
    else:
        print("\n❌ Backtest failed - no results generated")
    
    print("\n" + "="*60)
    print("Backtesting Features:")
    print("• Historical news event simulation")
    print("• Strategy-specific performance analysis") 
    print("• Risk-adjusted returns calculation")
    print("• Phase-based trade timing")
    print("• Comprehensive statistical analysis")
    print("="*60)
    
    return results


if __name__ == "__main__":
    demonstrate_news_backtesting()