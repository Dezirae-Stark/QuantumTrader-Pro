# GitHub Secrets Setup Guide

## Overview

This guide provides step-by-step instructions for configuring GitHub Secrets for QuantumTrader Pro CI/CD pipelines. GitHub Secrets allow you to store sensitive information securely and use it in GitHub Actions workflows without exposing credentials in your code.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Understanding GitHub Secrets](#understanding-github-secrets)
- [Setting Up Repository Secrets](#setting-up-repository-secrets)
- [Setting Up Environment Secrets](#setting-up-environment-secrets)
- [Required Secrets for QuantumTrader Pro](#required-secrets-for-quantumtrader-pro)
- [Using Secrets in Workflows](#using-secrets-in-workflows)
- [Secret Security](#secret-security)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- GitHub repository access (admin or maintainer role)
- Access to required credentials (broker API keys, tokens, etc.)
- OpenSSL installed for generating secrets: `openssl version`

## Understanding GitHub Secrets

### What are GitHub Secrets?

GitHub Secrets are encrypted environment variables that you can use in GitHub Actions workflows. They are:

- **Encrypted at rest** using libsodium sealed boxes
- **Masked in logs** - GitHub automatically redacts secret values in workflow logs
- **Scoped** - Can be repository-wide or environment-specific
- **Auditable** - Access is logged in the security log

### Secret Types

| Type | Scope | Use Case |
|------|-------|----------|
| **Repository Secrets** | All workflows | General CI/CD secrets |
| **Environment Secrets** | Specific environment | Production/staging credentials |
| **Organization Secrets** | Multiple repositories | Shared credentials |

## Setting Up Repository Secrets

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/QuantumTrader-Pro`
2. Click **Settings** tab (far right)
3. In the left sidebar, click **Secrets and variables** → **Actions**

### Step 2: Add Repository Secrets

1. Click the **New repository secret** button
2. Enter the secret **Name** (must be uppercase with underscores)
3. Enter the secret **Value**
4. Click **Add secret**

**Example:**

```
Name: JWT_SECRET
Value: 7f3d8e9a2b5c6f1e4d7a9b3c5e8f2a4d6e9b1c3f5a7d9e2b4c6f8a1d3e5f7a9b
```

### Step 3: Verify Secret Was Added

- The secret will appear in the secrets list
- The value will be hidden (shown as asterisks: `***`)
- You can update or delete the secret anytime

## Setting Up Environment Secrets

Environment secrets are more secure than repository secrets because they:

- Can require manual approval before deployment
- Can have deployment protection rules
- Are only accessible to workflows targeting that environment

### Step 1: Create Environment

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Enter environment name (e.g., `production`, `staging`, `demo`)
4. Click **Configure environment**

### Step 2: Configure Protection Rules

**Optional but recommended for production:**

1. Check **Required reviewers**
   - Add team members who must approve deployments
   - Prevents accidental production deployments

2. Set **Wait timer**
   - Add delay before deployment (e.g., 5 minutes)
   - Allows time to cancel if needed

3. Set **Deployment branches**
   - Restrict which branches can deploy
   - Example: Only `main` branch can deploy to production

### Step 3: Add Environment Secrets

1. In the environment configuration page, scroll to **Environment secrets**
2. Click **Add secret**
3. Enter secret name and value
4. Click **Add secret**

**Example for production environment:**

```
Environment: production

Secrets:
- BROKER_API_KEY: <production_broker_key>
- BROKER_API_SECRET: <production_broker_secret>
- BROKER_ACCOUNT: <production_account>
```

## Required Secrets for QuantumTrader Pro

### Core Application Secrets

Add these as **repository secrets** (used across all environments):

#### 1. JWT_SECRET

**Purpose:** Signs JWT authentication tokens

**Generate:**
```bash
openssl rand -hex 32
```

**Add to GitHub:**
```
Name: JWT_SECRET
Value: <output_from_openssl_command>
```

#### 2. SESSION_SECRET

**Purpose:** Encrypts session data

**Generate:**
```bash
openssl rand -hex 32
```

**Add to GitHub:**
```
Name: SESSION_SECRET
Value: <output_from_openssl_command>
```

### Broker Credentials

Add these as **environment secrets** (different for staging/production):

#### 3. BROKER_API_KEY

**Purpose:** Broker API authentication

**Source:** Your broker's developer portal

**Add to GitHub (for production environment):**
```
Environment: production
Name: BROKER_API_KEY
Value: <your_broker_api_key>
```

#### 4. BROKER_API_SECRET

**Purpose:** Broker API authentication

**Source:** Your broker's developer portal

**Add to GitHub:**
```
Environment: production
Name: BROKER_API_SECRET
Value: <your_broker_api_secret>
```

#### 5. BROKER_ACCOUNT

**Purpose:** Trading account identification

**Source:** Your broker account number

**Add to GitHub:**
```
Environment: production
Name: BROKER_ACCOUNT
Value: <your_account_number>
```

#### 6. BROKER_PASSWORD (if using MT4/MT5)

**Purpose:** MetaTrader account password

**Source:** Your MetaTrader account

**Add to GitHub:**
```
Environment: production
Name: BROKER_PASSWORD
Value: <your_mt_password>
```

### Database Credentials

Add these as **environment secrets**:

#### 7. POSTGRES_PASSWORD

**Purpose:** PostgreSQL database authentication

**Generate:**
```bash
openssl rand -base64 24
```

**Add to GitHub:**
```
Environment: production
Name: POSTGRES_PASSWORD
Value: <generated_password>
```

#### 8. REDIS_PASSWORD

**Purpose:** Redis authentication

**Generate:**
```bash
openssl rand -base64 24
```

**Add to GitHub:**
```
Environment: production
Name: REDIS_PASSWORD
Value: <generated_password>
```

### Notification Service Tokens

Add these as **repository secrets** (unless you want different tokens per environment):

#### 9. TELEGRAM_BOT_TOKEN

**Purpose:** Telegram bot notifications

**Source:** [@BotFather](https://t.me/botfather) on Telegram

**How to get:**
1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow instructions to create bot
4. Copy the API token provided

**Add to GitHub:**
```
Name: TELEGRAM_BOT_TOKEN
Value: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
```

#### 10. TELEGRAM_CHAT_ID

**Purpose:** Telegram chat for notifications

**How to get:**
1. Start a chat with your bot
2. Send any message to the bot
3. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Look for `"chat":{"id":XXXXXXXXX}` in the response

**Add to GitHub:**
```
Name: TELEGRAM_CHAT_ID
Value: 123456789
```

#### 11. DISCORD_WEBHOOK_URL

**Purpose:** Discord webhook notifications

**How to get:**
1. Open Discord server settings
2. Go to **Integrations** → **Webhooks**
3. Click **New Webhook**
4. Copy the webhook URL

**Add to GitHub:**
```
Name: DISCORD_WEBHOOK_URL
Value: https://discord.com/api/webhooks/123456789/abcdefg...
```

#### 12. SMTP_PASSWORD

**Purpose:** Email notifications via SMTP

**Source:** Your email provider (Gmail, SendGrid, etc.)

**For Gmail:**
1. Go to Google Account settings
2. Enable 2-factor authentication
3. Generate app-specific password
4. Use that password as SMTP_PASSWORD

**Add to GitHub:**
```
Name: SMTP_PASSWORD
Value: <app_specific_password>
```

### Cloud Service Credentials

Add these as **environment secrets** if using cloud services:

#### 13. AWS_ACCESS_KEY_ID

**Purpose:** AWS service authentication

**How to get:**
1. Go to AWS IAM Console
2. Create new user or use existing
3. Attach appropriate policies
4. Create access key
5. Copy Access Key ID

**Add to GitHub:**
```
Environment: production
Name: AWS_ACCESS_KEY_ID
Value: AKIAIOSFODNN7EXAMPLE
```

#### 14. AWS_SECRET_ACCESS_KEY

**Purpose:** AWS service authentication

**Source:** AWS IAM (shown only once when creating access key)

**Add to GitHub:**
```
Environment: production
Name: AWS_SECRET_ACCESS_KEY
Value: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### External Service Tokens

Add these as **repository secrets**:

#### 15. CODECOV_TOKEN

**Purpose:** Upload test coverage to Codecov

**How to get:**
1. Go to [codecov.io](https://codecov.io)
2. Sign in with GitHub
3. Find your repository
4. Copy the upload token

**Add to GitHub:**
```
Name: CODECOV_TOKEN
Value: <codecov_token>
```

#### 16. SENTRY_DSN

**Purpose:** Error tracking with Sentry

**How to get:**
1. Go to [sentry.io](https://sentry.io)
2. Create new project
3. Copy the DSN from project settings

**Add to GitHub:**
```
Name: SENTRY_DSN
Value: https://abc123@o123456.ingest.sentry.io/123456
```

### Complete Secrets Checklist

#### Repository Secrets (All Environments)

- [ ] `JWT_SECRET`
- [ ] `SESSION_SECRET`
- [ ] `TELEGRAM_BOT_TOKEN`
- [ ] `TELEGRAM_CHAT_ID`
- [ ] `DISCORD_WEBHOOK_URL`
- [ ] `SMTP_PASSWORD`
- [ ] `CODECOV_TOKEN`
- [ ] `SENTRY_DSN`

#### Environment Secrets - Production

- [ ] `BROKER_API_KEY`
- [ ] `BROKER_API_SECRET`
- [ ] `BROKER_ACCOUNT`
- [ ] `BROKER_PASSWORD` (if MT4/MT5)
- [ ] `POSTGRES_PASSWORD`
- [ ] `REDIS_PASSWORD`
- [ ] `AWS_ACCESS_KEY_ID` (if using AWS)
- [ ] `AWS_SECRET_ACCESS_KEY` (if using AWS)

#### Environment Secrets - Staging

- [ ] `BROKER_API_KEY` (staging broker)
- [ ] `BROKER_API_SECRET` (staging broker)
- [ ] `BROKER_ACCOUNT` (staging account)
- [ ] `POSTGRES_PASSWORD` (staging database)

## Using Secrets in Workflows

### Basic Usage

Access secrets using the `${{ secrets.SECRET_NAME }}` syntax:

```yaml
name: Test Workflow

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Run tests with secrets
      env:
        JWT_SECRET: ${{ secrets.JWT_SECRET }}
        SESSION_SECRET: ${{ secrets.SESSION_SECRET }}
      run: |
        python -m pytest tests/
```

### Creating .env File in Workflow

For applications that use .env files:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Create .env file
      run: |
        cat > .env << 'EOF'
        ENV=production
        DEBUG=false
        JWT_SECRET=${{ secrets.JWT_SECRET }}
        SESSION_SECRET=${{ secrets.SESSION_SECRET }}
        BROKER_API_KEY=${{ secrets.BROKER_API_KEY }}
        BROKER_API_SECRET=${{ secrets.BROKER_API_SECRET }}
        BROKER_ACCOUNT=${{ secrets.BROKER_ACCOUNT }}
        TELEGRAM_BOT_TOKEN=${{ secrets.TELEGRAM_BOT_TOKEN }}
        TELEGRAM_CHAT_ID=${{ secrets.TELEGRAM_CHAT_ID }}
        POSTGRES_PASSWORD=${{ secrets.POSTGRES_PASSWORD }}
        EOF

    - name: Deploy application
      run: |
        # Your deployment commands
        docker-compose up -d
```

### Using Environment Secrets

To use environment-specific secrets, specify the environment in the job:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production  # This is required to access environment secrets

    steps:
    - uses: actions/checkout@v4

    - name: Deploy with production secrets
      env:
        BROKER_API_KEY: ${{ secrets.BROKER_API_KEY }}
        BROKER_API_SECRET: ${{ secrets.BROKER_API_SECRET }}
      run: |
        python ml/predictor_daemon_v2.py --config configs/config.yaml
```

### Conditional Secrets

Use different secrets based on branch or environment:

```yaml
name: Deploy

on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}

    steps:
    - uses: actions/checkout@v4

    - name: Deploy
      run: |
        echo "Deploying to ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}"
        # Secrets automatically switch based on environment
```

### Multi-Environment Deployment

Example workflow deploying to staging then production:

```yaml
name: Multi-Environment Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging

    steps:
    - uses: actions/checkout@v4

    - name: Deploy to staging
      env:
        BROKER_API_KEY: ${{ secrets.BROKER_API_KEY }}
        BROKER_API_SECRET: ${{ secrets.BROKER_API_SECRET }}
      run: |
        echo "Deploying to staging..."
        # Staging deployment commands

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production

    steps:
    - uses: actions/checkout@v4

    - name: Deploy to production
      env:
        BROKER_API_KEY: ${{ secrets.BROKER_API_KEY }}
        BROKER_API_SECRET: ${{ secrets.BROKER_API_SECRET }}
      run: |
        echo "Deploying to production..."
        # Production deployment commands
```

## Secret Security

### Best Practices

1. **Never log secrets**
   ```yaml
   # BAD - Don't do this
   - name: Debug
     run: echo "My secret is ${{ secrets.JWT_SECRET }}"

   # GOOD - Secrets are automatically masked
   - name: Use secret
     env:
       JWT_SECRET: ${{ secrets.JWT_SECRET }}
     run: python script.py  # Script uses JWT_SECRET from environment
   ```

2. **Use environment secrets for sensitive credentials**
   ```yaml
   # Production credentials should be environment secrets
   jobs:
     deploy:
       environment: production  # Required for environment secrets
       steps:
         - name: Deploy
           env:
             BROKER_KEY: ${{ secrets.BROKER_API_KEY }}  # Environment-specific
           run: ./deploy.sh
   ```

3. **Rotate secrets regularly**
   - Broker credentials: Every 90 days
   - JWT secrets: Every 6 months
   - Database passwords: Every 90 days
   - Update GitHub secrets when rotating

4. **Use least privilege**
   ```yaml
   # Grant only necessary permissions
   permissions:
     contents: read
     deployments: write
   ```

5. **Audit secret access**
   - Go to **Settings** → **Security** → **Audit log**
   - Review who accessed secrets
   - Monitor for unauthorized access

### Secret Masking

GitHub automatically masks secrets in logs, but be aware:

```yaml
# These are automatically masked
- name: Use secrets safely
  env:
    SECRET: ${{ secrets.JWT_SECRET }}
  run: |
    echo $SECRET                    # Masked: ***
    echo "My secret is: $SECRET"   # Masked: My secret is: ***

# These might not be masked (be careful!)
- name: Potential exposure
  run: |
    # If secret is processed/transformed, masking may not work
    echo "${{ secrets.JWT_SECRET }}" | base64   # May not be masked
```

### Secrets in Pull Requests

**Important security consideration:**

- Secrets are NOT available to workflows triggered by forks
- This prevents malicious PRs from stealing secrets
- For fork PRs, you must manually trigger workflows

```yaml
name: Test PR

on:
  pull_request_target:  # Use with caution - runs in context of base repo

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # Checkout PR code

      # Secrets are available, but code is from fork
      # Review PR code carefully before approving workflow
```

## Troubleshooting

### Secret Not Found Error

**Error:**
```
Error: The secret 'JWT_SECRET' was not found
```

**Solutions:**

1. **Verify secret name matches exactly**
   - GitHub secret names are case-sensitive
   - `jwt_secret` ≠ `JWT_SECRET`
   - Check for typos

2. **Check secret scope**
   ```yaml
   # If using environment secrets, you must specify environment
   jobs:
     deploy:
       environment: production  # Required for environment secrets!
       steps:
         - name: Use secret
           env:
             KEY: ${{ secrets.BROKER_API_KEY }}
   ```

3. **Verify secret exists**
   - Go to Settings → Secrets and variables → Actions
   - Check repository secrets list
   - Check environment secrets list (if applicable)

### Secret Value Appears Incorrect

**Problem:** Application fails with authentication error

**Solutions:**

1. **Check for whitespace**
   - GitHub doesn't trim whitespace from secret values
   - Copy secret value carefully
   - Don't include newlines or spaces

2. **Regenerate secret**
   ```bash
   # Generate new secret
   openssl rand -hex 32

   # Update in GitHub
   # Settings → Secrets → Edit secret → Paste new value
   ```

3. **Test secret format**
   ```yaml
   - name: Test secret
     run: |
       echo "Secret length: ${#JWT_SECRET}"
       echo "Secret starts with: ${JWT_SECRET:0:4}..."
     env:
       JWT_SECRET: ${{ secrets.JWT_SECRET }}
   ```

### Workflow Can't Access Environment Secrets

**Error:**
```
Error: Resource not accessible by integration
```

**Solutions:**

1. **Specify environment in job**
   ```yaml
   jobs:
     deploy:
       environment: production  # This line is required!
   ```

2. **Check deployment protection rules**
   - Go to Settings → Environments → production
   - Verify required reviewers (if any)
   - Approve pending deployment if needed

3. **Verify branch protection**
   - Check which branches can deploy to environment
   - Ensure your branch is allowed

### Secret Masked in Logs But Still Visible

**Problem:** Secret appears partially visible in logs

**Cause:** GitHub masks the exact secret value, but if your code transforms the secret, the transformed value may not be masked.

**Solutions:**

1. **Don't transform secrets in workflows**
   ```yaml
   # BAD - Transformation may bypass masking
   - name: Process secret
     run: echo "${{ secrets.JWT_SECRET }}" | base64

   # GOOD - Use secret directly in environment
   - name: Use secret
     env:
       JWT_SECRET: ${{ secrets.JWT_SECRET }}
     run: python app.py
   ```

2. **If you must process secrets, do it in scripts**
   ```yaml
   - name: Process secret safely
     env:
       JWT_SECRET: ${{ secrets.JWT_SECRET }}
     run: |
       # Script handles secret internally, nothing echoed to logs
       python process_secret.py
   ```

### Can't Update Secret

**Problem:** Update button grayed out or permission denied

**Solutions:**

1. **Check repository permissions**
   - You need admin or maintainer role
   - Go to Settings → Collaborators and teams
   - Verify your role

2. **Check organization policies**
   - Organization may have secret policies
   - Contact organization admin

3. **Delete and recreate**
   - If you can't update, try deleting and creating new secret
   - Settings → Secrets → [Secret name] → Remove → New repository secret

## Additional Resources

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Secrets Management Guide](SECRETS_MANAGEMENT.md)
- [Environment Setup Guide](ENVIRONMENT_SETUP.md)
- [Security Best Practices](SECURITY.md)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

## Quick Reference

### Generate Secrets

```bash
# 32-byte hex string (64 characters)
openssl rand -hex 32

# 24-byte base64 string (32 characters)
openssl rand -base64 24

# UUID
uuidgen
```

### Add Secret via GitHub CLI

```bash
# Install GitHub CLI
brew install gh  # macOS
# or: sudo apt install gh  # Linux

# Authenticate
gh auth login

# Add secret
gh secret set JWT_SECRET --body "$(openssl rand -hex 32)"

# Add environment secret
gh secret set BROKER_API_KEY --env production --body "your_api_key"

# List secrets
gh secret list

# Delete secret
gh secret remove JWT_SECRET
```

### Verify Secrets in Workflow

```yaml
- name: Verify secrets are set
  run: |
    [ -z "$JWT_SECRET" ] && echo "JWT_SECRET not set" && exit 1
    [ -z "$SESSION_SECRET" ] && echo "SESSION_SECRET not set" && exit 1
    echo "All secrets verified"
  env:
    JWT_SECRET: ${{ secrets.JWT_SECRET }}
    SESSION_SECRET: ${{ secrets.SESSION_SECRET }}
```

---

**Last Updated:** 2025-11-20
**Version:** 2.1.0
