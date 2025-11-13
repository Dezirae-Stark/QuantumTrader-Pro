/**
 * Rate Limiting Middleware
 * Protects bridge server from DoS attacks and API abuse
 */

const rateLimit = require('express-rate-limit');

/**
 * General API rate limiter
 * Limits: 100 requests per 15 minutes per IP
 */
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Max 100 requests per window
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false, // Disable `X-RateLimit-*` headers
  handler: (req, res) => {
    console.warn(`[RATE_LIMIT] IP ${req.ip} exceeded general API rate limit`);
    res.status(429).json({
      success: false,
      message: 'Too many requests, please try again later',
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter: req.rateLimit.resetTime
    });
  }
});

/**
 * Authentication rate limiter
 * Limits: 5 login attempts per 15 minutes per IP
 * Prevents brute force attacks
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Max 5 login attempts per window
  skipSuccessfulRequests: true, // Don't count successful logins
  message: {
    success: false,
    message: 'Too many login attempts, please try again later',
    code: 'AUTH_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    console.warn(`[RATE_LIMIT] IP ${req.ip} exceeded authentication rate limit`);
    res.status(429).json({
      success: false,
      message: 'Too many login attempts, account temporarily locked',
      code: 'AUTH_RATE_LIMIT_EXCEEDED',
      retryAfter: req.rateLimit.resetTime,
      lockoutMinutes: 15
    });
  }
});

/**
 * Trade execution rate limiter
 * Limits: 30 trades per minute per authenticated user
 * Prevents automated trading abuse
 */
const tradeLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // Max 30 trades per minute
  keyGenerator: (req) => {
    // Use username instead of IP for authenticated requests
    return req.user ? req.user.username : req.ip;
  },
  message: {
    success: false,
    message: 'Trade execution rate limit exceeded',
    code: 'TRADE_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    const identifier = req.user ? req.user.username : req.ip;
    console.warn(`[RATE_LIMIT] User ${identifier} exceeded trade execution rate limit`);
    res.status(429).json({
      success: false,
      message: 'Too many trade executions, please slow down',
      code: 'TRADE_RATE_LIMIT_EXCEEDED',
      retryAfter: req.rateLimit.resetTime,
      maxTradesPerMinute: 30
    });
  }
});

/**
 * WebSocket connection rate limiter
 * Limits: 10 connections per 5 minutes per IP
 * Prevents connection flooding
 */
const wsConnectionLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 10, // Max 10 new connections per window
  message: {
    success: false,
    message: 'Too many WebSocket connection attempts',
    code: 'WS_CONNECTION_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    console.warn(`[RATE_LIMIT] IP ${req.ip} exceeded WebSocket connection rate limit`);
    res.status(429).json({
      success: false,
      message: 'Too many connection attempts, please wait before reconnecting',
      code: 'WS_CONNECTION_LIMIT_EXCEEDED',
      retryAfter: req.rateLimit.resetTime
    });
  }
});

/**
 * Strict rate limiter for sensitive operations
 * Limits: 3 requests per hour per IP
 * Use for password resets, account changes, etc.
 */
const strictLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // Max 3 requests per hour
  message: {
    success: false,
    message: 'Too many sensitive operation attempts',
    code: 'STRICT_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    console.warn(`[RATE_LIMIT] IP ${req.ip} exceeded strict rate limit`);
    res.status(429).json({
      success: false,
      message: 'Rate limit exceeded for sensitive operations',
      code: 'STRICT_RATE_LIMIT_EXCEEDED',
      retryAfter: req.rateLimit.resetTime,
      lockoutHours: 1
    });
  }
});

/**
 * Health check rate limiter (lenient)
 * Limits: 60 requests per minute per IP
 */
const healthCheckLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 60, // Max 60 requests per minute
  skipSuccessfulRequests: false,
  message: {
    success: false,
    message: 'Health check rate limit exceeded',
    code: 'HEALTH_CHECK_RATE_LIMIT_EXCEEDED'
  }
});

/**
 * MT4/MT5 EA rate limiter (very lenient)
 * Limits: 1000 requests per 15 minutes per IP
 * MT4/MT5 EAs poll frequently (every 5 seconds), so need higher limits
 */
const mt4Limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Max 1000 requests per 15 minutes (~ 66 req/min)
  skipSuccessfulRequests: true, // Don't count successful requests
  message: {
    success: false,
    message: 'MT4/MT5 rate limit exceeded',
    code: 'MT4_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    console.warn(`[RATE_LIMIT] IP ${req.ip} exceeded MT4/MT5 rate limit`);
    res.status(429).json({
      success: false,
      message: 'Too many requests from MT4/MT5 EA, please increase polling interval',
      code: 'MT4_RATE_LIMIT_EXCEEDED',
      retryAfter: req.rateLimit.resetTime,
      recommendation: 'Increase PollingIntervalSeconds to 10 or higher'
    });
  }
});

/**
 * IP Whitelist checker
 * Allows certain IPs to bypass rate limiting (for trusted MT4/ML servers)
 */
const whitelistedIPs = process.env.RATE_LIMIT_WHITELIST
  ? process.env.RATE_LIMIT_WHITELIST.split(',').map(ip => ip.trim())
  : [];

function isWhitelisted(req) {
  if (whitelistedIPs.length === 0) return false;

  const clientIP = req.ip || req.connection.remoteAddress;
  const isWhite = whitelistedIPs.some(whiteIP =>
    clientIP.includes(whiteIP) || clientIP === whiteIP
  );

  if (isWhite) {
    console.log(`[RATE_LIMIT] Whitelisted IP: ${clientIP}`);
  }

  return isWhite;
}

/**
 * Smart rate limiter that skips whitelisted IPs
 */
function createSmartLimiter(baseLimiter) {
  return (req, res, next) => {
    if (isWhitelisted(req)) {
      return next();
    }
    return baseLimiter(req, res, next);
  };
}

module.exports = {
  apiLimiter,
  authLimiter,
  tradeLimiter,
  wsConnectionLimiter,
  strictLimiter,
  healthCheckLimiter,
  mt4Limiter,
  createSmartLimiter,
  isWhitelisted
};
