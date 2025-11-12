# Security Advisory QTPRO-2025-001: Credential Exposure in Release Notes

**Published:** 2025-01-12
**Severity:** High
**Status:** Resolved
**CVE:** Pending Assignment

## Summary

Demo account credentials for LHFX (Longhorn FX) broker were inadvertently included in public release notes for QuantumTrader Pro v2.1.0 and earlier documentation. These credentials have been rotated and removed from all public-facing materials.

## Impact

### What Was Exposed

- **LHFX Demo Account Credentials** were present in:
  - GitHub Release notes for v2.1.0
  - README documentation in backtest/ and bridge/ directories
  - MQL4 configuration files (mql4/config.mqh, mql4/QuantumTraderPro.mq4)

### Scope of Exposure

- **Account Type:** Demo/Practice trading account (not production funds)
- **Broker:** LHFX (Longhorn FX) Demo Server
- **Timeline:** Credentials were public from 2025-01-12 06:49 UTC to 2025-01-12 (rotation time)
- **Risk Level:** Moderate - demo account with no real monetary value, but could be used for:
  - Unauthorized access to demo trading history
  - Potential reputation/research integrity concerns
  - Practice account manipulation

### What Was NOT Exposed

- No production trading account credentials
- No real funds or customer accounts
- No API keys for production systems
- No private keys or signing certificates
- No database credentials
- No cloud service credentials

## Resolution

### Actions Taken

1. **Credential Rotation (2025-01-12)**
   - All exposed LHFX demo credentials have been rotated
   - New credentials are stored securely and not committed to repository
   - Access control policies implemented for credential management

2. **Repository Remediation**
   - Updated release notes to remove hardcoded credentials
   - Modified documentation to use placeholder values (LHFX_USERNAME, LHFX_PASSWORD)
   - Implemented secret scanning in CI/CD pipeline
   - Added pre-commit hooks for secret detection

3. **Code Changes**
   - Refactored authentication flows to use environment variables
   - Implemented secure credential storage patterns
   - Added encrypted storage for mobile app (EncryptedSharedPreferences)

4. **Process Improvements**
   - Established security policy (SECURITY.md)
   - Implemented mandatory code review for credential-touching code
   - Added secret scanning tools (gitleaks, trufflehog) to development workflow
   - Created secure backtesting procedures that don't commit credentials

### Git History Considerations

**Why We Didn't Rewrite History:**

Git history was NOT rewritten for the following reasons:

1. **Fork Impact:** Rewriting history breaks all existing forks, making collaboration difficult
2. **Demo Credentials:** The exposed credentials were for demo accounts with no real monetary value
3. **Already Public:** Credentials were already indexed by search engines and web archives
4. **Rotation Sufficiency:** Rotating credentials achieves the same security outcome
5. **Audit Trail:** Preserving history maintains transparency and audit trail

**Alternative Mitigation:**

- All exposed credentials have been rotated and invalidated
- New credentials are managed via environment variables only
- Secret scanning prevents future exposure
- This advisory provides full transparency about the incident

## User Actions Required

### For Users of QuantumTrader Pro

✅ **Update to Latest Release**
- Download v2.1.1 or later from: https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases
- Follow updated documentation for secure credential management

✅ **Review Credential Practices**
- Never commit credentials to version control
- Use environment variables for sensitive configuration
- Follow secure storage guidelines in docs/security/

✅ **If You Forked This Repository**
- Pull latest changes from upstream
- Review your fork for any exposed credentials
- Implement secret scanning in your workflows

### For LHFX Demo Account Holders

⚠️ **If you used the exposed credentials:**
- The demo account has been rotated and is no longer accessible
- Request new demo credentials from LHFX support if needed
- No action required if you use different credentials

### No Action Required If:

- You only use the mobile app (credentials never stored in app code)
- You never used the exposed demo credentials
- You only downloaded release APKs (credentials not embedded)

## Timeline

| Date/Time (UTC) | Event |
|-----------------|-------|
| 2025-01-12 06:49 | v2.1.0 released with credentials in release notes |
| 2025-01-12 07:00 | Credentials identified during security review |
| 2025-01-12 07:15 | Credentials rotated with LHFX |
| 2025-01-12 07:30 | Advisory published and fixes initiated |
| 2025-01-12 08:00 | PR-1 submitted with remediations |

## Technical Details

### Files Affected

```
├── Release v2.1.0 notes (GitHub Releases)
├── backtest/README.md (lines 21-22)
├── bridge/README.md (line 30)
├── mql4/config.mqh (lines 1-2)
└── mql4/QuantumTraderPro.mq4 (lines 2-4)
```

### Remediation Pattern

**Before (Insecure):**
```python
LHFX_LOGIN = 194302
LHFX_PASSWORD = "ajty2ky"
```

**After (Secure):**
```python
LHFX_LOGIN = os.getenv("LHFX_USERNAME")
LHFX_PASSWORD = os.getenv("LHFX_PASSWORD")
if not LHFX_LOGIN or not LHFX_PASSWORD:
    raise ValueError("LHFX credentials must be provided via environment variables")
```

### Secret Scanning Results

The following tools were run to detect any remaining secrets:

- **gitleaks v8.x:** No additional secrets detected
- **trufflehog v3.x:** No verified secrets found
- **GitHub Secret Scanning:** Enabled for all future commits

## Prevention Measures

### Development Workflow

1. **Pre-commit Hooks**
   ```bash
   # Install gitleaks pre-commit hook
   git config core.hooksPath .githooks
   ```

2. **CI/CD Integration**
   - Secret scanning runs on every PR
   - Builds fail if secrets detected
   - CodeQL analysis for credential patterns

3. **Documentation Standards**
   - All docs use placeholder credentials: `LHFX_USERNAME`, `LHFX_PASSWORD`
   - Example values clearly marked as `REDACTED` or `<your-value-here>`
   - Security warnings in credential-handling sections

### Code Review Checklist

- [ ] No hardcoded credentials in code
- [ ] Environment variables used for secrets
- [ ] Documentation uses placeholders only
- [ ] Secret scanning tools pass
- [ ] Encryption used for stored credentials

## Contact & Reporting

### Security Contact

**Email:** security@quantumtrader.example (or repository owner)
**PGP Key:** See SECURITY.md for public key

### Reporting New Vulnerabilities

Please follow the disclosure process in SECURITY.md:

1. **DO NOT** open public issues for security vulnerabilities
2. Email security contact with details
3. Allow 90 days for coordinated disclosure
4. Acknowledge security researchers in advisories

### Questions

For questions about this advisory:
- Open a discussion: https://github.com/Dezirae-Stark/QuantumTrader-Pro/discussions
- Contact repository maintainers (non-security questions only)

## References

- **SECURITY.md:** Full security policy
- **PR-1:** Remediation pull request with code changes
- **CWE-798:** Use of Hard-coded Credentials
- **OWASP:** https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password

## Acknowledgments

This issue was identified during internal security review as part of repository hardening efforts.

---

**Severity Justification:** High
While exposed credentials were for demo accounts with no monetary value, public credential exposure poses reputation risk and could affect research reproducibility. The high severity reflects the principle of defense-in-depth and the importance of credential hygiene.

**Status:** Resolved - All credentials rotated, code remediated, preventive measures implemented.
