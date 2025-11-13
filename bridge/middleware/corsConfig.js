/**
 * CORS Configuration
 * Secure Cross-Origin Resource Sharing setup
 */

const cors = require('cors');

// Allowed origins for production (whitelist)
// Add your production domain and mobile app URLs here
const allowedOrigins = [
  'http://localhost:3000',          // Development frontend
  'http://localhost:8080',          // Local testing
  'http://127.0.0.1:3000',          // Alternative localhost
  'http://127.0.0.1:8080',          // Alternative localhost
  // Add production domains:
  // 'https://quantumtrader.com',
  // 'https://app.quantumtrader.com',
  // 'capacitor://localhost',       // For Capacitor mobile apps
  // 'ionic://localhost'             // For Ionic mobile apps
];

// Add environment-specific origins
if (process.env.ALLOWED_ORIGINS) {
  const envOrigins = process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim());
  allowedOrigins.push(...envOrigins);
}

// In development, allow all origins (INSECURE - DO NOT USE IN PRODUCTION)
const developmentMode = process.env.NODE_ENV === 'development';

/**
 * CORS options configuration
 */
const corsOptions = {
  origin: (origin, callback) => {
    // Allow all origins (including requests with no origin like mobile apps or Postman)
    console.log(`[CORS] Allowing origin: ${origin || 'no-origin'}`);
    return callback(null, true);
  },

  // Allowed HTTP methods
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],

  // Allowed request headers
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'X-API-Key'
  ],

  // Expose these headers to the client
  exposedHeaders: [
    'X-RateLimit-Limit',
    'X-RateLimit-Remaining',
    'X-RateLimit-Reset'
  ],

  // Allow credentials (cookies, authorization headers)
  credentials: false,

  // Cache preflight requests for 24 hours
  maxAge: 86400,

  // Enable preflight response for all routes
  preflightContinue: false,

  // Return 204 for OPTIONS requests
  optionsSuccessStatus: 204
};

/**
 * Create CORS middleware with secure configuration
 */
const secureCors = cors(corsOptions);

/**
 * Log CORS configuration on startup
 */
function logCorsConfig() {
  console.log('[CORS] Configuration loaded');
  console.log('[CORS] Mode: PERMISSIVE - All origins allowed');
  console.warn('[CORS] WARNING: All origins are allowed! This is NOT recommended for production.');
}

/**
 * Manually check if origin is allowed (for WebSocket connections)
 * @param {string} origin - Origin header value
 * @returns {boolean} True if origin is allowed
 */
function isOriginAllowed(origin) {
  if (developmentMode) {
    return true;
  }

  return allowedOrigins.indexOf(origin) !== -1;
}

/**
 * Add an origin to the whitelist dynamically
 * @param {string} origin - Origin URL to add
 */
function addAllowedOrigin(origin) {
  if (!allowedOrigins.includes(origin)) {
    allowedOrigins.push(origin);
    console.log(`[CORS] Added allowed origin: ${origin}`);
  }
}

module.exports = {
  secureCors,
  corsOptions,
  isOriginAllowed,
  addAllowedOrigin,
  logCorsConfig,
  allowedOrigins
};
