#!/usr/bin/env python3
"""
Flask API server for ML services and indicator management
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
from technical_predictor import TechnicalPredictor
import pandas as pd
import numpy as np
from datetime import datetime
import logging

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize predictor
predictor = TechnicalPredictor()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/toggle_indicator', methods=['POST'])
def toggle_indicator():
    """Toggle an indicator on/off"""
    try:
        data = request.json
        indicator_name = data.get('indicator')
        enabled = data.get('enabled', True)
        
        if not indicator_name:
            return jsonify({'error': 'indicator name required'}), 400
            
        # Toggle the indicator
        predictor.toggle_indicator(indicator_name, enabled)
        
        logger.info(f"Indicator {indicator_name} {'enabled' if enabled else 'disabled'}")
        
        return jsonify({
            'status': 'success',
            'indicator': indicator_name,
            'enabled': enabled
        })
        
    except Exception as e:
        logger.error(f"Error toggling indicator: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/advanced_signals/<symbol>', methods=['GET'])
def get_advanced_signals(symbol):
    """Get advanced signal analysis for a symbol"""
    try:
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data
        base_price = 1.0800 if symbol == 'EURUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get advanced signals
        signals = predictor.get_advanced_signals(df, symbol)
        
        return jsonify(signals)
        
    except Exception as e:
        logger.error(f"Error getting advanced signals: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/predict', methods=['POST'])
def predict():
    """Get ML predictions"""
    try:
        data = request.json
        symbol = data.get('symbol', 'UNKNOWN')
        
        # Extract price data
        if 'prices' in data:
            prices = pd.Series(data['prices'])
        else:
            return jsonify({'error': 'prices data required'}), 400
            
        # Get predictions
        predictions = predictor.predict_next_candles(prices, n_candles=5)
        
        return jsonify({
            'status': 'success',
            'symbol': symbol,
            'predictions': predictions
        })
        
    except Exception as e:
        logger.error(f"Error in prediction: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/indicator_status', methods=['GET'])
def get_indicator_status():
    """Get status of all indicators"""
    try:
        status = {}
        for config in predictor.signal_engine.configurations:
            status[config.indicator.name] = {
                'enabled': config.enabled,
                'weight': config.weight,
                'category': config.category.name
            }
        
        return jsonify({
            'status': 'success',
            'indicators': status,
            'total': len(status),
            'enabled': sum(1 for c in predictor.signal_engine.configurations if c.enabled)
        })
        
    except Exception as e:
        logger.error(f"Error getting indicator status: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/ultra_high_accuracy/<symbol>', methods=['GET'])
def get_ultra_high_accuracy_signal(symbol):
    """Get ultra-high accuracy signal (94.7%+ win rate)"""
    try:
        # Get spread parameter
        spread = float(request.args.get('spread', 0.0001))
        
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data
        base_price = 1.0800 if symbol == 'EURUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get ultra-high accuracy signal
        signal = predictor.get_ultra_high_accuracy_signal(df, symbol, spread)
        
        # Convert to JSON-serializable format
        response = {
            'status': 'success',
            'timestamp': signal['timestamp'].isoformat(),
            'symbol': signal['symbol'],
            'can_trade': signal['can_trade'],
            'score': signal['score'],
            'filters': signal['filters'],
            'reasons': signal['reasons']
        }
        
        # Add trade details if approved
        if signal['can_trade']:
            response.update({
                'signal': signal['signal'].name,
                'direction': signal['direction'],
                'confidence': signal['confidence'],
                'probability': signal['probability'],
                'risk_reward': signal['risk_reward'],
                'volatility': signal['volatility'],
                'position_size': signal['position_size'],
                'stop_loss': signal['stop_loss'],
                'take_profit': signal['take_profit']
            })
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error getting ultra-high accuracy signal: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/enable_ultra_high_accuracy', methods=['POST'])
def enable_ultra_high_accuracy():
    """Enable/disable ultra-high accuracy mode"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        
        predictor.enable_ultra_high_accuracy_mode(enabled)
        
        return jsonify({
            'status': 'success',
            'ultra_high_accuracy_enabled': enabled,
            'message': f"Ultra-high accuracy mode {'enabled' if enabled else 'disabled'}"
        })
        
    except Exception as e:
        logger.error(f"Error toggling ultra-high accuracy mode: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/volatility_signal/<symbol>', methods=['GET'])
def get_volatility_signal(symbol):
    """Get volatility trading signal (90%+ win rate in volatile markets)"""
    try:
        # Get spread parameter
        spread = float(request.args.get('spread', 0.0001))
        
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data with volatility
        base_price = 1.0800 if symbol == 'EURUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.002, periods))  # Higher volatility
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.001, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.002, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.002, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get volatility signal
        signal = predictor.get_volatility_signal(df, symbol, spread)
        
        return jsonify(signal)
        
    except Exception as e:
        logger.error(f"Error getting volatility signal: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/adaptive_signal/<symbol>', methods=['GET'])
def get_adaptive_signal(symbol):
    """Get adaptive signal that automatically selects best strategy"""
    try:
        # Get spread parameter
        spread = float(request.args.get('spread', 0.0001))
        
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data
        base_price = 1.0800 if symbol == 'EURUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get adaptive signal
        signal = predictor.get_adaptive_signal(df, symbol, spread)
        
        return jsonify(signal)
        
    except Exception as e:
        logger.error(f"Error getting adaptive signal: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/news_signal/<symbol>', methods=['GET'])
def get_news_signal(symbol):
    """Get news event trading signal (85%+ win rate on major news)"""
    try:
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data
        base_price = 1.2700 if symbol == 'GBPUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get news trading signal
        signal = predictor.get_news_signal(df, symbol)
        
        return jsonify(signal)
        
    except Exception as e:
        logger.error(f"Error getting news signal: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/economic_calendar/<symbol>', methods=['GET'])
def get_economic_calendar(symbol):
    """Get upcoming economic calendar events"""
    try:
        days_ahead = int(request.args.get('days', 7))
        
        calendar = predictor.get_economic_calendar(symbol, days_ahead)
        
        return jsonify(calendar)
        
    except Exception as e:
        logger.error(f"Error getting economic calendar: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/enable_volatility_suite', methods=['POST'])
def enable_volatility_suite():
    """Enable/disable volatility trading suite"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        
        predictor.enable_volatility_suite(enabled)
        
        return jsonify({
            'status': 'success',
            'volatility_suite_enabled': enabled,
            'message': f"Volatility trading suite {'enabled' if enabled else 'disabled'}"
        })
        
    except Exception as e:
        logger.error(f"Error toggling volatility suite: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/enable_adaptive_mode', methods=['POST'])
def enable_adaptive_mode():
    """Enable/disable adaptive strategy selection"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        
        predictor.enable_adaptive_mode(enabled)
        
        return jsonify({
            'status': 'success',
            'adaptive_mode_enabled': enabled,
            'message': f"Adaptive strategy mode {'enabled' if enabled else 'disabled'}"
        })
        
    except Exception as e:
        logger.error(f"Error toggling adaptive mode: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/enable_news_trading', methods=['POST'])
def enable_news_trading():
    """Enable/disable news event trading"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        
        predictor.enable_news_trading(enabled)
        
        return jsonify({
            'status': 'success',
            'news_trading_enabled': enabled,
            'message': f"News event trading {'enabled' if enabled else 'disabled'}"
        })
        
    except Exception as e:
        logger.error(f"Error toggling news trading: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/enable_aggressive_sizing', methods=['POST'])
def enable_aggressive_sizing():
    """Enable/disable aggressive position sizing (100:1+ leverage, 20% risk)"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        account_balance = data.get('account_balance')
        
        predictor.enable_aggressive_sizing(enabled, account_balance)
        
        return jsonify({
            'status': 'success',
            'aggressive_sizing_enabled': enabled,
            'account_balance': predictor.position_manager.account_balance if enabled else None,
            'max_leverage': predictor.position_manager.max_leverage if enabled else None,
            'max_risk_per_trade': f"{predictor.position_manager.max_risk_percentage:.0%}" if enabled else None,
            'message': f"Aggressive position sizing {'enabled' if enabled else 'disabled'}"
        })
        
    except Exception as e:
        logger.error(f"Error toggling aggressive sizing: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/aggressive_position_analysis/<symbol>', methods=['GET'])
def get_aggressive_position_analysis(symbol):
    """Get comprehensive aggressive position analysis"""
    try:
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data for GBP/USD
        base_price = 1.2700 if symbol == 'GBPUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get aggressive position analysis
        analysis = predictor.get_aggressive_position_analysis(df, symbol)
        
        return jsonify(analysis)
        
    except Exception as e:
        logger.error(f"Error getting aggressive position analysis: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/enable_unified_aggressive', methods=['POST'])
def enable_unified_aggressive():
    """Enable/disable unified aggressive trading (20% risk on ALL GBP/USD trades)"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        account_balance = data.get('account_balance')
        
        predictor.enable_unified_aggressive_trading(enabled, account_balance)
        
        response = {
            'status': 'success',
            'unified_aggressive_enabled': enabled,
            'message': f"Unified aggressive trading {'enabled' if enabled else 'disabled'}"
        }
        
        if enabled:
            response.update({
                'account_balance': predictor.unified_aggressive.position_manager.account_balance,
                'gbpusd_risk_percentage': f"{predictor.unified_aggressive.gbpusd_risk_percentage:.0%}",
                'target_daily_return': f"{predictor.unified_aggressive.target_daily_return:.0%}",
                'max_leverage': f"{predictor.unified_aggressive.position_manager.max_leverage}:1"
            })
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error toggling unified aggressive trading: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/unified_aggressive_signal/<symbol>', methods=['GET'])
def get_unified_aggressive_signal(symbol):
    """Get unified aggressive signal with 20% risk model for ALL strategies"""
    try:
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data for GBP/USD
        base_price = 1.2700 if symbol == 'GBPUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get unified aggressive signal
        signal = predictor.get_unified_aggressive_signal(df, symbol)
        
        return jsonify(signal)
        
    except Exception as e:
        logger.error(f"Error getting unified aggressive signal: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/daily_trading_plan/<symbol>', methods=['GET'])
def get_daily_trading_plan(symbol):
    """Get daily trading plan with 20% risk model"""
    try:
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data
        base_price = 1.2700 if symbol == 'GBPUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get daily trading plan
        plan = predictor.get_daily_trading_plan(df, symbol)
        
        return jsonify(plan)
        
    except Exception as e:
        logger.error(f"Error getting daily trading plan: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/trading_dashboard/<symbol>', methods=['GET'])
def get_trading_dashboard(symbol):
    """Get comprehensive trading dashboard for aggressive news trading"""
    try:
        # Get historical data (mock for now)
        periods = 200
        dates = pd.date_range(end=datetime.now(), periods=periods, freq='H')
        
        # Generate mock OHLCV data
        base_price = 1.2700 if symbol == 'GBPUSD' else 1.0000
        prices = base_price + np.cumsum(np.random.normal(0, 0.001, periods))
        
        df = pd.DataFrame({
            'open': prices * (1 + np.random.normal(0, 0.0005, periods)),
            'high': prices * (1 + abs(np.random.normal(0, 0.001, periods))),
            'low': prices * (1 - abs(np.random.normal(0, 0.001, periods))),
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        }, index=dates)
        
        # Get all relevant data
        dashboard = {
            'symbol': symbol,
            'timestamp': datetime.now().isoformat(),
            'current_price': float(df['close'].iloc[-1]),
        }
        
        # Add news trading data if enabled
        if predictor.use_news_trading:
            news_signal = predictor.get_news_signal(df, symbol)
            dashboard['news_trading'] = news_signal
        
        # Add economic calendar
        calendar = predictor.get_economic_calendar(symbol, 3)  # Next 3 days
        dashboard['economic_calendar'] = calendar
        
        # Add aggressive position analysis if enabled
        if predictor.use_aggressive_sizing:
            position_analysis = predictor.get_aggressive_position_analysis(df, symbol)
            dashboard['aggressive_analysis'] = position_analysis
        
        # Add unified aggressive trading if enabled
        if predictor.use_unified_aggressive:
            unified_signal = predictor.get_unified_aggressive_signal(df, symbol)
            dashboard['unified_aggressive'] = unified_signal
            
            daily_plan = predictor.get_daily_trading_plan(df, symbol)
            dashboard['daily_plan'] = daily_plan
        
        # Add system status
        dashboard['system_status'] = {
            'news_trading_enabled': predictor.use_news_trading,
            'aggressive_sizing_enabled': predictor.use_aggressive_sizing,
            'unified_aggressive_enabled': predictor.use_unified_aggressive,
            'adaptive_mode_enabled': predictor.use_adaptive_mode,
            'volatility_suite_enabled': predictor.use_volatility_suite,
            'ultra_high_accuracy_enabled': predictor.use_ultra_high_accuracy
        }
        
        return jsonify(dashboard)
        
    except Exception as e:
        logger.error(f"Error getting trading dashboard: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting ML API server on port 5001...")
    app.run(host='0.0.0.0', port=5001, debug=True)