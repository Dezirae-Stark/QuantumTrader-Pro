#!/usr/bin/env python3
"""
Unified MT4/MT5 Bridge API Server
Supports real-time data from both MetaTrader 4 and MetaTrader 5
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os
import logging
from datetime import datetime
from typing import Dict, Optional
import threading
import time

# Import MT5 connector if available
try:
    from mt5_connector import MT5Connector
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False
    print("MT5 connector not available. Install MetaTrader5 package.")

app = Flask(__name__)
CORS(app, resources={
    r"/api/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
        "expose_headers": ["Content-Type"],
        "supports_credentials": False,
        "max_age": 3600
    }
})

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global state
mt5_connector = None if not MT5_AVAILABLE else MT5Connector()
market_data_cache = {}
account_info_cache = {}
positions_cache = []
signals_cache = []

# Configuration
UPDATE_INTERVAL = 1  # seconds
WATCHED_SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD', 'BTCUSD', 'ETHUSD']

def update_market_data():
    """Background task to update market data"""
    while True:
        try:
            if mt5_connector and mt5_connector.connected:
                # Get real-time data from MT5
                data = mt5_connector.get_market_data(WATCHED_SYMBOLS)
                market_data_cache.update(data)
                
                # Update account info
                account_info = mt5_connector.get_account_info()
                if account_info:
                    account_info_cache.update(account_info)
                
                # Update positions
                positions = mt5_connector.get_open_positions()
                positions_cache.clear()
                positions_cache.extend(positions)
                
        except Exception as e:
            logger.error(f"Error updating market data: {str(e)}")
        
        time.sleep(UPDATE_INTERVAL)

# Start background update thread
update_thread = threading.Thread(target=update_market_data, daemon=True)
update_thread.start()

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    status = {
        'status': 'ok',
        'timestamp': datetime.utcnow().isoformat(),
        'mt5_available': MT5_AVAILABLE,
        'mt5_connected': mt5_connector.connected if mt5_connector else False
    }
    return jsonify(status)

@app.route('/api/connect', methods=['POST'])
def connect_broker():
    """Connect to MT4/MT5 broker"""
    if not MT5_AVAILABLE:
        return jsonify({'error': 'MT5 not available'}), 503
    
    data = request.json
    if not data:
        return jsonify({'error': 'Missing connection parameters'}), 400
    
    login = data.get('login')
    password = data.get('password')
    server = data.get('server')
    broker_type = data.get('broker_type', 'mt5')
    
    if not all([login, password, server]):
        return jsonify({'error': 'Missing login, password or server'}), 400
    
    try:
        if broker_type.lower() == 'mt5' and mt5_connector:
            success = mt5_connector.connect(int(login), password, server)
            if success:
                return jsonify({
                    'success': True,
                    'message': 'Connected to MT5',
                    'account_info': mt5_connector.account_info
                })
            else:
                return jsonify({'success': False, 'error': 'Failed to connect'}), 401
        else:
            return jsonify({'error': 'Only MT5 is currently supported'}), 400
            
    except Exception as e:
        logger.error(f"Connection error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/disconnect', methods=['POST'])
def disconnect_broker():
    """Disconnect from broker"""
    if mt5_connector:
        mt5_connector.disconnect()
    return jsonify({'success': True, 'message': 'Disconnected'})

@app.route('/api/market_data', methods=['GET'])
def get_market_data():
    """Get real-time market data"""
    if not market_data_cache:
        # Return empty data with proper structure
        empty_data = {}
        for symbol in WATCHED_SYMBOLS:
            empty_data[symbol] = {
                'symbol': symbol,
                'price': 0.0,
                'bid': 0.0,
                'ask': 0.0,
                'spread': 0.0,
                'change': 0.0,
                'changePercent': 0.0,
                'volume': 0,
                'timestamp': datetime.utcnow().isoformat()
            }
        return jsonify(empty_data)
    
    return jsonify(market_data_cache)

@app.route('/api/account', methods=['GET'])
def get_account_info():
    """Get account information"""
    if not account_info_cache:
        return jsonify({
            'balance': 0.0,
            'equity': 0.0,
            'margin': 0.0,
            'free_margin': 0.0,
            'margin_level': 0.0,
            'profit': 0.0,
            'currency': 'USD',
            'leverage': 100,
            'trade_allowed': False
        })
    
    return jsonify(account_info_cache)

@app.route('/api/trades', methods=['GET'])
def get_trades():
    """Get open positions"""
    return jsonify(positions_cache)

@app.route('/api/order', methods=['POST'])
def place_order():
    """Place a new order"""
    if not mt5_connector or not mt5_connector.connected:
        return jsonify({'error': 'Not connected to broker'}), 503
    
    data = request.json
    if not data:
        return jsonify({'error': 'Missing order parameters'}), 400
    
    try:
        success = mt5_connector.place_order(
            symbol=data.get('symbol'),
            order_type=data.get('type'),
            volume=float(data.get('volume', 0.01)),
            sl=data.get('stop_loss'),
            tp=data.get('take_profit')
        )
        
        if success:
            return jsonify({'success': True, 'message': 'Order placed'})
        else:
            return jsonify({'success': False, 'error': 'Order failed'}), 400
            
    except Exception as e:
        logger.error(f"Order error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/close/<int:position_id>', methods=['POST'])
def close_position(position_id):
    """Close a specific position"""
    if not mt5_connector or not mt5_connector.connected:
        return jsonify({'error': 'Not connected to broker'}), 503
    
    try:
        success = mt5_connector.close_position(position_id)
        if success:
            return jsonify({'success': True, 'message': 'Position closed'})
        else:
            return jsonify({'success': False, 'error': 'Failed to close position'}), 400
            
    except Exception as e:
        logger.error(f"Close position error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/signals', methods=['GET'])
def get_signals():
    """Get trading signals (legacy support)"""
    # For now, return cached signals or empty list
    return jsonify(signals_cache)

@app.route('/api/predictions', methods=['GET'])
def get_predictions():
    """Get ML predictions (legacy support)"""
    # This would integrate with your ML service
    return jsonify({
        'predictions': [],
        'message': 'ML predictions would come from ML service',
        'timestamp': datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)