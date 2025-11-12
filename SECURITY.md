# Security Policy

## Our Commitment

QuantumTrader Pro takes security seriously. We appreciate the security research community's efforts in responsibly disclosing vulnerabilities and will acknowledge contributors who follow our disclosure process.

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          | End of Life    |
| ------- | ------------------ | -------------- |
| 2.1.x   | :white_check_mark: | TBD            |
| 2.0.x   | :warning: Critical fixes only | 2025-06-01 |
| < 2.0   | :x:                | Unsupported    |

**Recommendation:** Always use the latest stable release for the best security posture.

## Scope

### In Scope

The following components are covered by this security policy:

- **Mobile Application** (Android APK)
  - Authentication and credential storage
  - Network communication and TLS implementation
  - Local data storage and encryption
  - Permissions and system integration

- **WebSocket Bridge Server**
  - API authentication and authorization
  - WebSocket security
  - Rate limiting and DOS protection
  - Dependency vulnerabilities

- **MQL4 Indicators and Expert Advisors**
  - Code injection vulnerabilities
  - Credential handling
  - MT4/MT5 integration security

- **Infrastructure and CI/CD**
  - GitHub Actions workflows
  - Build and release processes
  - Dependency management
  - Secret handling

- **Documentation**
  - Credential exposure in examples
  - Insecure code patterns
  - Misleading security guidance

### Out of Scope

The following are explicitly **not** covered:

- **Third-Party Services**
  - MetaTrader 4/5 platform security
  - Broker (LHFX, MetaQuotes) infrastructure
  - Cloud service provider security
  - Mobile OS (Android) vulnerabilities

- **Demo/Test Accounts**
  - Compromise of demo trading accounts (no real funds)
  - Test credentials explicitly marked as non-production

- **Social Engineering**
  - Phishing attacks against users
  - Impersonation of project maintainers

- **Physical Security**
  - Device theft or physical access attacks
  - SIM swapping or carrier-level attacks

- **Denial of Service (DOS)**
  - Resource exhaustion attacks against demo services
  - Network-level DOS attacks

## Reporting a Vulnerability

### How to Report

**⚠️ DO NOT open public GitHub Issues for security vulnerabilities.**

Instead, please report security issues privately using one of these methods:

#### Method 1: GitHub Security Advisory (Preferred)

1. Navigate to: https://github.com/Dezirae-Stark/QuantumTrader-Pro/security/advisories
2. Click "Report a vulnerability"
3. Fill out the advisory form with details
4. Submit privately to maintainers

#### Method 2: Encrypted Email

Send an encrypted email to: **security@quantumtrader.example** (or repository owner email)

**PGP Public Key:**
```
-----BEGIN PGP PUBLIC KEY BLOCK-----
[Key fingerprint and public key would go here in production]
To be provided upon request or via keyserver
-----END PGP PUBLIC KEY BLOCK-----
```

**For unencrypted (low-severity) reports:** Include `[SECURITY]` in subject line.

### What to Include

Please provide the following information:

1. **Vulnerability Description**
   - Clear description of the issue
   - Attack scenario or exploit narrative
   - Component/file affected

2. **Impact Assessment**
   - Confidentiality impact (data exposure)
   - Integrity impact (data modification)
   - Availability impact (service disruption)
   - Estimated severity (Critical/High/Medium/Low)

3. **Reproduction Steps**
   - Step-by-step instructions to reproduce
   - Environment details (OS, versions, configurations)
   - Proof-of-concept code or screenshots (if available)

4. **Suggested Remediation** (optional)
   - Proposed fixes or mitigations
   - Alternative solutions

5. **Disclosure Preferences**
   - Public acknowledgment (yes/no)
   - Name/handle for credit
   - Coordinated disclosure timeline preferences

### Example Report Template

```markdown
## Summary
Brief one-line description of the vulnerability

## Severity
[Critical/High/Medium/Low] - Based on CVSS or your assessment

## Component
- Affected file(s): path/to/file.ext
- Version: v2.1.0

## Vulnerability Details
Detailed technical description...

## Impact
- Confidentiality: [High/Medium/Low/None]
- Integrity: [High/Medium/Low/None]
- Availability: [High/Medium/Low/None]

## Reproduction Steps
1. Step one...
2. Step two...
3. Observe result...

## Proof of Concept
```code
// Exploit code here (if applicable)
```

## Suggested Fix
Proposed remediation approach...

## Disclosure
- Public credit: [Yes/No]
- Name/Handle: [Your name]
```

## Response Timeline

We are committed to the following response times:

| Severity   | Initial Response | Triage Complete | Fix Target | Public Disclosure |
|------------|-----------------|-----------------|------------|-------------------|
| Critical   | 24 hours        | 48 hours        | 7 days     | 30 days after fix |
| High       | 48 hours        | 5 days          | 30 days    | 60 days after fix |
| Medium     | 5 days          | 14 days         | 60 days    | 90 days after fix |
| Low        | 7 days          | 30 days         | Next release | 120 days after fix |

**Coordinated Disclosure:** We follow a 90-day coordinated disclosure policy. We will work with you to determine an appropriate public disclosure date after a fix is released.

### Response Process

1. **Acknowledgment:** We will acknowledge receipt within the timeframe above
2. **Validation:** We will validate and reproduce the issue
3. **Triage:** We will assess severity and impact
4. **Remediation:** We will develop and test a fix
5. **Release:** We will release a patched version
6. **Disclosure:** We will publish a security advisory after the fix is widely deployed

## Security Advisories

Published security advisories are available at:
- **GitHub:** https://github.com/Dezirae-Stark/QuantumTrader-Pro/security/advisories
- **Repository:** See `SECURITY-ADVISORY-*.md` files in the root directory

Subscribe to repository releases to receive security update notifications.

## Security Best Practices for Users

### Mobile App Users

1. **Download from Official Sources Only**
   - GitHub Releases: https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases
   - Verify APK signatures and checksums before installation

2. **Keep Software Updated**
   - Enable automatic updates or check regularly for new releases
   - Review changelogs for security fixes

3. **Use Strong Credentials**
   - Never reuse demo credentials for production accounts
   - Use unique, complex passwords
   - Enable biometric authentication if available

4. **Secure Your Device**
   - Keep Android OS updated
   - Use device encryption
   - Install from official app stores when possible

### Developers and Contributors

1. **Never Commit Secrets**
   - Use environment variables for credentials
   - Enable pre-commit hooks for secret scanning
   - Review diffs before committing

2. **Dependency Management**
   - Keep dependencies updated
   - Review security advisories for dependencies
   - Use lock files (package-lock.json, build.gradle.lockfile)

3. **Code Review**
   - All code changes require review
   - Focus on authentication, authorization, and data handling
   - Use automated security scanners in CI/CD

4. **Secure Development Environment**
   - Use encrypted disk storage
   - Secure API tokens and SSH keys
   - Isolate test environments from production

### Bridge Server Operators

1. **Use TLS/HTTPS**
   - Never run bridge server over HTTP in production
   - Use valid TLS certificates
   - Implement certificate pinning in mobile app

2. **Authentication Required**
   - Enable JWT or mutual TLS authentication
   - Rotate credentials regularly
   - Use short-lived tokens

3. **Network Security**
   - Run behind firewall or VPN
   - Implement rate limiting
   - Log security events (without logging credentials)

4. **Regular Updates**
   - Keep Node.js and npm packages updated
   - Monitor security advisories for Express, ws, and other dependencies
   - Apply patches promptly

## Security Features

### Current Security Measures

- **Android App**
  - EncryptedSharedPreferences for credential storage
  - Android Keystore integration
  - Network Security Config (TLS-only, certificate pinning)
  - ProGuard/R8 code obfuscation in release builds

- **Bridge Server**
  - JWT authentication support
  - Rate limiting (express-rate-limit)
  - CORS configuration
  - Structured logging (no PII/credentials)

- **CI/CD**
  - CodeQL static analysis
  - Dependabot dependency updates
  - Secret scanning (gitleaks, trufflehog)
  - Gradle wrapper validation
  - Signed release artifacts

- **Build Artifacts**
  - APK signing with release keystore
  - SHA256 checksums for verification
  - SBOM (Software Bill of Materials) generation
  - Reproducible builds (documented process)

### Roadmap

Planned security enhancements:

- [ ] End-to-end encryption for sensitive data in transit
- [ ] Hardware security module (HSM) integration for key storage
- [ ] Security audit by third-party firm
- [ ] Bug bounty program launch
- [ ] Penetration testing of mobile app and bridge
- [ ] Formal threat modeling and risk assessment

## Compliance and Certifications

**Current Status:** Pre-certification

**Planned Compliance:**
- OWASP Mobile Application Security Verification Standard (MASVS)
- OWASP Application Security Verification Standard (ASVS) Level 2
- CWE/SANS Top 25 mitigation

**Not Financial Services Compliant:** This software is for educational and research purposes only. It is not certified for production financial trading.

## Security Tools and Automation

### Recommended Tools for Contributors

- **Secret Scanning**
  - gitleaks: https://github.com/gitleaks/gitleaks
  - trufflehog: https://github.com/trufflesecurity/trufflehog
  - git-secrets: https://github.com/awslabs/git-secrets

- **Dependency Scanning**
  - npm audit (Node.js)
  - Gradle Dependency Check (Android)
  - OWASP Dependency-Check
  - Snyk

- **Static Analysis**
  - CodeQL (GitHub)
  - Android Lint
  - ESLint with security plugins

- **Dynamic Analysis**
  - OWASP ZAP for bridge server testing
  - Mobile Security Framework (MobSF) for Android APK analysis

### Pre-commit Hook Setup

```bash
# Install gitleaks
brew install gitleaks  # macOS
# or download from: https://github.com/gitleaks/gitleaks/releases

# Configure pre-commit hook
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/sh
gitleaks protect --staged --redact --verbose
EOF

chmod +x .git/hooks/pre-commit
```

## Contact

### Security Team

**Primary Contact:** Repository Maintainers
**Response:** security@quantumtrader.example (or via GitHub Security Advisories)

### General Security Questions

For non-sensitive security questions:
- Open a Discussion: https://github.com/Dezirae-Stark/QuantumTrader-Pro/discussions
- Tag: `security`, `question`

**Note:** Do NOT use Discussions for vulnerability reports.

## Acknowledgments

We thank the following security researchers for responsibly disclosing vulnerabilities:

_(This section will be updated as reports are received and fixed)_

## Legal

### Safe Harbor

We support security research conducted in good faith and will not pursue legal action against researchers who:

1. Follow responsible disclosure practices outlined in this policy
2. Do not access, modify, or delete user data beyond what is necessary to demonstrate the vulnerability
3. Do not perform DOS attacks or resource exhaustion
4. Do not violate privacy of other users
5. Provide reasonable time for remediation before public disclosure

### Disclaimer

This software is provided "as is" without warranty. The maintainers are not liable for any damages arising from security vulnerabilities. Use at your own risk, especially in production environments.

**Trading Risk:** This software connects to financial trading platforms. Users assume all trading risks, including loss of funds due to software bugs or security vulnerabilities.

## Additional Resources

- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **CWE Top 25:** https://cwe.mitre.org/top25/
- **Android Security Best Practices:** https://developer.android.com/topic/security/best-practices
- **Node.js Security Best Practices:** https://nodejs.org/en/docs/guides/security/

---

**Last Updated:** 2025-01-12
**Policy Version:** 1.0
**Next Review:** 2025-04-12 (Quarterly)
