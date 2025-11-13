# 🔒 Branch Protection Policy

## Overview

This document defines the branch protection settings for the QuantumTrader Pro repository. These rules prevent accidental code deletions, enforce code review, and ensure all security checks pass before merging.

## Protected Branches

### `main` Branch (Production)

The `main` branch contains the stable mobile app code and must be protected with the following settings:

#### Required Status Checks
All of these checks **must pass** before merging:

- ✅ **Build Android APK** - Ensures the app compiles successfully
- ✅ **CodeQL Java/Kotlin Analysis** - No security vulnerabilities detected
- ✅ **CodeQL JavaScript Analysis** - (if applicable) No JS/TS vulnerabilities
- ✅ **Gradle Wrapper Validation** - Prevents supply-chain attacks via malicious wrapper

```bash
# Required checks:
- build-apk
- codeql/java-kotlin
- codeql/javascript (if package.json exists)
- gradle/wrapper-validation
```

#### Pull Request Requirements

- **Require pull request reviews before merging**: 1 approval minimum
- **Dismiss stale reviews when new commits are pushed**: Yes
- **Require review from Code Owners**: No (unless CODEOWNERS file added)
- **Require approval of the most recent reviewable push**: Yes

#### Additional Restrictions

- **Require conversation resolution before merging**: Yes
- **Require signed commits**: Recommended (not enforced to allow Dependabot PRs)
- **Require linear history**: No (allows merge commits)
- **Allow force pushes**: **Never** (prevents history rewrites)
- **Allow deletions**: **Never** (prevents accidental branch deletion)

### `desktop` Branch

The `desktop` branch contains server-side components (bridge, ML engine, MT4/MT5 EAs) and should have similar protections:

#### Required Status Checks

- ✅ **CodeQL Java/Kotlin Analysis** - (if MQL4/MQL5 code is scanned)
- ✅ **CodeQL JavaScript Analysis** - Scans bridge server code
- ✅ **npm audit** - (if added) Checks for vulnerable dependencies

```bash
# Required checks:
- codeql/javascript
- npm-audit (if workflow exists)
```

#### Pull Request Requirements
Same as `main` branch:
- 1 approval required
- Dismiss stale reviews
- Require conversation resolution

#### Additional Restrictions
- **Allow force pushes**: **Never**
- **Allow deletions**: **Never**

---

## Applying Branch Protection Settings

### Option 1: GitHub Web Interface (Recommended for first-time setup)

1. Navigate to: **Settings** > **Branches** > **Branch protection rules**
2. Click **Add branch protection rule**
3. Enter branch name pattern: `main`
4. Configure settings as per the checklist below
5. Click **Create** or **Save changes**
6. Repeat for `desktop` branch

### Option 2: GitHub CLI Script (Automated)

Use the provided script for consistent configuration:

```bash
# From repository root
chmod +x scripts/ops/branch_protection.sh

# Apply protection to main branch
./scripts/ops/branch_protection.sh main

# Apply protection to desktop branch
./scripts/ops/branch_protection.sh desktop
```

**Note:** Requires `gh` CLI with admin permissions. Install: https://cli.github.com/

### Option 3: GitHub API (Advanced)

See `scripts/ops/branch_protection.sh` for example API calls using `gh api`.

---

## Configuration Checklist

Use this checklist when manually configuring branch protection via the web interface:

### For `main` Branch

- [ ] **Branch name pattern:** `main`
- [ ] ✅ Require a pull request before merging
  - [ ] ✅ Require approvals: 1
  - [ ] ✅ Dismiss stale pull request approvals when new commits are pushed
  - [ ] ✅ Require approval of the most recent reviewable push
- [ ] ✅ Require status checks to pass before merging
  - [ ] ✅ Require branches to be up to date before merging
  - [ ] ✅ Status checks that are required:
    - [ ] `build-apk` (from android.yml workflow)
    - [ ] `CodeQL / Analyze Java/Kotlin (Android)` (from codeql.yml)
    - [ ] `CodeQL / Analyze JavaScript/TypeScript` (if applicable)
    - [ ] `Validate Gradle Wrapper` (if in workflow)
- [ ] ✅ Require conversation resolution before merging
- [ ] ❌ Require signed commits (optional - breaks Dependabot)
- [ ] ❌ Require linear history (allows merge commits)
- [ ] ✅ Do not allow bypassing the above settings
- [ ] ✅ Restrict who can push to matching branches
  - [ ] ✅ Add: `Dezirae-Stark` (repository owner)
- [ ] ✅ Rules applied to administrators
- [ ] ✅ Lock branch (read-only): **No**
- [ ] ✅ Do not allow force pushes
- [ ] ✅ Do not allow deletions

### For `desktop` Branch

Same as `main`, but adjust required status checks:

- [ ] ✅ Status checks that are required:
  - [ ] `CodeQL / Analyze JavaScript/TypeScript`
  - [ ] `npm-audit` (if workflow added)

---

## Security Rationale

### Why Require Status Checks?

| Check | Purpose | Prevents |
|-------|---------|----------|
| **Build Android APK** | Ensures code compiles | Breaking changes, syntax errors |
| **CodeQL Analysis** | Detects security vulnerabilities | SQL injection, XSS, command injection |
| **Gradle Wrapper Validation** | Verifies wrapper integrity | Supply-chain attacks via malicious gradle-wrapper.jar |

### Why Require Pull Request Reviews?

- **Peer review catches bugs** that automated tests miss
- **Knowledge sharing** across team members
- **Prevents accidental merges** to production branches

### Why Prohibit Force Pushes?

Force pushes (`git push --force`) rewrite history, which can:
- Delete commits that others have based work on
- Remove code silently without review
- Break git bisect and blame functionality
- Violate audit trail requirements

**Exception:** Force push to personal feature branches is allowed.

### Why Prohibit Deletions?

Deleting a protected branch can:
- Lose production-ready code
- Break CI/CD pipelines that reference the branch
- Remove deployment history

---

## Bypassing Protections (Admin Override)

Repository administrators can bypass branch protection rules via the web interface:

1. Navigate to the Pull Request
2. Click **Merge pull request** dropdown
3. Select **Merge without waiting for requirements to be met (bypass branch protections)**

**Use cases for bypassing:**
- Emergency hotfixes during production outages
- Initial setup when workflows aren't yet configured
- Dependabot PRs when signed commits are required

**⚠️ Warning:** All bypasses are logged in the audit log. Use sparingly.

---

## Troubleshooting

### Issue: "Required status check is failing"

**Solution:**
1. Check workflow logs: Actions tab > Failed workflow
2. Fix the underlying issue (build error, security finding, etc.)
3. Push new commit to trigger re-check

### Issue: "Required status check is not running"

**Possible causes:**
- Workflow file not merged to `main` yet
- Workflow has a path filter that excludes your changes
- Workflow is disabled

**Solution:**
1. Verify workflow exists: `.github/workflows/codeql.yml`
2. Check if workflow runs on PR: `on: pull_request:`
3. Manually trigger workflow: Actions tab > Select workflow > Run workflow

### Issue: "Cannot merge because branch is out of date"

**Solution:**
```bash
# Update your feature branch with latest main
git checkout your-feature-branch
git pull origin main
git push
```

### Issue: "Dependabot PRs are blocked by signed commit requirement"

**Solution:**
Two options:
1. **Disable signed commit requirement** (recommended for automated PRs)
2. **Configure Dependabot GPG key**: [GitHub Docs](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/managing-encrypted-secrets-for-dependabot#adding-a-secret-for-dependabot)

---

## References

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging)
- [GitHub CLI (`gh`) Documentation](https://cli.github.com/manual/)

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-01-12 | Initial branch protection policy created | Claude Code |

---

*This policy is version-controlled. To propose changes, open a pull request modifying this file.*
