# Bridge Server Security

**Last Updated:** 2025-01-12
**Version:** 2.0
**Applies To:** QuantumTrader Pro WebSocket Bridge Server

---

## Overview

This document describes the comprehensive security hardening applied to the QuantumTrader Pro WebSocket Bridge Server. The bridge server handles sensitive trading operations, real-time price data, and ML signals, making security critical.

**Security Measures Implemented:**
1. JWT Authentication
2. Rate Limiting
3. Input Validation
4. CORS Whitelist
5. Security Headers (Helmet)
6. WebSocket Authentication
7. Audit Logging

---

## Architecture

### Before Security Hardening

- ❌ No authentication
- ❌ CORS allows all origins
- ❌ No rate limiting
- ❌ No input validation
- ❌ HTTP allowed
- ❌ No security headers

### After Security Hardening

- ✅ JWT-based authentication
- ✅ CORS whitelist with origin validation
- ✅ Multi-tier rate limiting (auth, API, trades)
- ✅ Comprehensive input validation
- ✅ HTTPS enforced (production)
- ✅ Helmet security headers

---

## 1. JWT Authentication

### Overview

All protected endpoints require a valid JWT (JSON Web Token) in the Authorization header. Tokens are issued upon successful login and expire after 24 hours (configurable).

### Authentication Flow

```
1. Client → POST /api/auth/login (username, password)
2. Server → Validates credentials
3. Server → Returns access token + refresh token
4. Client → Includes token in all requests: Authorization: Bearer <token>
5. Server → Validates token before processing request
```

### Endpoints

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "your_password"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Authentication successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": "24h",
  "user": {
    "username": "admin",
    "role": "admin"
  }
}
```

**Response (Failure):**
```json
{
  "success": false,
  "message": "Invalid credentials",
  "code": "INVALID_CREDENTIALS"
}
```

#### Refresh Token
```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Token refreshed",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": "24h"
}
```

### Using Tokens

Include the access token in the Authorization header for all protected endpoints:

```http
GET /api/signals?symbol=EURUSD
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Configuration

**Environment Variables (.env):**
```bash
# JWT Secret - CHANGE THIS IN PRODUCTION!
JWT_SECRET=your_secure_random_string_min_32_chars

# Token Expiration
JWT_EXPIRES_IN=24h
JWT_REFRESH_EXPIRES_IN=7d
```

**Generate Secure Secret:**
```bash
# Generate 32-byte random string
openssl rand -base64 32
```

### Default Credentials

**Username:** `admin`
**Password:** `changeme`

⚠️ **CRITICAL:** Change default password immediately in production!

**To change password:**
Edit `bridge/middleware/auth.js` and update the passwordHash using bcrypt:

```javascript
const bcrypt = require('bcryptjs');
const passwordHash = await bcrypt.hash('your_new_password', 10);
```

### Security Considerations

- **Token Storage:** Store tokens securely on client (e.g., Android Keystore, iOS Keychain)
- **Token Transmission:** Always use HTTPS in production
- **Token Expiration:** Default 24h for access tokens, 7d for refresh tokens
- **Token Revocation:** Currently no revocation mechanism (future enhancement: Redis blacklist)
- **Brute Force Protection:** Rate limiting prevents brute force attacks (5 attempts/15 min)

---

## 2. Rate Limiting

### Overview

Multi-tier rate limiting protects against DoS attacks, brute force attempts, and API abuse.

### Rate Limit Tiers

| Endpoint Type | Limit | Window | Purpose |
|--------------|-------|--------|---------|
| **Authentication** | 5 attempts | 15 minutes | Prevent brute force |
| **Trade Execution** | 30 trades | 1 minute | Prevent abuse |
| **General API** | 100 requests | 15 minutes | DoS protection |
| **Health Check** | 60 requests | 1 minute | Monitoring |

### Rate Limit Headers

The server returns rate limit information in response headers:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1699876200
```

### Rate Limit Exceeded Response

```json
{
  "success": false,
  "message": "Too many requests, please try again later",
  "code": "RATE_LIMIT_EXCEEDED",
  "retryAfter": 1699876200
}
```

**HTTP Status:** `429 Too Many Requests`

### Configuration

**Environment Variables (.env):**
```bash
# Rate Limiting
RATE_LIMIT_MAX=100
AUTH_RATE_LIMIT_MAX=5
TRADE_RATE_LIMIT_MAX=30
```

### Per-User vs Per-IP

- **Authentication endpoints:** Rate limited per IP address
- **Trade endpoints:** Rate limited per authenticated user
- **General API:** Rate limited per IP address

### Bypassing Rate Limits (Development)

For testing, temporarily increase limits in `bridge/middleware/rateLimit.js`:

```javascript
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000, // Increased for testing
  //...
});
```

⚠️ **DO NOT** use high limits in production!

---

## 3. Input Validation

### Overview

All user inputs are validated and sanitized to prevent injection attacks, buffer overflows, and malformed data.

### Validation Rules

#### Login
- **username:** 3-50 alphanumeric characters, underscore, hyphen
- **password:** Minimum 6 characters

#### Trade Execution
- **symbol:** Exactly 6 uppercase letters (e.g., EURUSD)
- **type:** Must be "buy" or "sell"
- **lots:** Float between 0.01 and 100
- **stopLoss/takeProfit:** Optional positive float
- **comment:** Max 100 characters, alphanumeric only

#### MT4 Connection
- **accountId:** Positive integer
- **password:** 1-50 characters
- **server:** Max 100 characters, alphanumeric with dots/hyphens

#### Signals Query
- **symbol:** 6 uppercase letters
- **timeframe:** Must be M1, M5, M15, M30, H1, H4, D1, W1, MN1

#### Position Close
- **ticket:** Positive integer

### Validation Error Response

```json
{
  "success": false,
  "message": "Validation failed",
  "code": "VALIDATION_ERROR",
  "errors": [
    {
      "field": "symbol",
      "message": "Invalid symbol format (e.g., EURUSD)",
      "value": "EUR"
    }
  ]
}
```

**HTTP Status:** `400 Bad Request`

### WebSocket Message Validation

WebSocket messages are also validated:

```json
{
  "type": "subscribe_prices",
  "payload": {
    "symbols": ["EURUSD", "GBPUSD"]
  }
}
```

**Validation:**
- Max 50 symbols per subscription
- Each symbol must be 6 uppercase letters
- Unknown message types are rejected

### Sanitization

All string inputs are sanitized to remove:
- HTML/script characters: `< > " '`
- Trailing/leading whitespace

---

## 4. CORS Configuration

### Overview

Cross-Origin Resource Sharing (CORS) is configured with a strict whitelist to prevent unauthorized web applications from accessing the API.

### Allowed Origins

**Development Mode:**
```javascript
// .env
NODE_ENV=development
```
- Allows all origins (⚠️ INSECURE - development only!)

**Production Mode:**
```javascript
// .env
NODE_ENV=production
ALLOWED_ORIGINS=https://quantumtrader.com,https://app.quantumtrader.com
```
- Only whitelisted origins allowed
- Blocks all other origins

### Configuration

**File:** `bridge/middleware/corsConfig.js`

**Default Whitelist:**
```javascript
const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:8080',
  // Add production domains:
  'https://quantumtrader.com',
  'https://app.quantumtrader.com',
  'capacitor://localhost',  // Mobile apps
  'ionic://localhost'
];
```

### Adding New Origins

**Method 1: Environment Variable**
```bash
# .env
ALLOWED_ORIGINS=https://newdomain.com,https://api.newdomain.com
```

**Method 2: Code**
```javascript
// bridge/middleware/corsConfig.js
const allowedOrigins = [
  //... existing origins
  'https://newdomain.com'
];
```

### CORS Headers

**Allowed Methods:** GET, POST, PUT, DELETE, OPTIONS
**Allowed Headers:** Content-Type, Authorization, X-Requested-With, X-API-Key
**Exposed Headers:** X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
**Credentials:** Enabled (cookies, auth headers)
**Preflight Cache:** 24 hours

### Blocked Origin Response

When an origin is blocked:
```
HTTP/1.1 403 Forbidden
Content-Type: text/plain

Not allowed by CORS policy
```

---

## 5. Security Headers (Helmet)

### Overview

Helmet middleware automatically sets secure HTTP headers to protect against common web vulnerabilities.

### Headers Set

| Header | Value | Protection |
|--------|-------|------------|
| **X-Content-Type-Options** | nosniff | Prevents MIME sniffing |
| **X-Frame-Options** | DENY | Prevents clickjacking |
| **X-XSS-Protection** | 1; mode=block | XSS protection |
| **Strict-Transport-Security** | max-age=31536000 | Forces HTTPS |
| **Content-Security-Policy** | default-src 'self' | Restricts resources |
| **Referrer-Policy** | no-referrer | Protects referrer info |

### Configuration

Helmet is enabled by default in `bridge/websocket_bridge.js`:

```javascript
const helmet = require('helmet');
app.use(helmet());
```

**Disable (not recommended):**
```bash
# .env
ENABLE_HELMET=false
```

---

## 6. WebSocket Authentication

### Overview

WebSocket connections require authentication via JWT token in the connection URL.

### Connection URL

```javascript
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
const ws = new WebSocket(`wss://bridge.quantumtrader.com?token=${token}`);
```

### Authentication Flow

```
1. Client requests WebSocket connection with token parameter
2. Server validates token using authenticateWebSocket()
3. If invalid: Connection closed with error
4. If valid: Connection established, user info attached
```

### Authentication Failure

```json
{
  "type": "error",
  "message": "Invalid or expired token",
  "code": "WS_AUTH_FAILED",
  "timestamp": 1699876200000
}
```

**WebSocket Close Code:** 1008 (Policy Violation)

### Message Validation

All WebSocket messages are validated before processing:

```javascript
// Valid message
{
  "type": "subscribe_prices",
  "payload": {
    "symbols": ["EURUSD", "GBPUSD"]
  }
}

// Invalid message (rejected)
{
  "type": "subscribe_prices",
  "payload": {
    "symbols": ["EUR"]  // Invalid symbol format
  }
}
```

### Rate Limiting

WebSocket connections are rate limited:
- **Max connections:** 10 per 5 minutes per IP

---

## 7. Deployment Security

### Production Checklist

Before deploying to production:

- [ ] Change default admin password
- [ ] Generate secure JWT_SECRET (min 32 chars)
- [ ] Set NODE_ENV=production
- [ ] Configure ALLOWED_ORIGINS whitelist
- [ ] Enable HTTPS (set ENABLE_HTTPS=true)
- [ ] Configure SSL certificates
- [ ] Set TRUST_PROXY=true (if behind reverse proxy)
- [ ] Review rate limits for production traffic
- [ ] Test authentication flow
- [ ] Test rate limiting
- [ ] Test CORS with production domains
- [ ] Verify WebSocket authentication
- [ ] Enable security audit logging

### HTTPS Configuration

**Enable HTTPS:**
```bash
# .env
ENABLE_HTTPS=true
SSL_KEY_PATH=/path/to/private-key.pem
SSL_CERT_PATH=/path/to/certificate.pem
SSL_CA_PATH=/path/to/ca-bundle.pem
```

**Generate Self-Signed Certificate (Development):**
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

**Production Certificate:**
Use Let's Encrypt or a commercial certificate authority.

### Reverse Proxy (Nginx)

**Recommended Setup:**

```nginx
server {
    listen 443 ssl http2;
    server_name bridge.quantumtrader.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Enable Proxy Trust:**
```bash
# .env
TRUST_PROXY=true
```

---

## 8. Monitoring & Logging

### Security Audit Logging

All security events are logged:

```
[AUTH] User authenticated: admin at 2025-01-12T14:30:00.000Z
[RATE_LIMIT] IP 192.168.1.100 exceeded authentication rate limit
[CORS] Blocked origin: https://malicious-site.com
[WS_AUTH] WebSocket authentication failed for 192.168.1.100
```

### Log Levels

```bash
# .env
LOG_LEVEL=info  # error | warn | info | debug
```

### Log Files

Logs are written to stdout/stderr by default. For production, use a log aggregation service:

**PM2 with Log Rotation:**
```bash
pm2 start websocket_bridge.js --name bridge --log-date-format "YYYY-MM-DD HH:mm:ss" --merge-logs
pm2 install pm2-logrotate
```

**Docker with Fluentd:**
```yaml
services:
  bridge:
    image: quantumtrader/bridge:latest
    logging:
      driver: fluentd
      options:
        fluentd-address: localhost:24224
```

---

## 9. Testing

### Authentication Testing

**Test Login:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"changeme"}'
```

**Test Protected Endpoint:**
```bash
TOKEN="your_access_token"

curl -X GET http://localhost:8080/api/signals?symbol=EURUSD \
  -H "Authorization: Bearer $TOKEN"
```

**Test Token Refresh:**
```bash
curl -X POST http://localhost:8080/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"your_refresh_token"}'
```

### Rate Limiting Testing

```bash
# Trigger rate limit (run 6 times quickly)
for i in {1..6}; do
  curl -X POST http://localhost:8080/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"wrong","password":"wrong"}'
  echo ""
done
```

Expected: 429 Too Many Requests after 5 attempts

### CORS Testing

```bash
# Test from allowed origin
curl -X OPTIONS http://localhost:8080/api/health \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -v

# Test from blocked origin
curl -X OPTIONS http://localhost:8080/api/health \
  -H "Origin: https://evil-site.com" \
  -H "Access-Control-Request-Method: GET" \
  -v
```

### WebSocket Testing

```javascript
// JavaScript (Browser or Node.js)
const token = 'your_access_token';
const ws = new WebSocket(`ws://localhost:8080?token=${token}`);

ws.onopen = () => {
  console.log('Connected');

  // Subscribe to prices
  ws.send(JSON.stringify({
    type: 'subscribe_prices',
    payload: {
      symbols: ['EURUSD', 'GBPUSD']
    }
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = () => {
  console.log('Disconnected');
};
```

---

## 10. Troubleshooting

### Authentication Issues

**Problem:** "Invalid or expired token"
**Solution:**
- Verify token hasn't expired (check `exp` claim)
- Ensure JWT_SECRET matches between login and validation
- Check token format: `Bearer <token>`

**Problem:** "Invalid credentials"
**Solution:**
- Verify username and password
- Check passwordHash in `middleware/auth.js`
- Ensure bcrypt is working correctly

### Rate Limiting Issues

**Problem:** "Too many requests" unexpectedly
**Solution:**
- Check rate limit configuration in `middleware/rateLimit.js`
- Verify IP address (use `req.ip` logging)
- If behind proxy, set `TRUST_PROXY=true`

### CORS Issues

**Problem:** "Not allowed by CORS policy"
**Solution:**
- Add origin to whitelist in `middleware/corsConfig.js`
- Or add to ALLOWED_ORIGINS environment variable
- Verify NODE_ENV setting (development vs production)

**Problem:** Preflight OPTIONS request fails
**Solution:**
- Ensure OPTIONS method is allowed
- Check `Access-Control-Allow-Methods` header
- Verify preflight cache settings

### WebSocket Issues

**Problem:** WebSocket connection closes immediately
**Solution:**
- Verify token is included in connection URL: `?token=<token>`
- Check token validity
- Review WebSocket authentication logs

**Problem:** Messages not validated
**Solution:**
- Check message format matches expected structure
- Review validation errors in logs
- Verify symbol format (6 uppercase letters)

---

## 11. Security Best Practices

### Credential Management

1. **Never commit credentials:**
   - Use .env for secrets
   - .env is gitignored
   - Use .env.example as template

2. **Rotate secrets regularly:**
   - Change JWT_SECRET every 90 days
   - Change admin password monthly
   - Rotate API keys quarterly

3. **Use strong passwords:**
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Use password manager

### Network Security

1. **Always use HTTPS in production**
2. **Enable HSTS header** (Helmet does this)
3. **Implement certificate pinning** (mobile apps)
4. **Use VPN or firewall** to restrict access

### Monitoring

1. **Monitor authentication failures** (potential attacks)
2. **Alert on rate limit exceeded** (DoS attempts)
3. **Track API usage patterns** (anomaly detection)
4. **Log all security events** (audit trail)

### Incident Response

1. **Have rollback plan** ready
2. **Know how to revoke tokens** (future: Redis blacklist)
3. **Document security contacts**
4. **Test incident response procedures**

---

## 12. References

- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [Express Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)
- [Helmet.js Documentation](https://helmetjs.github.io/)
- [CORS Specification](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)

---

## Change Log

| Date       | Version | Changes |
|------------|---------|---------|
| 2025-01-12 | 2.0     | Complete security hardening implementation |
| 2025-01-07 | 1.0     | Initial bridge server (insecure) |

---

**Questions?** Open an issue with the `bridge` or `security` label.
