#!/usr/bin/env python3
"""
QuantumTrader Pro - MT4/MT5 Backtesting Engine
Broker-agnostic backtesting engine supporting any MT4/MT5 broker

Configuration via environment variables (.env file)
"""

import sys
import os
import json
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from dotenv import load_dotenv

try:
    import MetaTrader5 as MT5
except ImportError:
    print("ERROR: MetaTrader5 module not installed")
    print("Install with: pip install MetaTrader5")
    sys.exit(1)

# Load environment variables from .env file
load_dotenv()

class MTBacktester:
    """
    Broker-agnostic MT4/MT5 backtesting engine.

    Connects to any MT4/MT5 broker using credentials from .env file.
    """

    def __init__(self):
        """Initialize backtester with configuration from environment variables."""
        # Broker credentials from .env
        self.login = self._get_env_int('MT_LOGIN')
        self.password = self._get_env('MT_PASSWORD')
        self.server = self._get_env('MT_SERVER')
        self.platform = self._get_env('MT_PLATFORM', 'MT5')

        # Backtest parameters
        self.symbol = self._get_env('BACKTEST_SYMBOL', 'EURUSD')
        self.timeframe_name = self._get_env('BACKTEST_TIMEFRAME', 'H1')
        self.timeframe = self._parse_timeframe(self.timeframe_name)
        self.bars = self._get_env_int('BACKTEST_BARS', 2000)

        # Risk management
        self.risk_percent = self._get_env_float('RISK_PER_TRADE', 0.02)
        self.initial_balance = self._get_env_float('INITIAL_BALANCE', 10000.0)
        self.max_daily_risk = self._get_env_float('MAX_DAILY_RISK', 0.05)

        # Technical indicators
        self.rsi_period = self._get_env_int('RSI_PERIOD', 14)
        self.sma_fast = self._get_env_int('SMA_FAST', 20)
        self.sma_slow = self._get_env_int('SMA_SLOW', 50)
        self.bb_period = self._get_env_int('BB_PERIOD', 20)
        self.bb_deviation = self._get_env_float('BB_DEVIATION', 2.0)

        # Output configuration
        self.results_file = self._get_env('RESULTS_FILE', 'backtest_results')
        self.generate_html = self._get_env('GENERATE_HTML_REPORT', 'true').lower() == 'true'

        # State
        self.connected = False
        self.results = {
            "broker": "BROKER_AGNOSTIC",
            "symbol": self.symbol,
            "timeframe": self.timeframe_name,
            "total_trades": 0,
            "winning_trades": 0,
            "losing_trades": 0,
            "gross_profit": 0.0,
            "gross_loss": 0.0,
            "net_profit": 0.0,
            "win_rate": 0.0,
            "profit_factor": 0.0,
            "max_drawdown": 0.0,
            "sharpe_ratio": 0.0,
            "trades": []
        }

    def _get_env(self, key, default=None):
        """Get environment variable with error handling."""
        value = os.getenv(key, default)
        if value is None:
            raise ValueError(f"Required environment variable '{key}' not set. Check your .env file.")
        return value

    def _get_env_int(self, key, default=None):
        """Get integer environment variable."""
        value = self._get_env(key, str(default) if default is not None else None)
        try:
            return int(value)
        except ValueError:
            raise ValueError(f"Environment variable '{key}' must be an integer, got: {value}")

    def _get_env_float(self, key, default=None):
        """Get float environment variable."""
        value = self._get_env(key, str(default) if default is not None else None)
        try:
            return float(value)
        except ValueError:
            raise ValueError(f"Environment variable '{key}' must be a number, got: {value}")

    def _parse_timeframe(self, tf_name):
        """Convert timeframe name to MT5 constant."""
        timeframes = {
            'M1': MT5.TIMEFRAME_M1,
            'M5': MT5.TIMEFRAME_M5,
            'M15': MT5.TIMEFRAME_M15,
            'M30': MT5.TIMEFRAME_M30,
            'H1': MT5.TIMEFRAME_H1,
            'H4': MT5.TIMEFRAME_H4,
            'D1': MT5.TIMEFRAME_D1,
            'W1': MT5.TIMEFRAME_W1,
            'MN1': MT5.TIMEFRAME_MN1
        }
        return timeframes.get(tf_name.upper(), MT5.TIMEFRAME_H1)

    def connect(self):
        """Connect to MT4/MT5 broker."""
        print(f"Connecting to {self.platform} server: {self.server}...")
        print(f"Account: {self.login}")

        if not MT5.initialize():
            print(f"MT5 initialize() failed, error code: {MT5.last_error()}")
            return False

        authorized = MT5.login(
            login=self.login,
            password=self.password,
            server=self.server
        )

        if authorized:
            account_info = MT5.account_info()
            print(f"✓ Connected to {account_info.company}")
            print(f"  Balance: ${account_info.balance:.2f}")
            print(f"  Leverage: 1:{account_info.leverage}")
            self.connected = True
            return True
        else:
            print(f"✗ Login failed for account {self.login}")
            print(f"  Error: {MT5.last_error()}")
            MT5.shutdown()
            return False

    def disconnect(self):
        """Disconnect from MT4/MT5."""
        if self.connected:
            MT5.shutdown()
            self.connected = False
            print("Disconnected from broker")

    def fetch_historical_data(self):
        """Fetch historical price data."""
        print(f"Fetching {self.bars} bars of {self.symbol} {self.timeframe_name} data...")

        rates = MT5.copy_rates_from_pos(self.symbol, self.timeframe, 0, self.bars)

        if rates is None or len(rates) == 0:
            print(f"✗ Failed to fetch data for {self.symbol}")
            return None

        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')

        print(f"✓ Fetched {len(df)} bars")
        print(f"  Date range: {df['time'].min()} to {df['time'].max()}")

        return df

    def calculate_indicators(self, df):
        """Calculate technical indicators."""
        print("Calculating technical indicators...")

        # RSI
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=self.rsi_period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=self.rsi_period).mean()
        rs = gain / loss
        df['rsi'] = 100 - (100 / (1 + rs))

        # Moving averages
        df['sma_fast'] = df['close'].rolling(window=self.sma_fast).mean()
        df['sma_slow'] = df['close'].rolling(window=self.sma_slow).mean()

        # Bollinger Bands
        df['bb_middle'] = df['close'].rolling(window=self.bb_period).mean()
        std = df['close'].rolling(window=self.bb_period).std()
        df['bb_upper'] = df['bb_middle'] + (std * self.bb_deviation)
        df['bb_lower'] = df['bb_middle'] - (std * self.bb_deviation)

        return df

    def run_backtest(self):
        """Run complete backtest."""
        print("\n" + "="*60)
        print("QUANTUMTRADER PRO - BROKER-AGNOSTIC BACKTEST")
        print("="*60)
        print(f"Broker Server: {self.server}")
        print(f"Account: {self.login}")
        print(f"Symbol: {self.symbol}")
        print(f"Timeframe: {self.timeframe_name}")
        print(f"Bars: {self.bars}")
        print("="*60 + "\n")

        if not self.connect():
            return False

        df = self.fetch_historical_data()
        if df is None:
            self.disconnect()
            return False

        df = self.calculate_indicators(df)

        print("\nRunning backtest simulation...")
        self._simulate_trades(df)

        self.disconnect()

        self._calculate_metrics()
        self._print_results()
        self._save_results()

        if self.generate_html:
            self._generate_html_report()

        return True

    def _simulate_trades(self, df):
        """Simulate trades based on strategy."""
        balance = self.initial_balance
        equity_curve = []
        in_position = False
        position_type = None
        entry_price = 0
        entry_index = 0

        for i in range(max(self.sma_slow, self.rsi_period), len(df)):
            row = df.iloc[i]

            # Skip if indicators not ready
            if pd.isna(row['rsi']) or pd.isna(row['sma_fast']):
                continue

            # Entry logic
            if not in_position:
                # BUY signal: RSI oversold
                if row['rsi'] < 30:
                    in_position = True
                    position_type = "BUY"
                    entry_price = row['close']
                    entry_index = i

                # SELL signal: RSI overbought
                elif row['rsi'] > 70:
                    in_position = True
                    position_type = "SELL"
                    entry_price = row['close']
                    entry_index = i

            # Exit logic
            else:
                exit_triggered = False
                exit_price = row['close']

                # BUY exit: RSI above 50 or stop loss
                if position_type == "BUY":
                    if row['rsi'] > 50:
                        exit_triggered = True
                    elif (entry_price - exit_price) / entry_price > 0.02:  # 2% stop loss
                        exit_triggered = True

                # SELL exit: RSI below 50 or stop loss
                elif position_type == "SELL":
                    if row['rsi'] < 50:
                        exit_triggered = True
                    elif (exit_price - entry_price) / entry_price > 0.02:  # 2% stop loss
                        exit_triggered = True

                if exit_triggered:
                    # Calculate profit/loss
                    if position_type == "BUY":
                        pnl = (exit_price - entry_price) / entry_price
                    else:  # SELL
                        pnl = (entry_price - exit_price) / entry_price

                    trade_value = balance * self.risk_percent
                    profit = trade_value * pnl
                    balance += profit

                    # Record trade
                    trade = {
                        "entry_time": str(df.iloc[entry_index]['time']),
                        "exit_time": str(row['time']),
                        "type": position_type,
                        "entry_price": float(entry_price),
                        "exit_price": float(exit_price),
                        "pnl": float(profit),
                        "balance": float(balance)
                    }

                    self.results['trades'].append(trade)

                    if profit > 0:
                        self.results['winning_trades'] += 1
                        self.results['gross_profit'] += profit
                    else:
                        self.results['losing_trades'] += 1
                        self.results['gross_loss'] += abs(profit)

                    in_position = False
                    position_type = None

            equity_curve.append(balance)

        self.results['total_trades'] = len(self.results['trades'])
        self.results['equity_curve'] = equity_curve

    def _calculate_metrics(self):
        """Calculate performance metrics."""
        if self.results['total_trades'] > 0:
            self.results['win_rate'] = (self.results['winning_trades'] / self.results['total_trades']) * 100

        if self.results['gross_loss'] > 0:
            self.results['profit_factor'] = self.results['gross_profit'] / self.results['gross_loss']

        self.results['net_profit'] = self.results['gross_profit'] - self.results['gross_loss']

        # Calculate max drawdown
        if hasattr(self, 'equity_curve') and len(self.results.get('equity_curve', [])) > 0:
            equity = self.results['equity_curve']
            peak = equity[0]
            max_dd = 0

            for value in equity:
                if value > peak:
                    peak = value
                drawdown = (peak - value) / peak if peak > 0 else 0
                if drawdown > max_dd:
                    max_dd = drawdown

            self.results['max_drawdown'] = max_dd * 100

        # Calculate Sharpe ratio (simplified)
        if hasattr(self, 'equity_curve') and len(self.results.get('equity_curve', [])) > 0:
            equity = self.results['equity_curve']
            returns = np.diff(equity) / equity[:-1]
            if len(returns) > 0 and np.std(returns) > 0:
                self.results['sharpe_ratio'] = np.mean(returns) / np.std(returns) * np.sqrt(252)

    def _print_results(self):
        """Print backtest results to console."""
        print("\n" + "="*60)
        print("BACKTEST RESULTS")
        print("="*60)
        print(f"Total Trades:      {self.results['total_trades']}")
        print(f"Winning Trades:    {self.results['winning_trades']}")
        print(f"Losing Trades:     {self.results['losing_trades']}")
        print(f"Win Rate:          {self.results['win_rate']:.2f}%")
        print(f"Profit Factor:     {self.results['profit_factor']:.2f}")
        print(f"Net Profit:        ${self.results['net_profit']:.2f} ({(self.results['net_profit']/self.initial_balance)*100:.2f}%)")
        print(f"Max Drawdown:      {self.results['max_drawdown']:.2f}%")
        print(f"Sharpe Ratio:      {self.results['sharpe_ratio']:.2f}")
        print("="*60 + "\n")

    def _save_results(self):
        """Save results to JSON file."""
        filename = f"{self.results_file}.json"
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"✓ Results saved to {filename}")

    def _generate_html_report(self):
        """Generate HTML report."""
        filename = f"{self.results_file}.html"

        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>QuantumTrader Pro - Backtest Results</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
                .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
                .metric {{ display: inline-block; margin: 15px 20px; padding: 20px; background: #ecf0f1; border-radius: 5px; min-width: 200px; }}
                .metric-label {{ font-size: 14px; color: #7f8c8d; }}
                .metric-value {{ font-size: 28px; font-weight: bold; color: #2c3e50; }}
                .positive {{ color: #27ae60; }}
                .negative {{ color: #e74c3c; }}
                .info {{ background: #e8f4f8; padding: 15px; border-left: 4px solid #3498db; margin: 20px 0; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>QuantumTrader Pro - Backtest Results</h1>

                <div class="info">
                    <strong>Broker:</strong> {self.server}<br>
                    <strong>Symbol:</strong> {self.symbol}<br>
                    <strong>Timeframe:</strong> {self.timeframe_name}<br>
                    <strong>Bars Analyzed:</strong> {self.bars}<br>
                    <strong>Initial Balance:</strong> ${self.initial_balance:.2f}
                </div>

                <div class="metric">
                    <div class="metric-label">Total Trades</div>
                    <div class="metric-value">{self.results['total_trades']}</div>
                </div>

                <div class="metric">
                    <div class="metric-label">Win Rate</div>
                    <div class="metric-value {'positive' if self.results['win_rate'] > 50 else 'negative'}">{self.results['win_rate']:.2f}%</div>
                </div>

                <div class="metric">
                    <div class="metric-label">Profit Factor</div>
                    <div class="metric-value {'positive' if self.results['profit_factor'] > 1 else 'negative'}">{self.results['profit_factor']:.2f}</div>
                </div>

                <div class="metric">
                    <div class="metric-label">Net Profit</div>
                    <div class="metric-value {'positive' if self.results['net_profit'] > 0 else 'negative'}">${self.results['net_profit']:.2f}</div>
                </div>

                <div class="metric">
                    <div class="metric-label">Max Drawdown</div>
                    <div class="metric-value {'positive' if self.results['max_drawdown'] < 10 else 'negative'}">{self.results['max_drawdown']:.2f}%</div>
                </div>

                <div class="metric">
                    <div class="metric-label">Sharpe Ratio</div>
                    <div class="metric-value {'positive' if self.results['sharpe_ratio'] > 1 else 'negative'}">{self.results['sharpe_ratio']:.2f}</div>
                </div>
            </div>
        </body>
        </html>
        """

        with open(filename, 'w') as f:
            f.write(html)

        print(f"✓ HTML report saved to {filename}")

if __name__ == "__main__":
    # Check for .env file
    if not os.path.exists('.env'):
        print("ERROR: .env file not found!")
        print("\n1. Copy .env.example to .env:")
        print("   cp .env.example .env")
        print("\n2. Edit .env and configure your broker credentials")
        print("\n3. Run again: python3 mt_backtest.py")
        sys.exit(1)

    try:
        backtester = MTBacktester()
        success = backtester.run_backtest()

        if success:
            print("\n✓ Backtest completed successfully!")
            sys.exit(0)
        else:
            print("\n✗ Backtest failed")
            sys.exit(1)

    except ValueError as e:
        print(f"\nConfiguration Error: {e}")
        print("Check your .env file configuration")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nBacktest interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\nUnexpected Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
