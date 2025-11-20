# Secrets Management Guide

## Overview

This guide provides comprehensive instructions for managing secrets, API keys, credentials, and sensitive configuration data in QuantumTrader Pro. Proper secrets management is critical for security and compliance.

## Table of Contents

- [Quick Start](#quick-start)
- [Environment Configuration](#environment-configuration)
- [Secret Types](#secret-types)
- [Local Development](#local-development)
- [Production Deployment](#production-deployment)
- [GitHub Secrets](#github-secrets)
- [Secret Rotation](#secret-rotation)
- [Cloud Secret Managers](#cloud-secret-managers)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Initial Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Generate strong secrets:**
   ```bash
   # Generate JWT secret
   openssl rand -hex 32

   # Generate session secret
   openssl rand -hex 32

   # Generate API key
   openssl rand -hex 24
   ```

3. **Configure your .env file:**
   ```bash
   # Edit with your preferred editor
   nano .env

   # Set minimum required variables
   ENV=development
   JWT_SECRET=<your_generated_secret>
   SESSION_SECRET=<your_generated_secret>
   BROKER_API_KEY=<your_broker_api_key>
   BROKER_API_SECRET=<your_broker_api_secret>
   ```

4. **Verify .env is in .gitignore:**
   ```bash
   grep "^\.env$" .gitignore
   # Should return: .env
   ```

## Environment Configuration

### Environment Modes

QuantumTrader Pro supports four environment modes:

| Environment | Use Case | Synthetic Data | Debug Mode | Validation |
|------------|----------|----------------|------------|------------|
| `development` | Local development | Allowed | Enabled | Relaxed |
| `demo` | Testing/demos | Allowed | Optional | Standard |
| `staging` | Pre-production | Not recommended | Optional | Strict |
| `production` | Live trading | **NEVER** | Disabled | Strict |

### Environment-Specific Files

Maintain separate environment files:

```
.env.development    # Local development (commit to git without secrets)
.env.demo          # Demo environment (never commit)
.env.staging       # Staging environment (never commit)
.env.production    # Production environment (never commit)
.env               # Active environment (never commit)
```

**Usage:**
```bash
# Copy appropriate template
cp .env.production.example .env.production

# Link to active environment
ln -sf .env.production .env
```

## Secret Types

### 1. Application Secrets

**JWT_SECRET**
- **Purpose**: Signs JWT authentication tokens
- **Generation**: `openssl rand -hex 32`
- **Rotation**: Every 6 months
- **Scope**: Application-wide
- **Criticality**: HIGH

**SESSION_SECRET**
- **Purpose**: Encrypts session data
- **Generation**: `openssl rand -hex 32`
- **Rotation**: Every 6 months
- **Scope**: Web server
- **Criticality**: HIGH

### 2. Broker Credentials

**BROKER_API_KEY / BROKER_API_SECRET**
- **Purpose**: Authenticate with broker API
- **Source**: Provided by broker
- **Rotation**: Every 90 days
- **Scope**: Trading operations
- **Criticality**: CRITICAL

**BROKER_ACCOUNT / BROKER_SERVER**
- **Purpose**: Trading account identification
- **Source**: Broker account details
- **Rotation**: When account changes
- **Scope**: Trading operations
- **Criticality**: CRITICAL

### 3. Notification Service Tokens

**TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID**
- **Purpose**: Send Telegram notifications
- **Source**: BotFather on Telegram
- **Rotation**: When compromised
- **Scope**: Notifications
- **Criticality**: MEDIUM

**DISCORD_WEBHOOK_URL**
- **Purpose**: Send Discord notifications
- **Source**: Discord webhook settings
- **Rotation**: When compromised
- **Scope**: Notifications
- **Criticality**: MEDIUM

**SMTP_PASSWORD**
- **Purpose**: Send email notifications
- **Source**: Email provider
- **Rotation**: Every 90 days
- **Scope**: Notifications
- **Criticality**: MEDIUM

### 4. API Keys

**API_KEY / API_SECRET**
- **Purpose**: Secure external API access
- **Generation**: `openssl rand -hex 24`
- **Rotation**: Every 90 days
- **Scope**: External integrations
- **Criticality**: HIGH

### 5. Database Credentials

**POSTGRES_PASSWORD / MYSQL_PASSWORD**
- **Purpose**: Database authentication
- **Source**: Database setup
- **Rotation**: Every 90 days
- **Scope**: Data persistence
- **Criticality**: HIGH

**REDIS_PASSWORD**
- **Purpose**: Redis authentication
- **Source**: Redis configuration
- **Rotation**: Every 90 days
- **Scope**: Caching/sessions
- **Criticality**: MEDIUM

### 6. Cloud Service Credentials

**AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY**
- **Purpose**: AWS service access
- **Source**: AWS IAM
- **Rotation**: Every 90 days
- **Scope**: Cloud storage/services
- **Criticality**: HIGH

**GCP_PROJECT_ID / GCP_CREDENTIALS**
- **Purpose**: Google Cloud access
- **Source**: GCP Console
- **Rotation**: Every 90 days
- **Scope**: Cloud storage/services
- **Criticality**: HIGH

## Local Development

### Development Environment Setup

1. **Create development .env:**
   ```bash
   cp .env.example .env.development
   ```

2. **Configure for local development:**
   ```bash
   # .env.development
   ENV=development
   DEBUG=true

   # Use mock broker for testing
   DEV_MOCK_BROKER=true
   DEV_SYNTHETIC_DATA=true

   # Local services
   BROKER_API_URL=http://localhost:8080
   API_HOST=localhost
   API_PORT=8080

   # Development secrets (use weak secrets for dev only!)
   JWT_SECRET=dev_jwt_secret_do_not_use_in_production
   SESSION_SECRET=dev_session_secret_do_not_use_in_production

   # Disable external services
   TELEGRAM_ENABLED=false
   DISCORD_ENABLED=false
   EMAIL_ENABLED=false
   ```

3. **Link to active environment:**
   ```bash
   ln -sf .env.development .env
   ```

### Safe Development Practices

1. **Never use production secrets in development**
   - Use separate development credentials
   - Use mock services when possible
   - Enable synthetic data for testing

2. **Use local mock services**
   ```bash
   # Enable mock broker
   DEV_MOCK_BROKER=true

   # Use synthetic data
   USE_SYNTHETIC_DATA=true
   ```

3. **Disable external integrations**
   ```bash
   # Prevent accidental notifications
   TELEGRAM_ENABLED=false
   DISCORD_ENABLED=false
   EMAIL_ENABLED=false
   SENTRY_ENABLED=false
   ```

## Production Deployment

### Production Environment Setup

1. **Create production .env:**
   ```bash
   cp .env.example .env.production
   ```

2. **Configure for production:**
   ```bash
   # .env.production
   ENV=production
   DEBUG=false

   # CRITICAL: Never use synthetic data in production
   USE_SYNTHETIC_DATA=false

   # Strong authentication
   REQUIRE_AUTHENTICATION=true
   JWT_SECRET=<generate_with_openssl_rand_hex_32>
   SESSION_SECRET=<generate_with_openssl_rand_hex_32>

   # Real broker credentials
   BROKER_PROVIDER=mt4
   BROKER_API_URL=https://your-broker-api.com
   BROKER_API_KEY=<your_real_broker_key>
   BROKER_API_SECRET=<your_real_broker_secret>
   BROKER_ACCOUNT=<your_account_number>

   # Strict security settings
   STRICT_SCHEMA_VALIDATION=true
   FAIL_ON_DATA_ERROR=true
   RETURN_VALIDATION_ERRORS=false  # Don't expose internals

   # Rate limiting
   RATE_LIMIT_PER_MINUTE=100
   AUTH_RATE_LIMIT_PER_MINUTE=5
   TRADE_RATE_LIMIT_PER_MINUTE=30
   ```

3. **Set restrictive permissions:**
   ```bash
   # Make .env readable only by owner
   chmod 600 .env.production

   # Verify permissions
   ls -l .env.production
   # Should show: -rw------- (600)
   ```

### Production Validation

Before deploying to production, validate your configuration:

```bash
# Run configuration validator
python backend/config_validator.py --env production

# Check for weak secrets
python scripts/check_secrets_strength.py .env.production

# Verify no synthetic data
grep "USE_SYNTHETIC_DATA=true" .env.production
# Should return nothing

# Verify production mode
grep "ENV=production" .env.production
```

### Deployment Checklist

- [ ] All secrets generated with strong randomness
- [ ] No development/test credentials in production .env
- [ ] USE_SYNTHETIC_DATA=false
- [ ] DEBUG=false
- [ ] REQUIRE_AUTHENTICATION=true
- [ ] Strong JWT_SECRET (32+ characters)
- [ ] Strong SESSION_SECRET (32+ characters)
- [ ] Real broker credentials configured
- [ ] File permissions set to 600
- [ ] .env not committed to git
- [ ] Backups encrypted and secured
- [ ] Secret rotation schedule documented
- [ ] Monitoring and alerting configured

## GitHub Secrets

### Setting Up Repository Secrets

1. **Navigate to repository settings:**
   ```
   GitHub Repository → Settings → Secrets and variables → Actions
   ```

2. **Add required secrets:**
   Click "New repository secret" and add each secret:

   | Secret Name | Description | Example Value |
   |------------|-------------|---------------|
   | `JWT_SECRET` | JWT signing key | `<openssl rand -hex 32>` |
   | `SESSION_SECRET` | Session encryption key | `<openssl rand -hex 32>` |
   | `BROKER_API_KEY` | Broker API key | From broker |
   | `BROKER_API_SECRET` | Broker API secret | From broker |
   | `BROKER_ACCOUNT` | Trading account number | From broker |
   | `TELEGRAM_BOT_TOKEN` | Telegram bot token | From BotFather |
   | `TELEGRAM_CHAT_ID` | Telegram chat ID | From Telegram |
   | `DISCORD_WEBHOOK_URL` | Discord webhook | From Discord |
   | `POSTGRES_PASSWORD` | Database password | Generated |
   | `CODECOV_TOKEN` | Code coverage token | From Codecov |
   | `SENTRY_DSN` | Error tracking DSN | From Sentry |

3. **Add environment-specific secrets:**
   For staging/production environments:
   - Go to Settings → Environments
   - Create environment (e.g., "production")
   - Add environment-specific secrets

### Using Secrets in GitHub Actions

**Example workflow:**
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - uses: actions/checkout@v4

    - name: Create .env file
      run: |
        cat > .env << EOF
        ENV=production
        DEBUG=false
        JWT_SECRET=${{ secrets.JWT_SECRET }}
        SESSION_SECRET=${{ secrets.SESSION_SECRET }}
        BROKER_API_KEY=${{ secrets.BROKER_API_KEY }}
        BROKER_API_SECRET=${{ secrets.BROKER_API_SECRET }}
        BROKER_ACCOUNT=${{ secrets.BROKER_ACCOUNT }}
        TELEGRAM_BOT_TOKEN=${{ secrets.TELEGRAM_BOT_TOKEN }}
        TELEGRAM_CHAT_ID=${{ secrets.TELEGRAM_CHAT_ID }}
        EOF

    - name: Deploy application
      run: |
        # Your deployment commands
        python ml/predictor_daemon_v2.py --config configs/config.yaml
```

### GitHub Secrets Security

1. **Secrets are encrypted at rest**
2. **Secrets are masked in logs**
3. **Secrets are only available to authorized workflows**
4. **Secrets can be scoped to specific environments**
5. **Secret access can be reviewed in audit logs**

## Secret Rotation

### Rotation Schedule

| Secret Type | Rotation Frequency | Priority |
|------------|-------------------|----------|
| Broker credentials | Every 90 days | CRITICAL |
| Database passwords | Every 90 days | HIGH |
| API keys | Every 90 days | HIGH |
| JWT secret | Every 6 months | HIGH |
| Session secret | Every 6 months | HIGH |
| Notification tokens | When compromised | MEDIUM |

### Rotation Procedure

1. **Generate new secret:**
   ```bash
   # Generate new secret
   NEW_SECRET=$(openssl rand -hex 32)
   echo $NEW_SECRET
   ```

2. **Update .env file:**
   ```bash
   # Backup current .env
   cp .env .env.backup.$(date +%Y%m%d)

   # Update secret in .env
   sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$NEW_SECRET/" .env
   ```

3. **Update GitHub Secrets:**
   - Navigate to repository secrets
   - Edit the secret
   - Paste new value
   - Save changes

4. **Restart application:**
   ```bash
   # Restart services to use new secret
   systemctl restart quantumtrader
   ```

5. **Verify rotation:**
   ```bash
   # Check application logs
   tail -f logs/quantumtrader.log

   # Test authentication
   curl -X POST http://localhost:8080/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"test","password":"test"}'
   ```

6. **Update documentation:**
   ```bash
   # Log rotation in tracking document
   echo "$(date +%Y-%m-%d) - Rotated JWT_SECRET" >> docs/secret_rotation_log.txt
   ```

### Emergency Rotation

If a secret is compromised:

1. **Immediately rotate the secret**
2. **Invalidate all active sessions/tokens**
3. **Review access logs for suspicious activity**
4. **Update all environments (dev, staging, prod)**
5. **Notify team members**
6. **Document the incident**

## Cloud Secret Managers

### AWS Secrets Manager

1. **Install AWS CLI:**
   ```bash
   pip install awscli boto3
   ```

2. **Create secret in AWS:**
   ```bash
   aws secretsmanager create-secret \
     --name quantumtrader/production/jwt-secret \
     --secret-string "$(openssl rand -hex 32)"
   ```

3. **Retrieve secret in application:**
   ```python
   import boto3

   def get_secret(secret_name):
       client = boto3.client('secretsmanager', region_name='us-east-1')
       response = client.get_secret_value(SecretId=secret_name)
       return response['SecretString']

   # Usage
   jwt_secret = get_secret('quantumtrader/production/jwt-secret')
   ```

4. **Update .env to use AWS:**
   ```bash
   # .env.production
   USE_AWS_SECRETS=true
   AWS_REGION=us-east-1
   AWS_SECRET_NAME_PREFIX=quantumtrader/production/
   ```

### Google Cloud Secret Manager

1. **Install GCP SDK:**
   ```bash
   pip install google-cloud-secret-manager
   ```

2. **Create secret in GCP:**
   ```bash
   echo -n "$(openssl rand -hex 32)" | \
     gcloud secrets create jwt-secret --data-file=-
   ```

3. **Retrieve secret in application:**
   ```python
   from google.cloud import secretmanager

   def get_secret(project_id, secret_id):
       client = secretmanager.SecretManagerServiceClient()
       name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
       response = client.access_secret_version(request={"name": name})
       return response.payload.data.decode('UTF-8')

   # Usage
   jwt_secret = get_secret('my-project', 'jwt-secret')
   ```

### HashiCorp Vault

1. **Install Vault:**
   ```bash
   # macOS
   brew install vault

   # Linux
   wget https://releases.hashicorp.com/vault/1.15.0/vault_1.15.0_linux_amd64.zip
   unzip vault_1.15.0_linux_amd64.zip
   sudo mv vault /usr/local/bin/
   ```

2. **Store secret in Vault:**
   ```bash
   vault kv put secret/quantumtrader/jwt-secret value="$(openssl rand -hex 32)"
   ```

3. **Retrieve secret in application:**
   ```python
   import hvac

   def get_secret(path):
       client = hvac.Client(url='http://localhost:8200')
       client.token = os.environ['VAULT_TOKEN']
       secret = client.secrets.kv.v2.read_secret_version(path=path)
       return secret['data']['data']['value']

   # Usage
   jwt_secret = get_secret('secret/quantumtrader/jwt-secret')
   ```

## Security Best Practices

### 1. Never Commit Secrets

**Bad:**
```bash
# DON'T DO THIS
git add .env
git commit -m "Add configuration"
git push
```

**Good:**
```bash
# Verify .env is in .gitignore
grep "^\.env$" .gitignore

# Check what will be committed
git status

# Verify .env is not tracked
git ls-files | grep .env
# Should return nothing
```

### 2. Use Strong Secrets

**Weak (DON'T USE):**
```bash
JWT_SECRET=secret123
SESSION_SECRET=password
API_KEY=12345
```

**Strong (USE THIS):**
```bash
JWT_SECRET=$(openssl rand -hex 32)
# Result: 7f3d8e9a2b5c6f1e4d7a9b3c5e8f2a4d6e9b1c3f5a7d9e2b4c6f8a1d3e5f7a9b

SESSION_SECRET=$(openssl rand -hex 32)
# Result: 9e2b4c6f8a1d3e5f7a9b2c4e6f8a1d3e5f7a9b2c4e6f8a1d3e5f7a9b2c4e6f
```

### 3. Separate Secrets by Environment

**Never use the same secrets across environments:**

```bash
# Development
JWT_SECRET=dev_secret_not_for_production

# Staging
JWT_SECRET=staging_secret_not_for_production

# Production
JWT_SECRET=<strong_unique_production_secret>
```

### 4. Restrict Access

**File permissions:**
```bash
# .env should be readable only by owner
chmod 600 .env

# config directory restricted
chmod 700 configs/

# Check permissions
ls -la .env
# Should show: -rw-------
```

**User permissions:**
- Only application user should read .env
- Use service accounts with minimal permissions
- Implement least privilege principle

### 5. Monitor Secret Access

**Log secret access:**
```python
import logging

def get_secret(key):
    logger.info(f"Secret accessed: {key} by {current_user}")
    return os.environ.get(key)
```

**Set up alerts:**
- Alert on unauthorized access attempts
- Alert on multiple failed authentications
- Alert on secret rotation failures

### 6. Encrypt Backups

**Backup with encryption:**
```bash
# Create encrypted backup
tar -czf - .env | openssl enc -aes-256-cbc -pbkdf2 -out env.tar.gz.enc

# Restore from backup
openssl enc -aes-256-cbc -pbkdf2 -d -in env.tar.gz.enc | tar -xzf -
```

### 7. Use Environment-Specific Validation

**Validate production configuration:**
```python
def validate_production_config():
    if os.environ.get('ENV') == 'production':
        # Ensure critical settings
        assert os.environ.get('USE_SYNTHETIC_DATA') != 'true', \
            "Synthetic data not allowed in production"
        assert os.environ.get('DEBUG') != 'true', \
            "Debug mode not allowed in production"
        assert len(os.environ.get('JWT_SECRET', '')) >= 32, \
            "JWT secret too weak for production"
```

### 8. Implement Secret Scanning

**Pre-commit hook:**
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Scan for potential secrets in commits
if git diff --cached --name-only | xargs grep -E 'password|secret|key|token' > /dev/null; then
    echo "Warning: Potential secret detected in commit"
    echo "Please review your changes"
    exit 1
fi
```

**GitHub secret scanning:**
- Enable secret scanning in repository settings
- Review alerts regularly
- Rotate secrets if exposed

## Troubleshooting

### Secret Not Loading

**Problem:** Application can't read secret from .env

**Solutions:**
```bash
# 1. Check .env file exists
ls -la .env

# 2. Verify .env format (no spaces around =)
cat .env | grep "JWT_SECRET"
# Should be: JWT_SECRET=value
# Not: JWT_SECRET = value

# 3. Check file permissions
ls -l .env
# Should be readable: -rw-r--r-- or -rw-------

# 4. Verify environment loading
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.environ.get('JWT_SECRET'))"
```

### Authentication Failing After Secret Rotation

**Problem:** All users logged out after rotating JWT_SECRET

**Expected Behavior:** This is normal - JWT_SECRET rotation invalidates all tokens

**Solutions:**
```bash
# 1. Users must log in again
# 2. Implement graceful rotation (support old and new secret temporarily)
# 3. Notify users before rotation
```

### GitHub Actions Can't Access Secrets

**Problem:** Workflow fails with "secret not found"

**Solutions:**
```bash
# 1. Verify secret is added in repository settings
# GitHub → Settings → Secrets and variables → Actions

# 2. Check secret name matches exactly (case-sensitive)
# Workflow: ${{ secrets.JWT_SECRET }}
# Setting: JWT_SECRET (must match)

# 3. Verify workflow has permission to access secrets
# Check repository settings → Actions → General → Workflow permissions

# 4. For environment-specific secrets, specify environment in job
jobs:
  deploy:
    environment: production  # This line is required!
```

### Secret Exposed in Logs

**Problem:** Secret accidentally logged

**Immediate Actions:**
```bash
# 1. Rotate the secret immediately
NEW_SECRET=$(openssl rand -hex 32)
sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$NEW_SECRET/" .env

# 2. Clear logs
> logs/quantumtrader.log

# 3. Update GitHub secrets if exposed there

# 4. Review code to prevent future exposure
grep -r "logger.info.*secret" backend/
```

**Prevention:**
```python
# Use secret masking
import re

def mask_secret(value):
    if len(value) <= 8:
        return "***"
    return f"{value[:4]}...{value[-4:]}"

# Log safely
logger.info(f"Using JWT secret: {mask_secret(jwt_secret)}")
# Output: Using JWT secret: 7f3d...6f8a
```

### Database Connection Failing

**Problem:** Can't connect to database with credentials

**Solutions:**
```bash
# 1. Test connection manually
psql -h localhost -U quantumtrader -d quantumtrader
# Or for MySQL:
mysql -h localhost -u quantumtrader -p quantumtrader

# 2. Check credentials in .env
grep "POSTGRES_PASSWORD" .env

# 3. Verify database is running
systemctl status postgresql
# Or:
docker ps | grep postgres

# 4. Check firewall rules
sudo ufw status | grep 5432

# 5. Test with Python
python -c "
import psycopg2
conn = psycopg2.connect(
    host='localhost',
    database='quantumtrader',
    user='quantumtrader',
    password='YOUR_PASSWORD'
)
print('Connected successfully')
conn.close()
"
```

## Additional Resources

- [Environment Setup Guide](ENVIRONMENT_SETUP.md)
- [GitHub Secrets Guide](GITHUB_SECRETS.md)
- [Security Best Practices](SECURITY.md)
- [Deployment Guide](DEPLOYMENT.md)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [12-Factor App: Config](https://12factor.net/config)

## Support

If you encounter issues with secrets management:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review logs: `tail -f logs/quantumtrader.log`
3. Validate configuration: `python backend/config_validator.py`
4. Open an issue on GitHub with:
   - Environment (dev/staging/prod)
   - Error messages (with secrets masked!)
   - Steps to reproduce

---

**Last Updated:** 2025-11-20
**Version:** 2.1.0
