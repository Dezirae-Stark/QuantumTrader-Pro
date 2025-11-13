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
CORS(app)

# Sample data storage
signals_data = []
trades_data = []
predictions_data = {}

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
    # Sample open trades
    sample_trades = [
        {
            'symbol': 'EURUSD',
            'type': 'buy',
            'entry_price': 1.0850,
            'current_price': 1.0875,
            'volume': 0.5,
            'profit_loss': 125.00,
            'open_time': '2025-11-07T18:30:00Z',
            'predicted_window': 5
        },
        {
            'symbol': 'GBPUSD',
            'type': 'sell',
            'entry_price': 1.2720,
            'current_price': 1.2695,
            'volume': 0.3,
            'profit_loss': 75.00,
            'open_time': '2025-11-07T19:15:00Z',
            'predicted_window': 6
        }
    ]
    return jsonify(sample_trades)

@app.route('/api/predictions', methods=['GET'])
def get_predictions():
    """Get ML predictions"""
    return jsonify(predictions_data)

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
    # Load initial data
    if os.path.exists('predictions/signal_output.json'):
        load_predictions_from_json()
    elif os.path.exists('predictions/predictions.csv'):
        load_predictions_from_csv()

    # Determine debug mode from environment
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() in ('true', '1', 'yes')

    # Security warning for production
    if debug_mode:
        print("⚠️  WARNING: Debug mode is ENABLED!")
        print("⚠️  This exposes stack traces and allows code execution!")
        print("⚠️  NEVER run with debug=True in production!")
        print("⚠️  Set FLASK_DEBUG=False or use a production WSGI server (gunicorn/uwsgi)")
        print()

    print("🚀 MT4 Bridge API Server Starting...")
    print("📡 Serving on http://localhost:8080")
    print("🔧 Debug mode:", "ENABLED (⚠️ INSECURE)" if debug_mode else "DISABLED")
    print("🔗 Endpoints:")
    print("   GET  /api/health       - Health check")
    print("   GET  /api/signals      - Trading signals")
    print("   GET  /api/trades       - Open trades")
    print("   GET  /api/predictions  - ML predictions")
    print("   POST /api/order        - Create order")
    print("   POST /api/close/<id>   - Close position")
    print()
    print("📝 PRODUCTION DEPLOYMENT:")
    print("   For production, use: gunicorn -w 4 -b 0.0.0.0:8080 mt4_bridge:app")
    print("   Never use Flask dev server (app.run) in production!")
    print()

    app.run(host='0.0.0.0', port=8080, debug=debug_mode)
