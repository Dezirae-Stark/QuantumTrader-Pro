#!/bin/bash
#
# QuantumTrader Pro - Full System Startup Script
# Starts bridge server and ML predictor daemon
#

set -e

echo "============================================================"
echo "  QuantumTrader Pro - System Startup"
echo "============================================================"
echo ""

# Check Python dependencies
echo "📦 Checking Python dependencies..."
if ! python3 -c "import flask, numpy, pandas, scipy, sklearn" 2>/dev/null; then
    echo "⚠️  Missing dependencies. Installing..."
    pip install -r ml/requirements.txt
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p bridge/data
mkdir -p predictions
mkdir -p ml/logs

# Kill any existing processes
echo "🧹 Cleaning up existing processes..."
pkill -f "mt4_bridge.py" 2>/dev/null || true
pkill -f "predictor_daemon.py" 2>/dev/null || true
sleep 2

# Start bridge server in background
echo "🌉 Starting bridge server..."
cd bridge && python3 mt4_bridge.py > ../ml/logs/bridge.log 2>&1 &
BRIDGE_PID=$!
cd ..
echo "   Bridge PID: $BRIDGE_PID"

# Wait for bridge to start
echo "⏳ Waiting for bridge to start..."
sleep 3

# Check if bridge is running
if ! curl -s http://localhost:8080/api/health > /dev/null; then
    echo "❌ Bridge failed to start. Check ml/logs/bridge.log"
    exit 1
fi
echo "✅ Bridge server running at http://localhost:8080"

# Start ML predictor daemon
echo "🔬 Starting ML predictor daemon..."
python3 ml/predictor_daemon.py \
    --symbols EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD \
    --interval 10 \
    > ml/logs/predictor.log 2>&1 &
PREDICTOR_PID=$!
echo "   Predictor PID: $PREDICTOR_PID"

echo ""
echo "============================================================"
echo "✅ QuantumTrader Pro system started successfully!"
echo "============================================================"
echo ""
echo "📊 Components running:"
echo "   • Bridge Server: http://localhost:8080 (PID: $BRIDGE_PID)"
echo "   • ML Predictor: Running (PID: $PREDICTOR_PID)"
echo ""
echo "📝 Logs:"
echo "   • Bridge:    tail -f ml/logs/bridge.log"
echo "   • Predictor: tail -f ml/logs/predictor.log"
echo "   • Daemon:    tail -f ml/logs/daemon.log"
echo ""
echo "🎯 Next steps:"
echo "   1. Attach QuantumTraderPro.mq4 EA to a chart in MT4/MT5"
echo "   2. Set BridgeURL to http://YOUR_IP:8080"
echo "   3. The EA will start sending market data automatically"
echo "   4. ML predictor will generate signals based on real data"
echo "   5. EA will open positions when confidence >= 70%"
echo ""
echo "🛑 To stop all services:"
echo "   kill $BRIDGE_PID $PREDICTOR_PID"
echo ""
echo "Press Ctrl+C to view logs (services will continue running)"
echo "============================================================"

# Tail both logs
tail -f ml/logs/bridge.log ml/logs/daemon.log
