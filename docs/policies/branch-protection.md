# Branch Protection Policy

**Last Updated:** 2025-01-12
**Version:** 1.0
**Applies To:** QuantumTrader Pro Repository

---

## Overview

This document defines branch protection rules and policies for the QuantumTrader Pro repository to ensure code quality, security, and collaborative development best practices.

Branch protection prevents accidental or malicious changes to important branches and enforces a review process for all code changes.

---

## Protected Branches

The following branches are subject to protection rules:

### 1. `main` Branch
**Purpose:** Production-ready code, stable releases

**Protection Level:** Highest

### 2. `release/*` Branches
**Purpose:** Release preparation and hotfixes

**Protection Level:** High

### 3. `develop` Branch (If Used)
**Purpose:** Integration branch for features

**Protection Level:** Medium

---

## Branch Protection Rules

### Required Rules for `main` Branch

#### 1. Require Pull Request Reviews
**Setting:** ✅ Enabled

**Configuration:**
- **Required approving reviews:** 1 (minimum)
- **Dismiss stale pull request approvals when new commits are pushed:** ✅ Yes
- **Require review from Code Owners:** ✅ Yes (when CODEOWNERS file exists)
- **Restrict who can dismiss pull request reviews:** Repository admins only

**Rationale:** Ensures at least one other person reviews code before merging, catching bugs and security issues.

#### 2. Require Status Checks to Pass
**Setting:** ✅ Enabled

**Required Checks:**
- `build` - Android APK build must succeed
- `codeql` - CodeQL security analysis must pass
- `secret-scan` - Secret scanning must find no issues
- `flutter-analyze` - Dart/Flutter linter must pass
- `wrapper-validation` - Gradle wrapper checksum validation

**Configuration:**
- **Require branches to be up to date before merging:** ✅ Yes

**Rationale:** Prevents broken code from entering main branch; ensures security scans pass.

#### 3. Require Signed Commits
**Setting:** ✅ Enabled

**Configuration:**
- All commits must be signed with a verified GPG key
- GitHub will reject unsigned commits

**Rationale:** Ensures commit authenticity and prevents impersonation. Critical for supply chain security.

**Setup Instructions:** See [CONTRIBUTING.md](../../CONTRIBUTING.md#commit-signing-required)

#### 4. Require Linear History
**Setting:** ✅ Enabled (Rebase/Squash merges only)

**Configuration:**
- **Allow merge commits:** ❌ No
- **Allow squash merging:** ✅ Yes (recommended)
- **Allow rebase merging:** ✅ Yes

**Rationale:** Maintains clean, linear git history; easier to bisect and understand changes.

#### 5. Require Conversation Resolution
**Setting:** ✅ Enabled

**Configuration:**
- All review comments must be resolved before merging

**Rationale:** Ensures all feedback is addressed; prevents incomplete code from merging.

#### 6. Include Administrators
**Setting:** ✅ Enabled

**Configuration:**
- Branch protection rules apply to repository administrators

**Rationale:** No one is above the rules; maintains consistency and accountability.

#### 7. Restrict Force Pushes
**Setting:** ✅ Enabled (Block force pushes)

**Configuration:**
- Force pushes are blocked for all users, including admins

**Rationale:** Prevents accidental history rewriting; protects git history integrity.

#### 8. Restrict Deletions
**Setting:** ✅ Enabled

**Configuration:**
- Branch cannot be deleted

**Rationale:** Prevents accidental deletion of production branch.

---

### Rules for `release/*` Branches

Same as `main` branch, plus:

#### Additional Rule: Require Deployment to Succeed
**Setting:** ✅ Enabled (if deployment workflow exists)

**Configuration:**
- Deployment to staging environment must succeed before merging

**Rationale:** Ensures release candidates are deployable before finalizing.

---

## Implementation

### Option 1: Via GitHub Web UI (Recommended for Initial Setup)

1. **Navigate to Settings:**
   - Go to repository on GitHub
   - Click **Settings** → **Branches** (under "Code and automation")

2. **Add Branch Protection Rule:**
   - Click **Add branch protection rule**
   - **Branch name pattern:** `main`

3. **Configure Protection Settings:**
   - ✅ Require a pull request before merging
     - ✅ Require approvals: `1`
     - ✅ Dismiss stale pull request approvals when new commits are pushed
     - ✅ Require review from Code Owners
   - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - **Status checks:** Add `build`, `codeql`, `secret-scan`, `flutter-analyze`, `wrapper-validation`
   - ✅ Require conversation resolution before merging
   - ✅ Require signed commits
   - ✅ Require linear history
   - ✅ Include administrators
   - ✅ Restrict who can push to matching branches (leave empty to block all direct pushes)
   - ✅ Allow force pushes: **Disabled**
   - ✅ Allow deletions: **Disabled**

4. **Save Changes:**
   - Click **Create** or **Save changes**

5. **Repeat for `release/*`:**
   - Create another rule with pattern `release/*`
   - Use same settings as `main`

### Option 2: Via GitHub API (Automated)

Use the provided script for automated setup:

```bash
# Run from repository root
bash scripts/ops/branch_protection.sh
```

**Script location:** `scripts/ops/branch_protection.sh`

**What it does:**
- Applies branch protection rules via GitHub API
- Requires admin token with `repo` scope
- Idempotent (safe to run multiple times)

**Prerequisites:**
- GitHub CLI (`gh`) installed and authenticated
- Admin permissions on repository
- Token with `repo` scope

**Script Content:**
```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="Dezirae-Stark/QuantumTrader-Pro"
BRANCH="main"

echo "Applying branch protection rules to $REPO:$BRANCH..."

# Required status checks (adjust based on actual workflow names)
STATUS_CHECKS='["build","codeql","secret-scan","flutter-analyze","wrapper-validation"]'

# Apply protection
gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
  --field required_status_checks="$(cat <<EOF
{
  "strict": true,
  "contexts": $STATUS_CHECKS
}
EOF
)" \
  --field enforce_admins=true \
  --field required_pull_request_reviews="$(cat <<EOF
{
  "required_approving_review_count": 1,
  "dismiss_stale_reviews": true,
  "require_code_owner_reviews": true
}
EOF
)" \
  --field restrictions=null \
  -H "Accept: application/vnd.github+json"

# Require signed commits
gh api -X POST "repos/$REPO/branches/$BRANCH/protection/required_signatures" \
  -H "Accept: application/vnd.github+json" || echo "Signed commits already required"

# Block force pushes and deletions (via Web UI only, not API)
echo "⚠️  Manual step required:"
echo "   - Go to Settings → Branches → Edit rule for '$BRANCH'"
echo "   - Ensure 'Allow force pushes' is UNCHECKED"
echo "   - Ensure 'Allow deletions' is UNCHECKED"

echo "✅ Branch protection applied successfully!"
```

**Run the script:**
```bash
cd scripts/ops
chmod +x branch_protection.sh
./branch_protection.sh
```

### Option 3: Via Terraform (Infrastructure as Code)

For organizations managing multiple repositories:

```hcl
# terraform/branch_protection.tf
resource "github_branch_protection" "main" {
  repository_id  = github_repository.quantumtrader_pro.id
  pattern        = "main"

  required_pull_request_reviews {
    required_approving_review_count      = 1
    dismiss_stale_reviews                = true
    require_code_owner_reviews           = true
    restrict_dismissals                  = false
  }

  required_status_checks {
    strict   = true
    contexts = ["build", "codeql", "secret-scan", "flutter-analyze", "wrapper-validation"]
  }

  require_conversation_resolution = true
  require_signed_commits          = true
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
}
```

---

## Verification

### Check Current Protection Status

```bash
# Via GitHub CLI
gh api repos/Dezirae-Stark/QuantumTrader-Pro/branches/main/protection | jq .

# Expected output includes:
# - required_pull_request_reviews
# - required_status_checks
# - enforce_admins: true
# - allow_force_pushes: { enabled: false }
# - allow_deletions: { enabled: false }
```

### Test Protection Rules

1. **Try to push directly to `main`:**
   ```bash
   git checkout main
   echo "test" >> test.txt
   git add test.txt
   git commit -m "test: Direct push test"
   git push origin main
   # Should be rejected: "required status checks"
   ```

2. **Try unsigned commit:**
   ```bash
   git commit --no-gpg-sign -m "test: Unsigned commit"
   # Should be rejected if protection enabled
   ```

3. **Try force push:**
   ```bash
   git push --force origin main
   # Should be rejected: "force push blocked"
   ```

---

## Bypassing Protection (Emergency Only)

### When to Bypass

Bypassing branch protection should be **extremely rare** and only in emergencies:

- Critical security hotfix required immediately
- Production outage requiring urgent fix
- Build system failure blocking all PRs

### How to Bypass (Admin Only)

1. **Temporarily disable rule:**
   - Settings → Branches → Edit rule
   - Uncheck "Include administrators"
   - Make urgent commit
   - **Re-enable immediately after**

2. **Document the bypass:**
   - Create incident report
   - Explain why bypass was necessary
   - Link to relevant issue/incident

3. **Post-incident review:**
   - Review the emergency commit with team
   - Open retrospective issue to prevent future bypasses

**Warning:** Bypassing protection breaks audit trail and should be logged.

---

## Exceptions and Special Cases

### Dependabot PRs

**Issue:** Dependabot cannot sign commits with GPG.

**Solution:**
- Option 1: Merge Dependabot PRs via web UI (GitHub signs on merge)
- Option 2: Cherry-pick Dependabot changes into signed commit:
  ```bash
  git fetch origin pull/123/head:dependabot-pr
  git checkout -b deps/update-dependency main
  git cherry-pick <commit-sha>
  git commit --amend --signoff --gpg-sign
  git push origin deps/update-dependency
  ```

### Automated Releases

**Issue:** Release automation may need to push to `main`.

**Solution:**
- Use GitHub App tokens (signed by GitHub)
- Or use GitHub Actions with GITHUB_TOKEN
- Or trigger via PR that auto-merges on approval

---

## Maintenance

### Regular Reviews

Branch protection rules should be reviewed:

- **Quarterly:** Check if rules are still appropriate
- **After incidents:** Adjust rules if protection failed
- **After workflow changes:** Update required status checks
- **When adding collaborators:** Review who has bypass permissions

### Updating Status Checks

When adding/removing CI workflows:

1. Update required status checks list in protection settings
2. Update this documentation
3. Update `scripts/ops/branch_protection.sh` if using automation

Example:
```bash
# Add new check
gh api -X PATCH repos/Dezirae-Stark/QuantumTrader-Pro/branches/main/protection/required_status_checks \
  --field contexts="$(cat <<EOF
["build","codeql","secret-scan","flutter-analyze","wrapper-validation","new-check"]
EOF
)"
```

---

## Troubleshooting

### Problem: "Required status check 'X' is not present"

**Cause:** Workflow hasn't run yet, or job name mismatch.

**Solution:**
1. Check workflow runs: `gh run list --workflow=<name>`
2. Verify job name matches required check name
3. Trigger workflow manually: `gh workflow run <name>`

### Problem: "Signed commit required, but commit is not signed"

**Cause:** GPG signing not configured or key expired.

**Solution:**
1. Check GPG config: `git config --get user.signingkey`
2. Verify key: `gpg --list-secret-keys`
3. Test signing: `echo "test" | gpg --clearsign`
4. See [CONTRIBUTING.md](../../CONTRIBUTING.md#commit-signing-required)

### Problem: "Administrator bypass is enabled"

**Cause:** "Include administrators" was unchecked during emergency.

**Solution:**
1. Re-enable immediately: Settings → Branches → Edit rule
2. Check "Include administrators"
3. Document why it was disabled in incident log

### Problem: Merge queue backed up

**Cause:** Too many pending PRs or slow CI.

**Solution:**
1. **Short-term:** Increase CI parallelism, use GitHub merge queue
2. **Long-term:** Optimize build times, split workflows

---

## References

- **GitHub Docs:** [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- **GitHub API:** [Branch Protection Endpoint](https://docs.github.com/en/rest/branches/branch-protection)
- **Git Signing:** [Signing commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)
- **Security Best Practices:** [Securing your repository](https://docs.github.com/en/code-security/getting-started/securing-your-repository)

---

## Change Log

| Date       | Version | Changes |
|------------|---------|---------|
| 2025-01-12 | 1.0     | Initial branch protection policy created |

---

**Questions?** Open an issue or discussion with the `policy` label.
