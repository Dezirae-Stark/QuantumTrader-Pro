# Environment Configuration Guide

## Overview

This guide explains how to configure QuantumTrader Pro for different environments (development, staging, demo, production). Each environment has specific requirements and best practices to ensure security, performance, and reliability.

## Table of Contents

- [Environment Types](#environment-types)
- [Quick Setup](#quick-setup)
- [Development Environment](#development-environment)
- [Demo Environment](#demo-environment)
- [Staging Environment](#staging-environment)
- [Production Environment](#production-environment)
- [Configuration Validation](#configuration-validation)
- [Environment Migration](#environment-migration)
- [Troubleshooting](#troubleshooting)

## Environment Types

QuantumTrader Pro supports four distinct environment types:

### Development

**Purpose:** Local development and testing

**Characteristics:**
- Relaxed validation
- Mock services enabled
- Synthetic data allowed
- Debug mode enabled
- Hot reload enabled
- Verbose logging

**Use Cases:**
- Feature development
- Bug fixing
- Local testing
- Experimentation

### Demo

**Purpose:** Demonstrations and non-production testing

**Characteristics:**
- Standard validation
- Synthetic data allowed
- Debug mode optional
- Real-like behavior
- Safe for demos

**Use Cases:**
- Product demonstrations
- Client presentations
- Training sessions
- Feature showcasing

### Staging

**Purpose:** Pre-production testing environment

**Characteristics:**
- Strict validation
- Production-like configuration
- Real broker (demo accounts)
- Debug mode optional
- Mirror production settings

**Use Cases:**
- Integration testing
- Performance testing
- Release candidate validation
- Deployment rehearsal

### Production

**Purpose:** Live trading environment

**Characteristics:**
- Maximum security
- Strict validation
- No synthetic data
- No debug mode
- Real broker accounts
- Full monitoring

**Use Cases:**
- Live trading
- Real money operations
- Production workloads

## Quick Setup

### 1. Choose Your Environment

```bash
# Set environment variable
export ENV=development  # or demo, staging, production
```

### 2. Create Environment File

```bash
# Copy template for your environment
cp .env.example .env.development

# Edit with your configuration
nano .env.development

# Link to active environment
ln -sf .env.development .env
```

### 3. Configure Minimum Requirements

```bash
# .env.development
ENV=development
DEBUG=true
BROKER_PROVIDER=mt4
BROKER_API_URL=http://localhost:8080
```

### 4. Validate Configuration

```bash
# Run validation script
python backend/config_validator.py --env development

# Or use the make command
make validate-config
```

### 5. Start Application

```bash
# Start with configuration file
python ml/predictor_daemon_v2.py --config configs/config.yaml

# Or use docker-compose
docker-compose up -d
```

## Development Environment

### Configuration

Create `.env.development` with the following settings:

```bash
# =====================================================================
# DEVELOPMENT ENVIRONMENT
# =====================================================================

# Environment Settings
ENV=development
DEBUG=true
APP_VERSION=2.1.0

# Data Source Configuration
USE_SYNTHETIC_DATA=true
ALLOW_CACHED_DATA=true
CACHED_DATA_MAX_AGE_SECONDS=300
FAIL_ON_DATA_ERROR=false
WARN_ON_STALE_DATA=true
STALE_DATA_THRESHOLD_SECONDS=120

# Broker Configuration
BROKER_PROVIDER=mt4
BROKER_API_URL=http://localhost:8080
BROKER_TIMEOUT_SECONDS=30
BROKER_MAX_RETRIES=3

# Mock Broker (recommended for development)
DEV_MOCK_BROKER=true

# Authentication & Security (weak secrets OK for dev)
REQUIRE_AUTHENTICATION=false
JWT_SECRET=dev_jwt_secret_not_for_production
SESSION_SECRET=dev_session_secret_not_for_production
JWT_EXPIRES_HOURS=24

# API Server Configuration
API_HOST=localhost
API_PORT=8080
NODE_ENV=development
CORS_ENABLED=true
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost:5000

# Rate Limiting (relaxed)
RATE_LIMIT_PER_MINUTE=1000
AUTH_RATE_LIMIT_PER_MINUTE=100
TRADE_RATE_LIMIT_PER_MINUTE=100

# Validation & Schema (relaxed)
STRICT_SCHEMA_VALIDATION=false
LOG_VALIDATION_ERRORS=true
RETURN_VALIDATION_ERRORS=true  # Show detailed errors

# Machine Learning Engine
ML_CONFIDENCE_THRESHOLD=50.0  # Lower threshold for testing
QUANTUM_CONFIDENCE_THRESHOLD=50.0
ML_PREDICTION_WINDOW=8
ENABLE_QUANTUM_FEATURES=true
ENABLE_CHAOS_FEATURES=true

# Trading Parameters (safe defaults)
MAX_RISK_PER_TRADE_PCT=1.0
MAX_DAILY_RISK_PCT=3.0
MAX_OPEN_POSITIONS=5
MAX_POSITIONS_PER_PAIR=1

# Notification Services (disabled by default)
TELEGRAM_ENABLED=false
DISCORD_ENABLED=false
EMAIL_ENABLED=false
SLACK_ENABLED=false

# Logging Configuration
LOG_LEVEL=DEBUG
LOG_TO_FILE=true
LOG_FILE=./logs/dev-quantumtrader.log
LOG_TO_CONSOLE=true
LOG_LEVEL_BACKEND=DEBUG
LOG_LEVEL_ML=DEBUG
LOG_LEVEL_BROKERS=DEBUG

# Monitoring & Metrics
ENABLE_METRICS=true
METRICS_PORT=9090
PERFORMANCE_TRACKING=true

# Database Configuration
DATABASE_TYPE=sqlite
SQLITE_DB_PATH=./data/dev-quantumtrader.db

# Redis Configuration (optional)
REDIS_ENABLED=false

# Development Settings
DEV_HOT_RELOAD=true
DEV_MOCK_BROKER=true
DEV_SYNTHETIC_DATA=true
DEV_SKIP_VALIDATION=false
DEV_VERBOSE_LOGGING=true

# Feature Flags (all enabled for testing)
FEATURE_QUANTUM_PREDICTIONS=true
FEATURE_ML_PREDICTIONS=true
FEATURE_CHAOS_ANALYSIS=true
FEATURE_CANTILEVER_HEDGE=true
FEATURE_AUTO_TRADING=false  # Disabled to prevent accidents
FEATURE_BACKTESTING=true
FEATURE_TELEGRAM_BOT=false
FEATURE_WEB_DASHBOARD=true
```

### Setup Steps

1. **Install dependencies:**
   ```bash
   # Python dependencies
   pip install -r requirements.txt

   # Flutter dependencies
   flutter pub get
   ```

2. **Start mock broker:**
   ```bash
   # Start local MT4 bridge
   cd bridge
   python mt4_bridge_server.py --port 8080 --mock
   ```

3. **Initialize database:**
   ```bash
   # Create database and tables
   python backend/init_db.py
   ```

4. **Generate test data:**
   ```bash
   # Generate synthetic market data
   python scripts/generate_test_data.py --days 30
   ```

5. **Start application:**
   ```bash
   # Start backend
   python ml/predictor_daemon_v2.py --config configs/config.yaml

   # Start Flutter desktop app (separate terminal)
   flutter run -d linux  # or windows, macos
   ```

### Development Best Practices

1. **Use mock services:**
   - Enable `DEV_MOCK_BROKER=true`
   - Use synthetic data for predictable testing
   - Avoid real broker connections

2. **Enable verbose logging:**
   - Set `LOG_LEVEL=DEBUG`
   - Enable `DEV_VERBOSE_LOGGING=true`
   - Monitor logs: `tail -f logs/dev-quantumtrader.log`

3. **Fast iteration:**
   - Enable `DEV_HOT_RELOAD=true`
   - Use `DEV_SKIP_VALIDATION=false` (keep validation for safety)
   - Return detailed errors with `RETURN_VALIDATION_ERRORS=true`

4. **Disable auto-trading:**
   - Set `FEATURE_AUTO_TRADING=false`
   - Prevents accidental trades during development
   - Use manual trigger for testing trades

5. **Separate database:**
   - Use `dev-quantumtrader.db` instead of `quantumtrader.db`
   - Prevents contaminating production data
   - Easy to reset: `rm data/dev-quantumtrader.db`

## Demo Environment

### Configuration

Create `.env.demo` with production-like settings but synthetic data allowed:

```bash
# =====================================================================
# DEMO ENVIRONMENT
# =====================================================================

# Environment Settings
ENV=demo
DEBUG=false
APP_VERSION=2.1.0

# Data Source Configuration
USE_SYNTHETIC_DATA=true  # Allowed for demos
ALLOW_CACHED_DATA=true
FAIL_ON_DATA_ERROR=false
WARN_ON_STALE_DATA=true

# Broker Configuration (can use demo account or mock)
BROKER_PROVIDER=mt4
BROKER_API_URL=http://demo-broker.example.com
BROKER_SERVER=LHFXDemo-Server
BROKER_ACCOUNT=194302
BROKER_PASSWORD=<demo_password>

# Authentication & Security
REQUIRE_AUTHENTICATION=true
JWT_SECRET=<generate_unique_secret>
SESSION_SECRET=<generate_unique_secret>
JWT_EXPIRES_HOURS=24

# API Server Configuration
API_HOST=0.0.0.0
API_PORT=8080
NODE_ENV=demo
CORS_ENABLED=true

# Rate Limiting (standard)
RATE_LIMIT_PER_MINUTE=100
AUTH_RATE_LIMIT_PER_MINUTE=10
TRADE_RATE_LIMIT_PER_MINUTE=30

# Validation & Schema
STRICT_SCHEMA_VALIDATION=true
LOG_VALIDATION_ERRORS=true
RETURN_VALIDATION_ERRORS=false

# Machine Learning Engine
ML_CONFIDENCE_THRESHOLD=70.0
QUANTUM_CONFIDENCE_THRESHOLD=65.0

# Trading Parameters
MAX_RISK_PER_TRADE_PCT=2.0
MAX_DAILY_RISK_PCT=5.0
MAX_OPEN_POSITIONS=10

# Notification Services (optional)
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=<your_demo_bot_token>
TELEGRAM_CHAT_ID=<your_chat_id>
TELEGRAM_NOTIFICATION_LEVEL=important

# Logging Configuration
LOG_LEVEL=INFO
LOG_TO_FILE=true
LOG_FILE=./logs/demo-quantumtrader.log
LOG_TO_CONSOLE=true

# Database Configuration
DATABASE_TYPE=sqlite
SQLITE_DB_PATH=./data/demo-quantumtrader.db

# Feature Flags
FEATURE_QUANTUM_PREDICTIONS=true
FEATURE_ML_PREDICTIONS=true
FEATURE_AUTO_TRADING=true
FEATURE_WEB_DASHBOARD=true
```

### Demo Setup

1. **Prepare demo data:**
   ```bash
   # Generate realistic demo data
   python scripts/generate_demo_data.py --realistic --days 90
   ```

2. **Configure demo broker:**
   ```bash
   # Use broker's demo account credentials
   # Or start mock broker with demo mode
   python bridge/mt4_bridge_server.py --demo
   ```

3. **Test all features:**
   ```bash
   # Run feature tests
   pytest tests/features/ -v
   ```

4. **Start demo server:**
   ```bash
   docker-compose -f docker-compose.demo.yml up -d
   ```

### Demo Best Practices

1. **Use realistic data:**
   - Generate data that mimics real market conditions
   - Include various market scenarios (trending, ranging, volatile)

2. **Enable all features:**
   - Show full capabilities of the system
   - Demonstrate quantum predictions, ML signals, etc.

3. **Safe configuration:**
   - Use demo broker accounts only
   - Keep risk parameters conservative
   - Prevent real money exposure

## Staging Environment

### Configuration

Create `.env.staging` that mirrors production:

```bash
# =====================================================================
# STAGING ENVIRONMENT
# =====================================================================

# Environment Settings
ENV=staging
DEBUG=false
APP_VERSION=2.1.0

# Data Source Configuration (no synthetic data!)
USE_SYNTHETIC_DATA=false
ALLOW_CACHED_DATA=false
FAIL_ON_DATA_ERROR=true
WARN_ON_STALE_DATA=true
STALE_DATA_THRESHOLD_SECONDS=60

# Broker Configuration (use staging/demo broker)
BROKER_PROVIDER=mt4
BROKER_API_URL=https://staging-broker-api.example.com
BROKER_API_KEY=<staging_broker_key>
BROKER_API_SECRET=<staging_broker_secret>
BROKER_SERVER=LHFXDemo-Server
BROKER_ACCOUNT=<staging_account>
BROKER_PASSWORD=<staging_password>
BROKER_TIMEOUT_SECONDS=30
BROKER_MAX_RETRIES=3

# Authentication & Security (use unique secrets!)
REQUIRE_AUTHENTICATION=true
JWT_SECRET=<generate_unique_staging_secret>
SESSION_SECRET=<generate_unique_staging_secret>
JWT_EXPIRES_HOURS=24
JWT_ALGORITHM=HS256

# API Server Configuration
API_HOST=0.0.0.0
API_PORT=8080
NODE_ENV=staging
CORS_ENABLED=true
ALLOWED_ORIGINS=https://staging.example.com

# Rate Limiting (production values)
RATE_LIMIT_PER_MINUTE=100
AUTH_RATE_LIMIT_PER_MINUTE=5
TRADE_RATE_LIMIT_PER_MINUTE=30

# Validation & Schema (strict!)
STRICT_SCHEMA_VALIDATION=true
LOG_VALIDATION_ERRORS=true
RETURN_VALIDATION_ERRORS=false

# Machine Learning Engine (production values)
ML_CONFIDENCE_THRESHOLD=75.0
QUANTUM_CONFIDENCE_THRESHOLD=70.0
ML_PREDICTION_WINDOW=8
MAX_PRICE_MOVE_PCT=10.0

# Trading Parameters (production values)
MAX_RISK_PER_TRADE_PCT=2.0
MAX_DAILY_RISK_PCT=5.0
MAX_OPEN_POSITIONS=10
MAX_POSITIONS_PER_PAIR=2
MAX_SPREAD_PIPS=3.0
MIN_STOP_LOSS_PIPS=20.0

# Notification Services (enabled)
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=<staging_bot_token>
TELEGRAM_CHAT_ID=<staging_chat_id>
TELEGRAM_NOTIFICATION_LEVEL=important

DISCORD_ENABLED=true
DISCORD_WEBHOOK_URL=<staging_webhook>
DISCORD_NOTIFICATION_LEVEL=important

EMAIL_ENABLED=true
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=<staging_email>
SMTP_PASSWORD=<staging_smtp_password>
EMAIL_FROM=<staging_email>
EMAIL_TO=<team_email>
EMAIL_NOTIFICATION_LEVEL=critical

# Logging Configuration (INFO level)
LOG_LEVEL=INFO
LOG_TO_FILE=true
LOG_FILE=./logs/staging-quantumtrader.log
LOG_MAX_FILE_SIZE_MB=100
LOG_BACKUP_COUNT=10
LOG_TO_CONSOLE=true

# Monitoring & Metrics
ENABLE_METRICS=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL_SECONDS=60
PERFORMANCE_TRACKING=true

# Database Configuration (PostgreSQL for staging)
DATABASE_TYPE=postgresql
POSTGRES_HOST=staging-db.example.com
POSTGRES_PORT=5432
POSTGRES_USER=quantumtrader
POSTGRES_PASSWORD=<staging_db_password>
POSTGRES_DB=quantumtrader_staging
POSTGRES_SSL_MODE=require
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20

# Redis Configuration
REDIS_ENABLED=true
REDIS_HOST=staging-redis.example.com
REDIS_PORT=6379
REDIS_PASSWORD=<staging_redis_password>
REDIS_DB=0
REDIS_SSL=true
REDIS_CACHE_TTL=300

# External Services
SENTRY_ENABLED=true
SENTRY_DSN=<staging_sentry_dsn>
SENTRY_ENVIRONMENT=staging

# Feature Flags (all enabled for testing)
FEATURE_QUANTUM_PREDICTIONS=true
FEATURE_ML_PREDICTIONS=true
FEATURE_CHAOS_ANALYSIS=true
FEATURE_CANTILEVER_HEDGE=true
FEATURE_AUTO_TRADING=true
FEATURE_BACKTESTING=true
FEATURE_TELEGRAM_BOT=true
FEATURE_WEB_DASHBOARD=true
```

### Staging Setup

1. **Provision infrastructure:**
   ```bash
   # Use Terraform or similar
   terraform apply -var-file=staging.tfvars
   ```

2. **Deploy application:**
   ```bash
   # Build Docker image
   docker build -t quantumtrader-pro:staging .

   # Deploy to staging
   docker-compose -f docker-compose.staging.yml up -d
   ```

3. **Run migrations:**
   ```bash
   # Apply database migrations
   alembic upgrade head
   ```

4. **Verify deployment:**
   ```bash
   # Health check
   curl https://staging.example.com/health

   # Run smoke tests
   pytest tests/smoke/ --env=staging
   ```

### Staging Best Practices

1. **Mirror production:**
   - Use same configuration structure as production
   - Use similar infrastructure (databases, caching, etc.)
   - Test with production-like data volumes

2. **Separate credentials:**
   - Never use production credentials
   - Use dedicated staging broker accounts
   - Separate databases and services

3. **Comprehensive testing:**
   - Integration tests
   - Performance tests
   - Security tests
   - End-to-end tests

4. **Deployment rehearsal:**
   - Practice deployment procedures
   - Test rollback procedures
   - Verify monitoring and alerting

## Production Environment

### Configuration

Create `.env.production` with maximum security:

```bash
# =====================================================================
# PRODUCTION ENVIRONMENT
# =====================================================================

# Environment Settings
ENV=production
DEBUG=false  # NEVER enable debug in production!
APP_VERSION=2.1.0

# Data Source Configuration (STRICT!)
USE_SYNTHETIC_DATA=false  # CRITICAL: Must be false!
ALLOW_CACHED_DATA=false
FAIL_ON_DATA_ERROR=true
WARN_ON_STALE_DATA=true
STALE_DATA_THRESHOLD_SECONDS=60

# Broker Configuration (REAL CREDENTIALS!)
BROKER_PROVIDER=mt4
BROKER_API_URL=https://broker-api.example.com
BROKER_API_KEY=<production_broker_key>
BROKER_API_SECRET=<production_broker_secret>
BROKER_SERVER=<production_server>
BROKER_ACCOUNT=<production_account>
BROKER_PASSWORD=<production_password>
BROKER_TIMEOUT_SECONDS=30
BROKER_MAX_RETRIES=3
BROKER_RETRY_DELAY_SECONDS=5

# Authentication & Security (STRONG SECRETS!)
REQUIRE_AUTHENTICATION=true
JWT_SECRET=<openssl_rand_hex_32>
SESSION_SECRET=<openssl_rand_hex_32>
JWT_EXPIRES_HOURS=24
JWT_ALGORITHM=HS256

# API Keys for external access
API_KEY=<openssl_rand_hex_24>
API_SECRET=<openssl_rand_hex_24>

# API Server Configuration
API_HOST=0.0.0.0
API_PORT=8080
NODE_ENV=production
CORS_ENABLED=true
ALLOWED_ORIGINS=https://quantumtrader.example.com

# Rate Limiting (strict)
RATE_LIMIT_PER_MINUTE=100
AUTH_RATE_LIMIT_PER_MINUTE=5
TRADE_RATE_LIMIT_PER_MINUTE=30
RATE_LIMIT_WINDOW_MS=60000

# Validation & Schema (STRICT!)
STRICT_SCHEMA_VALIDATION=true
LOG_VALIDATION_ERRORS=true
RETURN_VALIDATION_ERRORS=false  # Don't expose internals

# Machine Learning Engine
ML_CONFIDENCE_THRESHOLD=75.0
QUANTUM_CONFIDENCE_THRESHOLD=70.0
ML_PREDICTION_WINDOW=8
MAX_PRICE_MOVE_PCT=10.0
MIN_PREDICTION_CONFIDENCE=50.0

# Feature Engineering
ENABLE_TREND_INDICATORS=true
ENABLE_MOMENTUM_INDICATORS=true
ENABLE_VOLATILITY_INDICATORS=true
ENABLE_VOLUME_INDICATORS=true
ENABLE_QUANTUM_FEATURES=true
ENABLE_CHAOS_FEATURES=true

# Trading Parameters
MAX_RISK_PER_TRADE_PCT=2.0
MAX_DAILY_RISK_PCT=5.0
MAX_OPEN_POSITIONS=10
MAX_POSITIONS_PER_PAIR=2
MAX_SPREAD_PIPS=3.0
MIN_STOP_LOSS_PIPS=20.0
SLIPPAGE_TOLERANCE_PIPS=2.0

# Signal Filtering
ENABLE_QUANTUM_SIGNALS=true
ENABLE_ML_SIGNALS=true
ENABLE_CANTILEVER_HEDGE=true

# Position Management
USE_TRAILING_STOP=true
TRAILING_STOP_DISTANCE_PIPS=50.0
BREAK_EVEN_PIPS=30.0

# Notification Services (ALL ENABLED!)
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=<production_bot_token>
TELEGRAM_CHAT_ID=<production_chat_id>
TELEGRAM_NOTIFICATION_LEVEL=important

DISCORD_ENABLED=true
DISCORD_WEBHOOK_URL=<production_webhook>
DISCORD_USERNAME=QuantumTrader Pro
DISCORD_NOTIFICATION_LEVEL=important

EMAIL_ENABLED=true
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USE_TLS=true
SMTP_USERNAME=<production_email>
SMTP_PASSWORD=<production_smtp_app_password>
EMAIL_FROM=<production_email>
EMAIL_TO=<admin_email>
EMAIL_NOTIFICATION_LEVEL=critical

SLACK_ENABLED=true
SLACK_WEBHOOK_URL=<production_slack_webhook>
SLACK_CHANNEL=#trading-alerts
SLACK_NOTIFICATION_LEVEL=important

# Logging Configuration
LOG_LEVEL=INFO  # or WARNING for less verbosity
LOG_FORMAT=%(asctime)s - %(name)s - %(levelname)s - %(message)s
LOG_TO_FILE=true
LOG_FILE=./logs/quantumtrader.log
LOG_MAX_FILE_SIZE_MB=100
LOG_BACKUP_COUNT=10
LOG_TO_CONSOLE=true
LOG_LEVEL_BACKEND=INFO
LOG_LEVEL_ML=INFO
LOG_LEVEL_BROKERS=INFO

# Monitoring & Metrics (CRITICAL!)
ENABLE_METRICS=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL_SECONDS=60
PERFORMANCE_TRACKING=true
PROMETHEUS_ENABLED=true
PROMETHEUS_PORT=9090

# Database Configuration (PostgreSQL for production)
DATABASE_TYPE=postgresql
POSTGRES_HOST=prod-db.example.com
POSTGRES_PORT=5432
POSTGRES_USER=quantumtrader
POSTGRES_PASSWORD=<strong_production_db_password>
POSTGRES_DB=quantumtrader
POSTGRES_SSL_MODE=require
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=40
DB_POOL_TIMEOUT=30

# Redis Configuration (CRITICAL for caching)
REDIS_ENABLED=true
REDIS_HOST=prod-redis.example.com
REDIS_PORT=6379
REDIS_PASSWORD=<strong_production_redis_password>
REDIS_DB=0
REDIS_SSL=true
REDIS_CACHE_TTL=300

# External Services
CODECOV_TOKEN=<codecov_token>

SENTRY_ENABLED=true
SENTRY_DSN=<production_sentry_dsn>
SENTRY_ENVIRONMENT=production

ANALYTICS_ENABLED=true
ANALYTICS_ID=<production_analytics_id>

# Cloud Storage (for backups)
AWS_ACCESS_KEY_ID=<aws_access_key>
AWS_SECRET_ACCESS_KEY=<aws_secret_key>
AWS_S3_BUCKET=quantumtrader-backups
AWS_REGION=us-east-1

# Feature Flags
FEATURE_QUANTUM_PREDICTIONS=true
FEATURE_ML_PREDICTIONS=true
FEATURE_CHAOS_ANALYSIS=true
FEATURE_CANTILEVER_HEDGE=true
FEATURE_AUTO_TRADING=true  # Enable only when ready!
FEATURE_BACKTESTING=true
FEATURE_TELEGRAM_BOT=true
FEATURE_WEB_DASHBOARD=true
```

### Production Setup

1. **Pre-deployment checklist:**
   ```bash
   # Create checklist file
   cat > production-deployment-checklist.txt << 'EOF'
   [ ] All secrets generated with strong randomness
   [ ] USE_SYNTHETIC_DATA=false
   [ ] DEBUG=false
   [ ] REQUIRE_AUTHENTICATION=true
   [ ] Strong JWT_SECRET (32+ bytes)
   [ ] Strong SESSION_SECRET (32+ bytes)
   [ ] Real broker credentials configured and tested
   [ ] Database credentials rotated
   [ ] Redis credentials set
   [ ] All notification services configured
   [ ] Monitoring and alerting configured
   [ ] Backups configured and tested
   [ ] SSL/TLS certificates installed
   [ ] Firewall rules configured
   [ ] Rate limiting configured
   [ ] Log rotation configured
   [ ] .env file permissions set to 600
   [ ] .env not committed to git
   [ ] Secrets stored in vault/GitHub Secrets
   [ ] Deployment tested in staging
   [ ] Rollback plan documented
   [ ] Team notified of deployment
   EOF
   ```

2. **Validate production configuration:**
   ```bash
   # Run comprehensive validation
   python backend/config_validator.py --env production --strict

   # Check secret strength
   python scripts/check_secrets_strength.py .env.production

   # Verify production mode
   python scripts/verify_production_config.py
   ```

3. **Secure .env file:**
   ```bash
   # Set restrictive permissions
   chmod 600 .env.production

   # Verify ownership
   chown appuser:appuser .env.production

   # Verify permissions
   ls -l .env.production
   # Should show: -rw------- (600)
   ```

4. **Deploy application:**
   ```bash
   # Build production image
   docker build -t quantumtrader-pro:v2.1.0 -f Dockerfile.prod .

   # Deploy
   docker-compose -f docker-compose.prod.yml up -d

   # Or use Kubernetes
   kubectl apply -f k8s/production/
   ```

5. **Post-deployment verification:**
   ```bash
   # Health check
   curl https://api.quantumtrader.example.com/health

   # Test authentication
   curl -X POST https://api.quantumtrader.example.com/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"test"}'

   # Check metrics
   curl http://localhost:9090/metrics

   # Monitor logs
   tail -f logs/quantumtrader.log

   # Run smoke tests
   pytest tests/smoke/ --env=production --no-modify
   ```

### Production Best Practices

1. **Security first:**
   - Use strong, unique secrets (minimum 32 bytes)
   - Never enable DEBUG mode
   - Never use synthetic data
   - Rotate credentials regularly
   - Use TLS/SSL everywhere
   - Implement rate limiting
   - Use firewall rules
   - Enable authentication

2. **Monitoring and alerting:**
   - Configure Sentry for error tracking
   - Enable Prometheus metrics
   - Set up health checks
   - Configure notification services
   - Monitor trading performance
   - Alert on critical issues

3. **Data integrity:**
   - Disable synthetic data
   - Fail fast on data errors
   - Validate all inputs strictly
   - Monitor data quality
   - Log data issues

4. **Backup and recovery:**
   - Automated database backups
   - Encrypted backup storage
   - Test restore procedures
   - Document recovery process
   - Maintain backup retention policy

5. **High availability:**
   - Use load balancers
   - Implement health checks
   - Configure auto-restart
   - Use connection pooling
   - Implement graceful shutdown

## Configuration Validation

### Automated Validation

Create `backend/config_validator.py`:

```python
#!/usr/bin/env python3
import os
import sys
from dotenv import load_dotenv

def validate_config(env='production', strict=False):
    """Validate environment configuration."""
    errors = []
    warnings = []

    # Load .env file
    env_file = f'.env.{env}' if env != 'production' else '.env'
    if not os.path.exists(env_file):
        errors.append(f"Environment file not found: {env_file}")
        return errors, warnings

    load_dotenv(env_file)

    # Get environment mode
    env_mode = os.environ.get('ENV')

    # Critical validations
    if env_mode == 'production':
        # Check USE_SYNTHETIC_DATA
        if os.environ.get('USE_SYNTHETIC_DATA', '').lower() == 'true':
            errors.append("CRITICAL: USE_SYNTHETIC_DATA must be false in production!")

        # Check DEBUG
        if os.environ.get('DEBUG', '').lower() == 'true':
            errors.append("CRITICAL: DEBUG must be false in production!")

        # Check JWT_SECRET strength
        jwt_secret = os.environ.get('JWT_SECRET', '')
        if len(jwt_secret) < 32:
            errors.append(f"CRITICAL: JWT_SECRET too weak ({len(jwt_secret)} chars, need 32+)")

        # Check SESSION_SECRET strength
        session_secret = os.environ.get('SESSION_SECRET', '')
        if len(session_secret) < 32:
            errors.append(f"CRITICAL: SESSION_SECRET too weak ({len(session_secret)} chars, need 32+)")

        # Check REQUIRE_AUTHENTICATION
        if os.environ.get('REQUIRE_AUTHENTICATION', '').lower() != 'true':
            errors.append("CRITICAL: REQUIRE_AUTHENTICATION must be true in production!")

    # Required variables
    required_vars = [
        'ENV',
        'BROKER_PROVIDER',
        'BROKER_API_URL',
        'JWT_SECRET',
        'SESSION_SECRET',
    ]

    for var in required_vars:
        if not os.environ.get(var):
            errors.append(f"Required variable not set: {var}")

    # Broker validation
    broker_provider = os.environ.get('BROKER_PROVIDER')
    if broker_provider in ['mt4', 'mt5']:
        if not os.environ.get('BROKER_ACCOUNT'):
            warnings.append("BROKER_ACCOUNT not set for MT4/MT5")

    # Print results
    if errors:
        print("❌ VALIDATION ERRORS:")
        for error in errors:
            print(f"  - {error}")

    if warnings:
        print("\n⚠️  WARNINGS:")
        for warning in warnings:
            print(f"  - {warning}")

    if not errors and not warnings:
        print("✅ Configuration validation passed!")

    return errors, warnings

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Validate environment configuration')
    parser.add_argument('--env', default='production',
                        help='Environment to validate (development, staging, production)')
    parser.add_argument('--strict', action='store_true',
                        help='Treat warnings as errors')
    args = parser.parse_args()

    errors, warnings = validate_config(args.env, args.strict)

    if errors or (args.strict and warnings):
        sys.exit(1)
```

### Usage

```bash
# Validate production configuration
python backend/config_validator.py --env production --strict

# Validate development configuration
python backend/config_validator.py --env development

# Add to CI/CD
make validate-config
```

## Environment Migration

### Development → Staging

```bash
# 1. Copy development config
cp .env.development .env.staging

# 2. Update critical settings
sed -i 's/ENV=development/ENV=staging/' .env.staging
sed -i 's/DEBUG=true/DEBUG=false/' .env.staging
sed -i 's/USE_SYNTHETIC_DATA=true/USE_SYNTHETIC_DATA=false/' .env.staging

# 3. Update secrets
python scripts/generate_secrets.py --env staging

# 4. Update broker to staging/demo account
# Edit .env.staging manually

# 5. Validate
python backend/config_validator.py --env staging --strict
```

### Staging → Production

```bash
# 1. Copy staging config (DO NOT copy secrets!)
cp .env.staging .env.production

# 2. Generate NEW production secrets (never reuse!)
JWT_SECRET=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)

# 3. Update .env.production with production values
sed -i 's/ENV=staging/ENV=production/' .env.production
sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env.production
sed -i "s/SESSION_SECRET=.*/SESSION_SECRET=$SESSION_SECRET/" .env.production

# 4. Update broker to production account
# Edit BROKER_API_KEY, BROKER_API_SECRET, BROKER_ACCOUNT

# 5. Update database to production
# Edit POSTGRES_HOST, POSTGRES_PASSWORD

# 6. Secure file
chmod 600 .env.production

# 7. Validate
python backend/config_validator.py --env production --strict

# 8. Test in staging first!
# Deploy to staging with production config
# Run full test suite
# Only then deploy to production
```

## Troubleshooting

### Application Won't Start

**Error:** Configuration validation failed

**Solutions:**

```bash
# 1. Check .env file exists
ls -la .env

# 2. Verify .env format
cat .env | head -20

# 3. Run validator
python backend/config_validator.py

# 4. Check for missing variables
python -c "
from dotenv import load_dotenv
import os
load_dotenv()
required = ['ENV', 'BROKER_PROVIDER', 'BROKER_API_URL', 'JWT_SECRET']
for var in required:
    if not os.environ.get(var):
        print(f'Missing: {var}')
"
```

### Wrong Environment Loaded

**Problem:** Application using wrong configuration

**Solutions:**

```bash
# 1. Check which .env is linked
ls -la .env

# 2. Verify ENV variable
grep "^ENV=" .env

# 3. Explicitly set environment
export ENV=production
python ml/predictor_daemon_v2.py --config configs/config.yaml

# 4. Check for environment variable override
env | grep ENV
```

### Secrets Not Working

**Problem:** Authentication failing or broker connection failing

**Solutions:**

```bash
# 1. Verify secret format
grep "JWT_SECRET" .env
# Should not have spaces: JWT_SECRET=value

# 2. Check secret strength
python scripts/check_secrets_strength.py .env

# 3. Regenerate secrets
openssl rand -hex 32

# 4. Verify secrets loaded
python -c "
import os
from dotenv import load_dotenv
load_dotenv()
jwt = os.environ.get('JWT_SECRET')
print(f'JWT_SECRET length: {len(jwt) if jwt else 0}')
print(f'JWT_SECRET preview: {jwt[:10]}...' if jwt else 'NOT SET')
"
```

## Additional Resources

- [Secrets Management Guide](SECRETS_MANAGEMENT.md)
- [GitHub Secrets Setup](GITHUB_SECRETS.md)
- [Security Best Practices](SECURITY.md)
- [Deployment Guide](DEPLOYMENT.md)
- [12-Factor App Methodology](https://12factor.net/)

---

**Last Updated:** 2025-11-20
**Version:** 2.1.0
