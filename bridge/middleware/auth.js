/**
 * JWT Authentication Middleware
 * Secures bridge server endpoints with JSON Web Tokens
 */

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'CHANGE_THIS_SECRET_IN_PRODUCTION';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

// In-memory user store (replace with database in production)
// For demo purposes, includes LHFX practice account credentials
const users = new Map([
  ['admin', {
    username: 'admin',
    // Password: 'changeme' (hashed with bcrypt)
    passwordHash: '$2a$10$Z8qBH9J7pV5dXKZN.Yf8HuWXvR2K.nEJ3v6FN4qX2mWc4Y9Z6xN3C',
    role: 'admin',
    mt4Accounts: []
  }]
]);

/**
 * Generate JWT access token
 * @param {object} user - User object
 * @returns {string} JWT token
 */
function generateAccessToken(user) {
  const payload = {
    username: user.username,
    role: user.role,
    type: 'access'
  };

  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

/**
 * Generate JWT refresh token
 * @param {object} user - User object
 * @returns {string} JWT refresh token
 */
function generateRefreshToken(user) {
  const payload = {
    username: user.username,
    type: 'refresh'
  };

  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });
}

/**
 * Verify JWT token
 * @param {string} token - JWT token
 * @returns {object} Decoded token payload
 */
function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    throw new Error('Invalid or expired token');
  }
}

/**
 * Authentication middleware for REST endpoints
 * Validates JWT token from Authorization header
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access token required',
      code: 'NO_TOKEN'
    });
  }

  try {
    const decoded = verifyToken(token);

    if (decoded.type !== 'access') {
      return res.status(401).json({
        success: false,
        message: 'Invalid token type',
        code: 'INVALID_TOKEN_TYPE'
      });
    }

    // Attach user info to request
    req.user = {
      username: decoded.username,
      role: decoded.role
    };

    next();
  } catch (error) {
    return res.status(403).json({
      success: false,
      message: 'Invalid or expired token',
      code: 'TOKEN_INVALID',
      error: error.message
    });
  }
}

/**
 * Login endpoint handler
 * Authenticates user and returns JWT tokens
 */
async function login(req, res) {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Username and password required'
      });
    }

    // Retrieve user from store
    const user = users.get(username);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);

    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Log successful authentication
    console.log(`[AUTH] User authenticated: ${username} at ${new Date().toISOString()}`);

    res.json({
      success: true,
      message: 'Authentication successful',
      accessToken,
      refreshToken,
      expiresIn: JWT_EXPIRES_IN,
      user: {
        username: user.username,
        role: user.role
      }
    });

  } catch (error) {
    console.error('[AUTH] Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Authentication failed',
      error: error.message
    });
  }
}

/**
 * Token refresh endpoint handler
 * Issues new access token using valid refresh token
 */
async function refreshTokenHandler(req, res) {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token required'
      });
    }

    const decoded = verifyToken(refreshToken);

    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        success: false,
        message: 'Invalid token type',
        code: 'INVALID_TOKEN_TYPE'
      });
    }

    const user = users.get(decoded.username);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    // Generate new access token
    const accessToken = generateAccessToken(user);

    res.json({
      success: true,
      message: 'Token refreshed',
      accessToken,
      expiresIn: JWT_EXPIRES_IN
    });

  } catch (error) {
    console.error('[AUTH] Token refresh error:', error);
    res.status(403).json({
      success: false,
      message: 'Invalid or expired refresh token',
      error: error.message
    });
  }
}

/**
 * Helper function to add new user (for initial setup)
 * @param {string} username - Username
 * @param {string} password - Plain text password
 * @param {string} role - User role
 */
async function addUser(username, password, role = 'user') {
  const passwordHash = await bcrypt.hash(password, 10);
  users.set(username, {
    username,
    passwordHash,
    role,
    mt4Accounts: []
  });
  console.log(`[AUTH] User added: ${username} (${role})`);
}

/**
 * WebSocket authentication middleware
 * Validates JWT token from query parameter or first message
 */
function authenticateWebSocket(ws, req) {
  // Extract token from query parameter
  const url = new URL(req.url, `http://${req.headers.host}`);
  const token = url.searchParams.get('token');

  if (!token) {
    return {
      authenticated: false,
      error: 'Token required for WebSocket connection'
    };
  }

  try {
    const decoded = verifyToken(token);

    if (decoded.type !== 'access') {
      return {
        authenticated: false,
        error: 'Invalid token type'
      };
    }

    return {
      authenticated: true,
      user: {
        username: decoded.username,
        role: decoded.role
      }
    };

  } catch (error) {
    return {
      authenticated: false,
      error: 'Invalid or expired token'
    };
  }
}

module.exports = {
  authenticateToken,
  authenticateWebSocket,
  login,
  refreshTokenHandler,
  addUser,
  generateAccessToken,
  generateRefreshToken,
  verifyToken
};
