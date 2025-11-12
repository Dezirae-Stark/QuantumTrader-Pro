# Operations Scripts

This directory contains operational scripts for managing repository security and infrastructure.

## Available Scripts

### 1. Branch Protection Automation

#### `apply_branch_protection.sh`
Applies comprehensive branch protection rules to the main branch via GitHub API.

**Purpose:** Automates the enforcement of security policies documented in `docs/policies/branch-protection.md`.

**Usage:**
```bash
# Apply protection to main branch (default)
./apply_branch_protection.sh

# Apply protection to specific branch/repo
./apply_branch_protection.sh develop Dezirae-Stark/QuantumTrader-Pro
```

**What It Does:**
- ✅ Requires pull request reviews (1 approval minimum)
- ✅ Requires status checks to pass (build, codeql, secret-scan, flutter-analyze, wrapper-validation)
- ✅ Requires signed commits (GPG)
- ✅ Enforces linear history (squash/rebase only)
- ✅ Requires conversation resolution
- ✅ Includes administrators in rules
- ✅ Blocks force pushes
- ✅ Blocks branch deletions

**Prerequisites:**
- GitHub CLI (`gh`) installed and authenticated
- Admin permissions on repository
- Token with `repo` scope

**Install GitHub CLI:**
```bash
# macOS
brew install gh

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Authenticate
gh auth login
```

**Output:**
The script provides detailed feedback:
- ✓ Green checkmarks for successful operations
- ✗ Red X marks for errors
- ⚠ Yellow warnings for manual steps needed
- ℹ Blue info messages for status updates

**Idempotent:** Safe to run multiple times. Existing settings will be updated.

---

### 2. Branch Protection Verification

#### `verify_branch_protection.sh`
Checks and displays the current branch protection status in a user-friendly format.

**Purpose:** Verify that branch protection rules are correctly configured without visiting the GitHub web UI.

**Usage:**
```bash
# Check main branch protection (default)
./verify_branch_protection.sh

# Check specific branch/repo
./verify_branch_protection.sh develop Dezirae-Stark/QuantumTrader-Pro

# Show full raw JSON output
SHOW_RAW=true ./verify_branch_protection.sh
```

**What It Shows:**
1. **Pull Request Reviews**
   - Required approving reviews count
   - Dismiss stale reviews setting
   - Code owner review requirement

2. **Required Status Checks**
   - Branches must be up to date
   - List of required checks

3. **Additional Settings**
   - Include administrators
   - Linear history requirement
   - Conversation resolution
   - Force push blocking
   - Deletion blocking

4. **Signed Commits**
   - GPG signature requirement status

5. **Security Score**
   - Overall protection score (0-10)
   - Color-coded rating

**Prerequisites:**
- GitHub CLI (`gh`) installed and authenticated
- Read permissions on repository

**Example Output:**
```
========================================
Branch Protection Status
========================================
ℹ  Repository: Dezirae-Stark/QuantumTrader-Pro
ℹ  Branch: main

✓ Branch protection is enabled

📝 Pull Request Reviews

✓ Required approving reviews: 1
✓ Dismiss stale pull request approvals: Enabled
✓ Require review from Code Owners: Enabled

🔍 Required Status Checks

✓ Require branches to be up to date: Enabled
✓ Required status checks configured:
  - build
  - codeql
  - secret-scan
  - flutter-analyze
  - wrapper-validation

⚙️  Additional Settings

✓ Include administrators: Enabled
✓ Require linear history: Enabled
✓ Require conversation resolution: Enabled
✓ Allow force pushes: Disabled (force pushes blocked)
✓ Allow deletions: Disabled (branch protected from deletion)

🔐 Signed Commits

✓ Require signed commits: Enabled
ℹ  All commits must be signed with GPG

========================================
Security Score
========================================

  Branch Protection Score: 10 / 10

✓ Excellent! All recommended protections are enabled

ℹ  Policy reference: docs/policies/branch-protection.md
```

---

## Workflow

### Initial Setup

1. **Apply branch protection:**
   ```bash
   cd scripts/ops
   ./apply_branch_protection.sh
   ```

2. **Verify configuration:**
   ```bash
   ./verify_branch_protection.sh
   ```

3. **Test protection:**
   ```bash
   # Try direct push to main (should be rejected)
   git checkout main
   echo "test" >> test.txt
   git add test.txt
   git commit -m "test: Direct push"
   git push origin main
   # Expected: "required status checks" error
   ```

### Maintenance

Run verification script periodically to ensure protection remains active:

```bash
# Add to cron or run manually
./verify_branch_protection.sh
```

If protection is disabled or modified:
```bash
# Re-apply protection
./apply_branch_protection.sh
```

---

## Troubleshooting

### "GitHub CLI (gh) is not installed"

**Solution:** Install GitHub CLI:
```bash
# macOS
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo apt update && sudo apt install gh

# Fedora/CentOS/RHEL
sudo dnf install gh
```

### "Not authenticated with GitHub CLI"

**Solution:** Authenticate:
```bash
gh auth login
# Follow prompts to authenticate
```

### "Admin permissions required"

**Solution:** You need admin access to apply branch protection. Options:
1. Request admin access from repository owner
2. Have repository owner run the script
3. Apply protection manually via Web UI: Settings → Branches

### "Branch not protected"

**Cause:** Branch protection has not been enabled yet.

**Solution:** Run `./apply_branch_protection.sh`

### "Failed to apply protection rules"

**Possible Causes:**
- Insufficient permissions
- Invalid status check names
- Branch doesn't exist

**Solution:**
1. Check `/tmp/branch_protection_output.txt` for error details
2. Verify you have admin permissions
3. Ensure branch exists
4. Update `STATUS_CHECKS` in script to match actual workflow job names

---

## Configuration

### Customizing Required Status Checks

Edit `apply_branch_protection.sh` and modify the `STATUS_CHECKS` variable:

```bash
# Current configuration
STATUS_CHECKS='["build","codeql","secret-scan","flutter-analyze","wrapper-validation"]'

# Example: Add new check
STATUS_CHECKS='["build","codeql","secret-scan","flutter-analyze","wrapper-validation","new-check"]'
```

**Important:** Status check names must exactly match workflow job names in `.github/workflows/*.yml`.

Example workflow:
```yaml
# .github/workflows/ci.yml
jobs:
  build:  # This name must be in STATUS_CHECKS
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: flutter build apk
```

### Applying to Multiple Branches

```bash
# Apply to main
./apply_branch_protection.sh main

# Apply to develop
./apply_branch_protection.sh develop

# Apply to release branches
for branch in release/v1.0 release/v2.0; do
  ./apply_branch_protection.sh "$branch"
done
```

---

## References

- **Policy Documentation:** [docs/policies/branch-protection.md](../../docs/policies/branch-protection.md)
- **GitHub API Docs:** [Branch Protection API](https://docs.github.com/en/rest/branches/branch-protection)
- **GitHub CLI Docs:** [GitHub CLI Manual](https://cli.github.com/manual/)
- **Contributing Guide:** [CONTRIBUTING.md](../../CONTRIBUTING.md)

---

## Security Considerations

### Why Branch Protection Matters

**Without Protection:**
- Anyone can push directly to main (bypasses review)
- Unsigned commits introduce supply chain risk
- Force pushes can rewrite history (data loss)
- Broken code can reach production

**With Protection:**
- All changes require PR and review
- CI must pass before merge
- GPG-signed commits verify authenticity
- History is protected and linear

### Testing Protection

Always test after applying protection:

1. **Test direct push (should fail):**
   ```bash
   git push origin main
   # Expected: "protected branch" error
   ```

2. **Test unsigned commit (should fail):**
   ```bash
   git commit --no-gpg-sign -m "test"
   git push origin main
   # Expected: "signed commits required" error
   ```

3. **Test force push (should fail):**
   ```bash
   git push --force origin main
   # Expected: "force push blocked" error
   ```

4. **Test proper workflow (should succeed):**
   ```bash
   git checkout -b feature/test
   git commit -S -m "feat: Test feature"
   git push origin feature/test
   gh pr create --base main --head feature/test
   # Wait for CI to pass, get approval, then merge
   ```

---

## Future Enhancements

Planned improvements for these scripts:

- [ ] Interactive mode for easier configuration
- [ ] Support for branch patterns (e.g., `release/*`)
- [ ] Automatic detection of workflow job names
- [ ] Slack/email notifications when protection is disabled
- [ ] Terraform/IaC export for version control
- [ ] Bulk operations for multiple repositories

---

**Questions?** Open an issue with the `operations` or `security` label.
