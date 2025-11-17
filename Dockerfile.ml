# Dockerfile for ML Engine
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better caching)
COPY ml/requirements.txt /app/ml/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r ml/requirements.txt

# Copy ML engine code
COPY ml/ /app/ml/

# Set Python path
ENV PYTHONPATH=/app

# Default environment variables
ENV TRADING_SYMBOL=EURUSD
ENV TRADING_TIMEFRAME=H1
ENV BRIDGE_URL=http://bridge:8080
ENV PREDICTION_INTERVAL=60

# Run the quantum predictor
CMD ["python", "ml/quantum_predictor.py", "--daemon", "--bridge-url", "${BRIDGE_URL}", "--symbol", "${TRADING_SYMBOL}", "--timeframe", "${TRADING_TIMEFRAME}", "--interval", "${PREDICTION_INTERVAL}"]
