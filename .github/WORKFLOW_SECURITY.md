# GitHub Actions Workflow Security Guidelines

This document outlines security best practices for all GitHub Actions workflows in the QuantumTrader-Pro repository.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Security Requirements](#security-requirements)
3. [Best Practices](#best-practices)
4. [Common Vulnerabilities](#common-vulnerabilities)
5. [Checklist](#checklist)
6. [Resources](#resources)

---

## Core Principles

### 1. Principle of Least Privilege

Workflows should have the minimum permissions necessary to complete their tasks.

**❌ Bad:**
```yaml
# No permissions specified = full read/write access
jobs:
  build:
    runs-on: ubuntu-latest
```

**✅ Good:**
```yaml
permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
```

### 2. Defense in Depth

Multiple layers of security controls to protect against various attack vectors.

**✅ Implementation:**
```yaml
steps:
- name: Harden Runner
  uses: step-security/harden-runner@v2
  with:
    egress-policy: audit

- name: Checkout
  uses: actions/checkout@v4
  with:
    persist-credentials: false
```

### 3. Transparency and Auditability

All security-relevant actions must be logged and traceable.

---

## Security Requirements

### Required for ALL Workflows

#### 1. Explicit Permissions

**Every workflow MUST specify permissions explicitly.**

```yaml
permissions:
  contents: read      # Read repository contents
  actions: read       # Read workflow run data
  security-events: write  # Write security events (CodeQL, etc.)
```

**Available permissions:**
- `actions` - GitHub Actions workflow runs
- `checks` - Check runs and check suites
- `contents` - Repository contents, commits, branches, tags
- `deployments` - Deployments
- `id-token` - OIDC token for cloud auth
- `issues` - Issues and comments
- `packages` - Packages (npm, Docker, etc.)
- `pages` - GitHub Pages
- `pull-requests` - Pull requests
- `security-events` - Security events (SARIF, etc.)
- `statuses` - Commit statuses

#### 2. Step Security Hardening

**All workflows MUST use step-security/harden-runner for egress control.**

```yaml
steps:
- name: Harden Runner
  uses: step-security/harden-runner@v2
  with:
    egress-policy: audit  # Use 'block' in production with allowed-endpoints
    disable-sudo: false
    disable-file-monitoring: false
```

**Egress policies:**
- `audit` - Log all outbound connections (use during development)
- `block` - Block all outbound connections except allowed-endpoints (use in production)

#### 3. Secure Checkout

**Always disable credential persistence unless specifically needed.**

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    persist-credentials: false  # Prevent credential leakage
    ref: ${{ github.sha }}      # Explicit commit reference
```

#### 4. Pinned Action Versions

**Pin actions to specific SHA hashes or tags, never use `@main` or `@master`.**

**❌ Bad:**
```yaml
uses: actions/checkout@main  # Mutable reference
```

**✅ Good:**
```yaml
uses: actions/checkout@v4  # Tagged release
# OR
uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab  # SHA hash
```

---

## Best Practices

### Secret Management

#### ✅ DO:
- Use GitHub Secrets for all sensitive data
- Use environment-specific secrets
- Rotate secrets regularly
- Use OIDC for cloud authentication when possible

```yaml
- name: Deploy
  env:
    API_KEY: ${{ secrets.API_KEY }}
  run: ./deploy.sh
```

#### ❌ DON'T:
- Hardcode secrets in workflows
- Echo secrets in logs
- Store secrets in environment variables unnecessarily

```yaml
# ❌ NEVER DO THIS
- name: Deploy
  env:
    API_KEY: "sk-1234567890abcdef"  # Hardcoded secret
  run: echo $API_KEY  # Logged to console
```

### Input Validation

**Always validate user inputs to prevent script injection.**

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Validate input
      run: |
        if [[ ! "${{ inputs.version }}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Invalid version format"
          exit 1
        fi

    - name: Deploy
      run: ./deploy.sh "${{ inputs.version }}"
```

### Artifact Security

#### Generate and Verify Hashes

```yaml
- name: Generate APK hash
  run: |
    cd build/release
    sha256sum QuantumTraderPro.apk > QuantumTraderPro.apk.sha256
    cat QuantumTraderPro.apk.sha256

- name: Upload artifacts with hashes
  uses: actions/upload-artifact@v4
  with:
    name: release-artifacts
    path: |
      build/release/*.apk
      build/release/*.sha256
```

#### Sign Releases

```yaml
- name: Sign release artifacts
  env:
    GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
    GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
  run: |
    echo "$GPG_PRIVATE_KEY" | gpg --import
    gpg --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" \
        --detach-sign --armor build/release/QuantumTraderPro.apk
```

### Timeout Configuration

**Always set timeouts to prevent resource exhaustion.**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Fail after 30 minutes

    steps:
    - name: Build
      timeout-minutes: 15  # Step-level timeout
      run: ./build.sh
```

### Concurrency Control

**Prevent race conditions and resource conflicts.**

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancel old runs
```

---

## Common Vulnerabilities

### 1. Script Injection

**Vulnerability:**
```yaml
# ❌ User input directly in script
- name: Greet
  run: echo "Hello ${{ github.event.issue.title }}"
```

**If issue title is:** `"; rm -rf / #`
**Command becomes:** `echo "Hello "; rm -rf / #"`

**Fix:**
```yaml
# ✅ Use environment variables
- name: Greet
  env:
    ISSUE_TITLE: ${{ github.event.issue.title }}
  run: echo "Hello $ISSUE_TITLE"
```

### 2. Credential Leakage

**Vulnerability:**
```yaml
# ❌ Credentials persisted in checkout
- uses: actions/checkout@v4
  # persist-credentials defaults to true!

- name: Build
  run: |
    # Any malicious code in dependencies can now access credentials
    npm install
```

**Fix:**
```yaml
# ✅ Disable credential persistence
- uses: actions/checkout@v4
  with:
    persist-credentials: false
```

### 3. Dependency Confusion

**Vulnerability:**
```yaml
# ❌ Unrestricted network access
- name: Install dependencies
  run: npm install
```

**Fix:**
```yaml
# ✅ Use harden-runner with egress control
- name: Harden Runner
  uses: step-security/harden-runner@v2
  with:
    egress-policy: block
    allowed-endpoints: >
      registry.npmjs.org:443
      github.com:443

- name: Install dependencies
  run: npm ci  # Use 'ci' for reproducible builds
```

### 4. Insufficient Permissions

**Vulnerability:**
```yaml
# ❌ No permissions specified = default write access
jobs:
  test:
    runs-on: ubuntu-latest
```

**Fix:**
```yaml
# ✅ Explicit read-only permissions
permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
```

### 5. Artifact Tampering

**Vulnerability:**
```yaml
# ❌ No verification of uploaded artifacts
- uses: actions/upload-artifact@v4
  with:
    name: release
    path: dist/
```

**Fix:**
```yaml
# ✅ Generate and upload hashes
- name: Generate hashes
  run: |
    cd dist/
    sha256sum * > SHA256SUMS.txt

- uses: actions/upload-artifact@v4
  with:
    name: release
    path: |
      dist/*
      dist/SHA256SUMS.txt
```

---

## Checklist

Use this checklist when creating or reviewing workflows:

### Required (All Workflows)

- [ ] Explicit `permissions` block with minimal privileges
- [ ] `harden-runner` step as first step
- [ ] `persist-credentials: false` in checkout step
- [ ] Pinned action versions (tags or SHA hashes)
- [ ] Timeout set at job level (`timeout-minutes`)
- [ ] No hardcoded secrets or credentials
- [ ] Input validation for user-provided data

### Recommended

- [ ] Concurrency control configured
- [ ] Step-level timeouts for long-running operations
- [ ] Artifact hash generation and verification
- [ ] Error handling and failure notifications
- [ ] Secrets rotation schedule documented
- [ ] Egress policy set to `block` with allowed endpoints

### For Production Builds

- [ ] GPG signing of artifacts
- [ ] SBOM generation
- [ ] Security scanning (CodeQL, dependency scan)
- [ ] Release attestation
- [ ] Multi-stage approval for deployments
- [ ] Audit logging enabled

### For Workflows with Secrets

- [ ] Secrets accessed via `${{ secrets.NAME }}`
- [ ] Secrets never echoed or logged
- [ ] Environment-specific secrets used
- [ ] Secret rotation documented
- [ ] Principle of least privilege applied

---

## Resources

### Official Documentation

- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Security Best Practices for Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#understanding-the-risk-of-script-injections)
- [Workflow Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)

### Tools

- [StepSecurity Harden Runner](https://github.com/step-security/harden-runner)
- [GitHub Action Security Scanner](https://github.com/rhysd/actionlint)
- [OSSF Scorecard](https://github.com/ossf/scorecard)

### Training

- [GitHub Actions Security Training](https://lab.github.com/githubtraining/github-actions:-continuous-integration)
- [OWASP CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)

---

## Workflow Review Process

All workflow changes MUST be reviewed by a CODEOWNER before merging.

**Review checklist:**
1. Run actionlint locally: `actionlint .github/workflows/*.yml`
2. Verify all required security controls are present
3. Check for hardcoded secrets or credentials
4. Validate input sanitization
5. Confirm appropriate permissions
6. Test in a fork before merging

---

## Incident Response

If a security issue is discovered in a workflow:

1. **Immediately:** Disable the workflow via GitHub UI
2. **Assess:** Determine scope of impact
3. **Remediate:** Fix the vulnerability
4. **Rotate:** Rotate any potentially exposed secrets
5. **Document:** Create incident report
6. **Review:** Audit all workflows for similar issues

---

## Updates

This document is reviewed quarterly and updated as needed.

**Last updated:** 2025-01-12
**Next review:** 2025-04-12
**Maintainer:** @Dezirae-Stark

---

## Questions?

For questions about workflow security, open an issue with the `security` label.
