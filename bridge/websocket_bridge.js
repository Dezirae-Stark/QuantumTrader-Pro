/**
 * QuantumTrader-Pro WebSocket Bridge Server (SECURED)
 * Node.js server bridging MT4/LHFX with ML Python backend
 * Port: 8080
 *
 * Security Features:
 * - JWT Authentication
 * - Rate Limiting
 * - Input Validation
 * - CORS Whitelist
 * - Security Headers (Helmet)
 */

// Load environment variables
require('dotenv').config();

const express = require('express');
const WebSocket = require('ws');
const http = require('http');
const helmet = require('helmet');

// Security middleware
const { secureCors, logCorsConfig } = require('./middleware/corsConfig');
const {
  authenticateToken,
  authenticateWebSocket,
  login,
  refreshTokenHandler
} = require('./middleware/auth');
const {
  apiLimiter,
  authLimiter,
  tradeLimiter,
  healthCheckLimiter
} = require('./middleware/rateLimit');
const {
  validateLogin,
  validateTrade,
  validateClosePosition,
  validateConnection,
  validateSignalsQuery,
  validatePositionsQuery,
  validateToken,
  validateWebSocketMessage
} = require('./middleware/validation');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Security Middleware
app.use(helmet()); // Security headers
app.use(secureCors); // CORS with whitelist
app.use(express.json({ limit: '1mb' })); // Body parser with size limit
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Trust proxy if behind reverse proxy (nginx, load balancer)
if (process.env.TRUST_PROXY === 'true') {
  app.set('trust proxy', 1);
}

// Log CORS configuration on startup
logCorsConfig();

// Configuration
const PORT = process.env.PORT || 8080;
const MAX_RECONNECT_ATTEMPTS = 5;
const HEARTBEAT_INTERVAL = 30000; // 30 seconds

// State management
const state = {
    lhfxConnected: false,
    mlConnected: false,
    activePositions: new Map(),
    priceStreams: new Map(),
    clients: new Set(),
    lastHeartbeat: Date.now()
};

// Logger utility
const logger = {
    info: (msg, data = {}) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`, data),
    error: (msg, error = {}) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`, error),
    warn: (msg, data = {}) => console.warn(`[WARN] ${new Date().toISOString()} - ${msg}`, data),
    debug: (msg, data = {}) => console.debug(`[DEBUG] ${new Date().toISOString()} - ${msg}`, data)
};

// WebSocket connection handler
wss.on('connection', (ws, req) => {
    const clientId = `${req.socket.remoteAddress}:${req.socket.remotePort}`;
    logger.info(`New WebSocket connection attempt`, { clientId });

    // Authenticate WebSocket connection
    const authResult = authenticateWebSocket(ws, req);

    if (!authResult.authenticated) {
        logger.warn(`WebSocket authentication failed`, { clientId, error: authResult.error });
        ws.send(JSON.stringify({
            type: 'error',
            message: authResult.error,
            code: 'WS_AUTH_FAILED',
            timestamp: Date.now()
        }));
        ws.close(1008, authResult.error); // Policy violation
        return;
    }

    logger.info(`WebSocket authenticated`, {
        clientId,
        username: authResult.user.username
    });

    state.clients.add(ws);
    ws.isAlive = true;
    ws.clientId = clientId;
    ws.user = authResult.user;

    // Send connection acknowledgment
    ws.send(JSON.stringify({
        type: 'connection',
        status: 'connected',
        timestamp: Date.now(),
        serverInfo: {
            version: '1.0.0',
            lhfxConnected: state.lhfxConnected,
            mlConnected: state.mlConnected
        }
    }));

    // Heartbeat pong handler
    ws.on('pong', () => {
        ws.isAlive = true;
        state.lastHeartbeat = Date.now();
    });

    // Message handler
    ws.on('message', async (message) => {
        try {
            const data = JSON.parse(message);

            // Validate message structure
            const validation = validateWebSocketMessage(data);
            if (!validation.valid) {
                logger.warn('Invalid WebSocket message', {
                    clientId,
                    error: validation.error
                });
                ws.send(JSON.stringify({
                    type: 'error',
                    message: validation.error,
                    code: 'VALIDATION_ERROR',
                    timestamp: Date.now()
                }));
                return;
            }

            await handleWebSocketMessage(ws, data);
        } catch (error) {
            logger.error('WebSocket message error', { error: error.message, clientId });
            ws.send(JSON.stringify({
                type: 'error',
                message: 'Invalid message format',
                code: 'MESSAGE_PARSE_ERROR',
                timestamp: Date.now()
            }));
        }
    });

    // Connection close handler
    ws.on('close', () => {
        logger.info(`WebSocket disconnected`, { clientId });
        state.clients.delete(ws);
    });

    // Error handler
    ws.on('error', (error) => {
        logger.error('WebSocket error', { error: error.message, clientId });
    });
});

// WebSocket message router
async function handleWebSocketMessage(ws, data) {
    const { type, payload } = data;

    switch (type) {
        case 'subscribe_prices':
            handlePriceSubscription(ws, payload);
            break;
        case 'unsubscribe_prices':
            handlePriceUnsubscription(ws, payload);
            break;
        case 'price_update':
            broadcastPriceUpdate(payload);
            break;
        case 'signal_update':
            broadcastSignal(payload);
            break;
        case 'position_update':
            updatePosition(payload);
            break;
        case 'lhfx_status':
            updateLHFXStatus(payload);
            break;
        case 'ml_status':
            updateMLStatus(payload);
            break;
        default:
            ws.send(JSON.stringify({
                type: 'error',
                message: `Unknown message type: ${type}`,
                timestamp: Date.now()
            }));
    }
}

// Price subscription handler
function handlePriceSubscription(ws, payload) {
    const { symbols } = payload;

    if (!symbols || !Array.isArray(symbols)) {
        ws.send(JSON.stringify({
            type: 'error',
            message: 'Invalid symbols array',
            timestamp: Date.now()
        }));
        return;
    }

    ws.subscribedSymbols = new Set(symbols);

    logger.info('Price subscription added', {
        clientId: ws.clientId,
        symbols
    });

    ws.send(JSON.stringify({
        type: 'subscription_confirmed',
        symbols,
        timestamp: Date.now()
    }));
}

// Price unsubscription handler
function handlePriceUnsubscription(ws, payload) {
    const { symbols } = payload;

    if (ws.subscribedSymbols) {
        symbols.forEach(symbol => ws.subscribedSymbols.delete(symbol));
    }

    logger.info('Price subscription removed', {
        clientId: ws.clientId,
        symbols
    });
}

// Broadcast price update to subscribed clients
function broadcastPriceUpdate(priceData) {
    const { symbol, bid, ask, timestamp } = priceData;

    state.priceStreams.set(symbol, { bid, ask, timestamp });

    const message = JSON.stringify({
        type: 'price_update',
        symbol,
        bid,
        ask,
        spread: (ask - bid).toFixed(5),
        timestamp
    });

    state.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN &&
            client.subscribedSymbols &&
            client.subscribedSymbols.has(symbol)) {
            client.send(message);
        }
    });
}

// Broadcast ML signal to all clients
function broadcastSignal(signalData) {
    const message = JSON.stringify({
        type: 'signal',
        ...signalData,
        timestamp: Date.now()
    });

    state.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });

    logger.info('Signal broadcasted', { signal: signalData.direction, symbol: signalData.symbol });
}

// Update position state
function updatePosition(positionData) {
    const { ticket, action } = positionData;

    if (action === 'open' || action === 'update') {
        state.activePositions.set(ticket, positionData);
    } else if (action === 'close') {
        state.activePositions.delete(ticket);
    }

    broadcastPositionUpdate(positionData);
}

// Broadcast position update
function broadcastPositionUpdate(positionData) {
    const message = JSON.stringify({
        type: 'position_update',
        ...positionData,
        timestamp: Date.now()
    });

    state.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}

// Update LHFX connection status
function updateLHFXStatus(statusData) {
    state.lhfxConnected = statusData.connected;
    logger.info('LHFX status updated', statusData);

    broadcastSystemStatus();
}

// Update ML connection status
function updateMLStatus(statusData) {
    state.mlConnected = statusData.connected;
    logger.info('ML status updated', statusData);

    broadcastSystemStatus();
}

// Broadcast system status
function broadcastSystemStatus() {
    const message = JSON.stringify({
        type: 'system_status',
        lhfxConnected: state.lhfxConnected,
        mlConnected: state.mlConnected,
        activePositions: state.activePositions.size,
        connectedClients: state.clients.size,
        timestamp: Date.now()
    });

    state.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}

// REST API Endpoints

// ============================================
// Authentication Endpoints (Public)
// ============================================

// Login endpoint - Get JWT tokens
app.post('/api/auth/login', authLimiter, validateLogin, login);

// Token refresh endpoint - Get new access token
app.post('/api/auth/refresh', authLimiter, validateToken, refreshTokenHandler);

// ============================================
// API Endpoints (Protected)
// ============================================

// Apply general rate limiting to all API endpoints
app.use('/api', apiLimiter);

// Health check endpoint (less restrictive)
app.get('/api/health', healthCheckLimiter, (req, res) => {
    const health = {
        status: 'healthy',
        uptime: process.uptime(),
        lhfxConnected: state.lhfxConnected,
        mlConnected: state.mlConnected,
        activePositions: state.activePositions.size,
        connectedClients: state.clients.size,
        lastHeartbeat: state.lastHeartbeat,
        timestamp: Date.now()
    };

    res.json(health);
    logger.debug('Health check requested', health);
});

// LHFX connection endpoint (PROTECTED)
app.post('/api/connect', authenticateToken, validateConnection, async (req, res) => {
    try {
        const { accountId, password, server } = req.body;

        if (!accountId || !password) {
            return res.status(400).json({
                success: false,
                message: 'Account ID and password are required'
            });
        }

        logger.info('LHFX connection request', { accountId, server });

        // Simulate connection process (replace with actual LHFX API integration)
        state.lhfxConnected = true;

        broadcastSystemStatus();

        res.json({
            success: true,
            message: 'Connected to LHFX successfully',
            accountId,
            timestamp: Date.now()
        });

    } catch (error) {
        logger.error('Connection error', { error: error.message });
        res.status(500).json({
            success: false,
            message: 'Connection failed',
            error: error.message
        });
    }
});

// Get signals endpoint (PROTECTED)
app.get('/api/signals', authenticateToken, validateSignalsQuery, (req, res) => {
    try {
        const { symbol, timeframe } = req.query;

        // Return cached signals or fetch from ML backend
        const signals = {
            symbol: symbol || 'EURUSD',
            timeframe: timeframe || 'M15',
            signals: [],
            timestamp: Date.now()
        };

        res.json(signals);

    } catch (error) {
        logger.error('Signals retrieval error', { error: error.message });
        res.status(500).json({
            success: false,
            message: 'Failed to retrieve signals',
            error: error.message
        });
    }
});

// Get positions endpoint (PROTECTED)
app.get('/api/positions', authenticateToken, validatePositionsQuery, (req, res) => {
    try {
        const positions = Array.from(state.activePositions.values());

        res.json({
            success: true,
            count: positions.length,
            positions,
            timestamp: Date.now()
        });

    } catch (error) {
        logger.error('Positions retrieval error', { error: error.message });
        res.status(500).json({
            success: false,
            message: 'Failed to retrieve positions',
            error: error.message
        });
    }
});

// Execute trade endpoint (PROTECTED + RATE LIMITED)
app.post('/api/trade', authenticateToken, tradeLimiter, validateTrade, async (req, res) => {
    try {
        const { symbol, type, lots, stopLoss, takeProfit, comment } = req.body;

        if (!symbol || !type || !lots) {
            return res.status(400).json({
                success: false,
                message: 'Symbol, type, and lots are required'
            });
        }

        logger.info('Trade execution request', { symbol, type, lots });

        // Simulate trade execution (replace with actual LHFX API integration)
        const ticket = Math.floor(Math.random() * 1000000);
        const price = state.priceStreams.get(symbol) || { bid: 0, ask: 0 };

        const position = {
            ticket,
            symbol,
            type,
            lots,
            openPrice: type === 'buy' ? price.ask : price.bid,
            stopLoss,
            takeProfit,
            comment,
            openTime: Date.now(),
            profit: 0,
            action: 'open'
        };

        updatePosition(position);

        res.json({
            success: true,
            message: 'Trade executed successfully',
            ticket,
            position,
            timestamp: Date.now()
        });

    } catch (error) {
        logger.error('Trade execution error', { error: error.message });
        res.status(500).json({
            success: false,
            message: 'Trade execution failed',
            error: error.message
        });
    }
});

// Close position endpoint (PROTECTED)
app.post('/api/close', authenticateToken, validateClosePosition, async (req, res) => {
    try {
        const { ticket } = req.body;

        if (!ticket) {
            return res.status(400).json({
                success: false,
                message: 'Ticket is required'
            });
        }

        const position = state.activePositions.get(ticket);

        if (!position) {
            return res.status(404).json({
                success: false,
                message: 'Position not found'
            });
        }

        logger.info('Position close request', { ticket });

        // Simulate position close (replace with actual LHFX API integration)
        const closePrice = state.priceStreams.get(position.symbol) || { bid: 0, ask: 0 };

        const closedPosition = {
            ...position,
            closePrice: position.type === 'buy' ? closePrice.bid : closePrice.ask,
            closeTime: Date.now(),
            action: 'close'
        };

        updatePosition(closedPosition);

        res.json({
            success: true,
            message: 'Position closed successfully',
            ticket,
            closedPosition,
            timestamp: Date.now()
        });

    } catch (error) {
        logger.error('Position close error', { error: error.message });
        res.status(500).json({
            success: false,
            message: 'Position close failed',
            error: error.message
        });
    }
});

// Heartbeat interval to check client connections
const heartbeatInterval = setInterval(() => {
    state.clients.forEach(ws => {
        if (!ws.isAlive) {
            logger.warn('Client connection timeout', { clientId: ws.clientId });
            return ws.terminate();
        }

        ws.isAlive = false;
        ws.ping();
    });
}, HEARTBEAT_INTERVAL);

// Graceful shutdown handler
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');

    clearInterval(heartbeatInterval);

    server.close(() => {
        logger.info('Server closed');
        process.exit(0);
    });

    // Force close after 10 seconds
    setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
    }, 10000);
});

// Error handlers
process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception', { error: error.message, stack: error.stack });
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled rejection', { reason, promise });
});

// Start server
server.listen(PORT, () => {
    logger.info(`QuantumTrader-Pro Bridge Server started`, {
        port: PORT,
        environment: process.env.NODE_ENV || 'development'
    });
});

module.exports = { app, server, wss };
