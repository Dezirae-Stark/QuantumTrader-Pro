#!/usr/bin/env python3
"""
MT5 Connector - Real-time data feed from MetaTrader 5
Based on: https://medium.com/@eduardo-bogosian/how-to-pull-data-from-metatrader-5-with-python-4889bd92f62d
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, timezone
import logging
from typing import Dict, List, Optional, Tuple
import json
import time
import os

logger = logging.getLogger(__name__)

class MT5Connector:
    def __init__(self):
        self.connected = False
        self.account_info = None
        
    def connect(self, login: int, password: str, server: str) -> bool:
        """Connect to MT5 terminal"""
        try:
            # Initialize MT5 connection
            if not mt5.initialize():
                logger.error(f"MT5 initialize failed: {mt5.last_error()}")
                return False
            
            # Login to account
            authorized = mt5.login(login=login, password=password, server=server)
            if authorized:
                self.connected = True
                self.account_info = mt5.account_info()._asdict()
                logger.info(f"Connected to MT5: {server}, Account: {login}")
                return True
            else:
                logger.error(f"Failed to connect: {mt5.last_error()}")
                return False
                
        except Exception as e:
            logger.error(f"Connection error: {str(e)}")
            return False
    
    def disconnect(self):
        """Disconnect from MT5"""
        if self.connected:
            mt5.shutdown()
            self.connected = False
            logger.info("Disconnected from MT5")
    
    def get_market_data(self, symbols: List[str]) -> Dict:
        """Get real-time market data for symbols"""
        if not self.connected:
            return {}
            
        market_data = {}
        
        for symbol in symbols:
            try:
                # Get symbol info
                symbol_info = mt5.symbol_info(symbol)
                if symbol_info is None:
                    logger.warning(f"Symbol {symbol} not found")
                    continue
                
                # Get current tick
                tick = mt5.symbol_info_tick(symbol)
                if tick is None:
                    continue
                    
                # Calculate change
                # Get daily candle for change calculation
                rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_D1, 0, 2)
                change = 0
                change_percent = 0
                
                if rates is not None and len(rates) >= 2:
                    yesterday_close = rates[-2]['close']
                    change = tick.bid - yesterday_close
                    change_percent = (change / yesterday_close) * 100
                
                market_data[symbol] = {
                    'symbol': symbol,
                    'price': tick.bid,
                    'ask': tick.ask,
                    'bid': tick.bid,
                    'spread': round((tick.ask - tick.bid) / symbol_info.point, 1),
                    'change': round(change, symbol_info.digits),
                    'changePercent': round(change_percent, 2),
                    'volume': tick.volume,
                    'timestamp': datetime.fromtimestamp(tick.time, tz=timezone.utc).isoformat()
                }
                
            except Exception as e:
                logger.error(f"Error getting data for {symbol}: {str(e)}")
                
        return market_data
    
    def get_account_info(self) -> Dict:
        """Get account information"""
        if not self.connected:
            return {}
            
        try:
            account = mt5.account_info()
            if account is None:
                return {}
                
            return {
                'balance': account.balance,
                'equity': account.equity,
                'margin': account.margin,
                'free_margin': account.margin_free,
                'margin_level': account.margin_level,
                'profit': account.profit,
                'currency': account.currency,
                'leverage': account.leverage,
                'trade_allowed': account.trade_allowed
            }
        except Exception as e:
            logger.error(f"Error getting account info: {str(e)}")
            return {}
    
    def get_open_positions(self) -> List[Dict]:
        """Get all open positions"""
        if not self.connected:
            return []
            
        try:
            positions = mt5.positions_get()
            if positions is None:
                return []
                
            position_list = []
            for pos in positions:
                position_list.append({
                    'ticket': pos.ticket,
                    'symbol': pos.symbol,
                    'type': 'buy' if pos.type == mt5.ORDER_TYPE_BUY else 'sell',
                    'volume': pos.volume,
                    'entry_price': pos.price_open,
                    'current_price': pos.price_current,
                    'swap': pos.swap,
                    'profit': pos.profit,
                    'open_time': datetime.fromtimestamp(pos.time, tz=timezone.utc).isoformat(),
                    'sl': pos.sl,
                    'tp': pos.tp,
                    'magic': pos.magic,
                    'comment': pos.comment
                })
                
            return position_list
            
        except Exception as e:
            logger.error(f"Error getting positions: {str(e)}")
            return []
    
    def place_order(self, symbol: str, order_type: str, volume: float, 
                   sl: Optional[float] = None, tp: Optional[float] = None,
                   deviation: int = 20) -> bool:
        """Place a market order"""
        if not self.connected:
            return False
            
        try:
            # Get symbol info
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                logger.error(f"Symbol {symbol} not found")
                return False
            
            # Prepare request
            point = symbol_info.point
            if order_type.lower() == 'buy':
                trade_type = mt5.ORDER_TYPE_BUY
                price = mt5.symbol_info_tick(symbol).ask
            else:
                trade_type = mt5.ORDER_TYPE_SELL
                price = mt5.symbol_info_tick(symbol).bid
                
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": volume,
                "type": trade_type,
                "price": price,
                "deviation": deviation,
                "magic": 234000,
                "comment": "QuantumTrader Pro",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            # Add SL/TP if provided
            if sl is not None:
                request["sl"] = sl
            if tp is not None:
                request["tp"] = tp
                
            # Send order
            result = mt5.order_send(request)
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Order failed: {result.comment}")
                return False
                
            logger.info(f"Order placed: {result.order}")
            return True
            
        except Exception as e:
            logger.error(f"Error placing order: {str(e)}")
            return False
    
    def close_position(self, ticket: int) -> bool:
        """Close a specific position"""
        if not self.connected:
            return False
            
        try:
            position = mt5.positions_get(ticket=ticket)
            if position is None or len(position) == 0:
                logger.error(f"Position {ticket} not found")
                return False
                
            pos = position[0]
            
            # Prepare close request
            if pos.type == mt5.ORDER_TYPE_BUY:
                trade_type = mt5.ORDER_TYPE_SELL
                price = mt5.symbol_info_tick(pos.symbol).bid
            else:
                trade_type = mt5.ORDER_TYPE_BUY
                price = mt5.symbol_info_tick(pos.symbol).ask
                
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": pos.symbol,
                "volume": pos.volume,
                "type": trade_type,
                "position": ticket,
                "price": price,
                "deviation": 20,
                "magic": 234000,
                "comment": "Position closed by QuantumTrader",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            result = mt5.order_send(request)
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Failed to close position: {result.comment}")
                return False
                
            logger.info(f"Position {ticket} closed")
            return True
            
        except Exception as e:
            logger.error(f"Error closing position: {str(e)}")
            return False
    
    def get_historical_data(self, symbol: str, timeframe: int, count: int) -> pd.DataFrame:
        """Get historical OHLCV data"""
        if not self.connected:
            return pd.DataFrame()
            
        try:
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, count)
            if rates is None:
                return pd.DataFrame()
                
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            return df
            
        except Exception as e:
            logger.error(f"Error getting historical data: {str(e)}")
            return pd.DataFrame()


# Example usage for testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Initialize connector
    connector = MT5Connector()
    
    # Connect to demo account - credentials from environment
    # Set these environment variables:
    # MT5_LOGIN=your_account_number
    # MT5_PASSWORD=your_password
    # MT5_SERVER=YourBroker-Demo
    LOGIN = int(os.environ.get('MT5_LOGIN', '0'))
    PASSWORD = os.environ.get('MT5_PASSWORD', '')
    SERVER = os.environ.get('MT5_SERVER', 'Demo-Server')
    
    if connector.connect(LOGIN, PASSWORD, SERVER):
        # Get market data
        symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD']
        market_data = connector.get_market_data(symbols)
        print("Market Data:", json.dumps(market_data, indent=2))
        
        # Get account info
        account_info = connector.get_account_info()
        print("Account Info:", json.dumps(account_info, indent=2))
        
        # Get open positions
        positions = connector.get_open_positions()
        print("Open Positions:", json.dumps(positions, indent=2))
        
        # Disconnect
        connector.disconnect()