/**
 * Input Validation Middleware
 * Validates and sanitizes request data to prevent injection attacks
 */

const { body, query, param, validationResult } = require('express-validator');

/**
 * Handle validation errors
 * Returns 400 Bad Request with error details
 */
function handleValidationErrors(req, res, next) {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      code: 'VALIDATION_ERROR',
      errors: errors.array().map(err => ({
        field: err.path,
        message: err.msg,
        value: err.value
      }))
    });
  }

  next();
}

/**
 * Login validation rules
 */
const validateLogin = [
  body('username')
    .trim()
    .notEmpty().withMessage('Username is required')
    .isLength({ min: 3, max: 50 }).withMessage('Username must be 3-50 characters')
    .matches(/^[a-zA-Z0-9_-]+$/).withMessage('Username contains invalid characters'),

  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),

  handleValidationErrors
];

/**
 * Trade execution validation rules
 */
const validateTrade = [
  body('symbol')
    .trim()
    .notEmpty().withMessage('Symbol is required')
    .matches(/^[A-Z]{6}$/).withMessage('Invalid symbol format (e.g., EURUSD)'),

  body('type')
    .notEmpty().withMessage('Trade type is required')
    .isIn(['buy', 'sell', 'BUY', 'SELL']).withMessage('Type must be buy or sell'),

  body('lots')
    .notEmpty().withMessage('Lot size is required')
    .isFloat({ min: 0.01, max: 100 }).withMessage('Lots must be between 0.01 and 100'),

  body('stopLoss')
    .optional()
    .isFloat({ min: 0 }).withMessage('Stop loss must be a positive number'),

  body('takeProfit')
    .optional()
    .isFloat({ min: 0 }).withMessage('Take profit must be a positive number'),

  body('comment')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Comment must be max 100 characters')
    .matches(/^[a-zA-Z0-9\s\-_.,]*$/).withMessage('Comment contains invalid characters'),

  handleValidationErrors
];

/**
 * Position close validation rules
 */
const validateClosePosition = [
  body('ticket')
    .notEmpty().withMessage('Ticket is required')
    .isInt({ min: 1 }).withMessage('Ticket must be a positive integer'),

  handleValidationErrors
];

/**
 * MT4 connection validation rules
 */
const validateConnection = [
  body('accountId')
    .notEmpty().withMessage('Account ID is required')
    .isInt({ min: 1 }).withMessage('Account ID must be a positive integer'),

  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 1, max: 50 }).withMessage('Password must be 1-50 characters'),

  body('server')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Server name too long')
    .matches(/^[a-zA-Z0-9\-_.]+$/).withMessage('Invalid server name format'),

  handleValidationErrors
];

/**
 * Signals query validation rules
 */
const validateSignalsQuery = [
  query('symbol')
    .optional()
    .trim()
    .matches(/^[A-Z]{6}$/).withMessage('Invalid symbol format (e.g., EURUSD)'),

  query('timeframe')
    .optional()
    .isIn(['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1'])
    .withMessage('Invalid timeframe'),

  handleValidationErrors
];

/**
 * Positions query validation rules
 */
const validatePositionsQuery = [
  query('symbol')
    .optional()
    .trim()
    .matches(/^[A-Z]{6}$/).withMessage('Invalid symbol format'),

  query('status')
    .optional()
    .isIn(['open', 'closed', 'all'])
    .withMessage('Status must be open, closed, or all'),

  handleValidationErrors
];

/**
 * WebSocket subscription validation
 */
function validateWebSocketMessage(data) {
  const { type, payload } = data;

  if (!type || typeof type !== 'string') {
    return {
      valid: false,
      error: 'Message type is required and must be a string'
    };
  }

  // Validate based on message type
  switch (type) {
    case 'subscribe_prices':
      if (!payload || !Array.isArray(payload.symbols)) {
        return {
          valid: false,
          error: 'Payload must contain symbols array'
        };
      }

      // Validate each symbol
      const invalidSymbols = payload.symbols.filter(s =>
        typeof s !== 'string' || !/^[A-Z]{6}$/.test(s)
      );

      if (invalidSymbols.length > 0) {
        return {
          valid: false,
          error: `Invalid symbols: ${invalidSymbols.join(', ')}`
        };
      }

      // Limit number of subscriptions
      if (payload.symbols.length > 50) {
        return {
          valid: false,
          error: 'Maximum 50 symbols can be subscribed at once'
        };
      }
      break;

    case 'unsubscribe_prices':
      if (!payload || !Array.isArray(payload.symbols)) {
        return {
          valid: false,
          error: 'Payload must contain symbols array'
        };
      }
      break;

    default:
      // Unknown message types are handled by the message router
      break;
  }

  return { valid: true };
}

/**
 * Sanitize user input
 * Removes potentially dangerous characters
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') return input;

  return input
    .replace(/[<>\"']/g, '') // Remove HTML/script characters
    .trim();
}

/**
 * Validate JWT token format
 */
const validateToken = [
  body('refreshToken')
    .notEmpty().withMessage('Refresh token is required')
    .matches(/^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$/)
    .withMessage('Invalid token format'),

  handleValidationErrors
];

module.exports = {
  validateLogin,
  validateTrade,
  validateClosePosition,
  validateConnection,
  validateSignalsQuery,
  validatePositionsQuery,
  validateWebSocketMessage,
  validateToken,
  sanitizeInput,
  handleValidationErrors
};
