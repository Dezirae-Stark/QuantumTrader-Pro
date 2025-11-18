#!/usr/bin/env python3
"""
MT4 Bridge API Server
Serves JSON endpoints for QuantumTrader Pro to poll
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import csv
from datetime import datetime
import os

app = Flask(__name__)
# Allow all domains for CORS
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

# Sample data storage
signals_data = []
trades_data = []
predictions_data = {}
market_data = {}  # Store real-time market data from EA
account_data = {}

def load_predictions_from_csv(filepath='predictions/predictions.csv'):
    """Load predictions from CSV file"""
    global signals_data
    signals_data = []

    try:
        with open(filepath, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                signals_data.append({
                    'symbol': row['symbol'],
                    'trend': row['trend'],
                    'probability': float(row['probability']),
                    'action': row['action'],
                    'timestamp': row['timestamp'],
                    'ml_prediction': {
                        'entry_probability': float(row['entry_prob']),
                        'exit_probability': float(row['exit_prob']),
                        'confidence_score': float(row['confidence']),
                        'predicted_window': int(row['predicted_window'])
                    }
                })
    except FileNotFoundError:
        print(f"CSV file not found: {filepath}")

def load_predictions_from_json(filepath='predictions/signal_output.json'):
    """Load predictions from JSON file"""
    global signals_data, predictions_data

    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
            signals_data = data.get('signals', [])
            predictions_data = data
    except FileNotFoundError:
        print(f"JSON file not found: {filepath}")
    except json.JSONDecodeError:
        print(f"Invalid JSON in file: {filepath}")

def load_trades_from_json(filepath='predictions/trades.json'):
    """Load active trades from JSON file"""
    global trades_data

    try:
        with open(filepath, 'r') as f:
            trades_data = json.load(f)
    except FileNotFoundError:
        print(f"Trades file not found: {filepath}")
        trades_data = []
    except json.JSONDecodeError:
        print(f"Invalid JSON in trades file: {filepath}")
        trades_data = []

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'timestamp': datetime.utcnow().isoformat()})

@app.route('/api/signals', methods=['GET'])
def get_signals():
    """Get trading signals"""
    return jsonify(signals_data)

@app.route('/api/trades', methods=['GET'])
def get_trades():
    """Get open trades"""
    # Reload trades data to get latest updates
    if os.path.exists('predictions/trades.json'):
        load_trades_from_json()

    # Return real trades data or empty list if none available
    if trades_data:
        return jsonify(trades_data)

    # Return empty list with message if no trades
    return jsonify({
        'trades': [],
        'message': 'No active trades',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/predictions', methods=['GET'])
def get_predictions():
    """Get ML predictions"""
    # Reload predictions to get latest updates
    if os.path.exists('predictions/signal_output.json'):
        load_predictions_from_json()
    elif os.path.exists('predictions/predictions.csv'):
        load_predictions_from_csv()

    # Return predictions or empty response with message
    if predictions_data:
        return jsonify(predictions_data)

    # Return empty response if no predictions available
    return jsonify({
        'predictions': [],
        'signals': [],
        'message': 'No predictions available',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/market', methods=['POST'])
def receive_market_data():
    """Receive real-time market data from EA"""
    global market_data

    data = request.json
    if not data or 'symbol' not in data:
        return jsonify({'error': 'Missing symbol'}), 400

    symbol = data['symbol']

    # Store market data
    if symbol not in market_data:
        market_data[symbol] = []

    # Keep last 500 candles per symbol
    market_data[symbol].append({
        'symbol': symbol,
        'bid': data.get('bid', 0),
        'ask': data.get('ask', 0),
        'spread': data.get('spread', 0),
        'timestamp': data.get('timestamp', int(datetime.utcnow().timestamp()))
    })

    # Limit history to 500 candles
    if len(market_data[symbol]) > 500:
        market_data[symbol] = market_data[symbol][-500:]

    # Save to file for ML predictor
    os.makedirs('bridge/data', exist_ok=True)
    with open(f'bridge/data/{symbol}_market.json', 'w') as f:
        json.dump(market_data[symbol], f, indent=2)

    return jsonify({'status': 'ok', 'symbol': symbol, 'datapoints': len(market_data[symbol])}), 200

@app.route('/api/account', methods=['POST'])
def receive_account_data():
    """Receive account data from EA"""
    global account_data

    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    account_data = data
    account_data['last_update'] = datetime.utcnow().isoformat()

    # Save to file
    os.makedirs('bridge/data', exist_ok=True)
    with open('bridge/data/account.json', 'w') as f:
        json.dump(account_data, f, indent=2)

    return jsonify({'status': 'ok'}), 200

@app.route('/api/positions', methods=['POST'])
def receive_positions():
    """Receive open positions from EA"""
    global trades_data

    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    trades_data = data.get('positions', [])

    # Save to file
    os.makedirs('predictions', exist_ok=True)
    with open('predictions/trades.json', 'w') as f:
        json.dump(trades_data, f, indent=2)

    return jsonify({'status': 'ok', 'positions': len(trades_data)}), 200

@app.route('/api/order', methods=['POST'])
def create_order():
    """Create a new trading order"""
    order_data = request.json

    # Validate order data
    required_fields = ['symbol', 'type', 'volume']
    if not all(field in order_data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400

    # In production, send order to MT4 via MQL4 script
    response = {
        'status': 'success',
        'order_id': f"ORD{datetime.utcnow().timestamp()}",
        'symbol': order_data['symbol'],
        'type': order_data['type'],
        'volume': order_data['volume'],
        'timestamp': datetime.utcnow().isoformat()
    }

    return jsonify(response), 201

@app.route('/api/close/<position_id>', methods=['POST'])
def close_position(position_id):
    """Close an open position"""
    # In production, close position via MT4
    response = {
        'status': 'success',
        'position_id': position_id,
        'closed_at': datetime.utcnow().isoformat()
    }

    return jsonify(response)

if __name__ == '__main__':
    # Create predictions directory if it doesn't exist
    os.makedirs('predictions', exist_ok=True)

    # Load initial data
    print("📂 Loading initial data...")
    if os.path.exists('predictions/signal_output.json'):
        load_predictions_from_json()
        print("   ✓ Loaded predictions from JSON")
    elif os.path.exists('predictions/predictions.csv'):
        load_predictions_from_csv()
        print("   ✓ Loaded predictions from CSV")
    else:
        print("   ⚠ No prediction files found")

    if os.path.exists('predictions/trades.json'):
        load_trades_from_json()
        print(f"   ✓ Loaded {len(trades_data)} active trades")
    else:
        print("   ⚠ No trades file found")

    print("\n🚀 MT4 Bridge API Server Starting...")
    print("📡 Serving on http://localhost:8080")
    print("🔗 Endpoints:")
    print("   GET  /api/health       - Health check")
    print("   GET  /api/signals      - Trading signals")
    print("   GET  /api/trades       - Open trades")
    print("   GET  /api/predictions  - ML predictions")
    print("   POST /api/market       - Receive market data from EA")
    print("   POST /api/account      - Receive account data from EA")
    print("   POST /api/positions    - Receive open positions from EA")
    print("   POST /api/order        - Create order")
    print("   POST /api/close/<id>   - Close position")

    app.run(host='0.0.0.0', port=8080, debug=True)
