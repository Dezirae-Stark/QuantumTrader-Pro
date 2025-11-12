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
    // Allow requests with no origin (like mobile apps or Postman)
    if (!origin && developmentMode) {
      return callback(null, true);
    }

    // In development mode, allow all origins (INSECURE)
    if (developmentMode) {
      console.log(`[CORS] Development mode: allowing origin ${origin}`);
      return callback(null, true);
    }

    // Production mode: check whitelist
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      console.warn(`[CORS] Blocked origin: ${origin}`);
      callback(new Error('Not allowed by CORS policy'));
    }
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
  credentials: true,

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
  console.log(`[CORS] Mode: ${developmentMode ? 'DEVELOPMENT (PERMISSIVE)' : 'PRODUCTION (RESTRICTIVE)'}`);

  if (!developmentMode) {
    console.log(`[CORS] Allowed origins: ${allowedOrigins.join(', ')}`);
  } else {
    console.warn('[CORS] WARNING: Development mode allows all origins! NOT SAFE FOR PRODUCTION');
  }
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
