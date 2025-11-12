# Contributing to QuantumTrader Pro

Thank you for your interest in contributing to Quantum Trader Pro! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contribution Workflow](#contribution-workflow)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Security](#security)
- [License](#license)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of experience level, background, or identity.

### Expected Behavior

- Be respectful and constructive in all interactions
- Welcome newcomers and help them get started
- Focus on what is best for the project and community
- Show empathy towards other community members
- Accept constructive criticism gracefully

### Unacceptable Behavior

- Harassment, discrimination, or trolling of any kind
- Publishing others' private information without permission
- Personal attacks or inflammatory comments
- Spam or off-topic content

### Enforcement

Instances of unacceptable behavior may be reported to the project maintainers. All complaints will be reviewed and investigated promptly and fairly.

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Git** (2.30 or later) with GPG signing configured
- **Flutter SDK** (3.0 or later) for mobile app development
- **Node.js** (14.0 or later) and npm for bridge server
- **Python** (3.8 or later) for backtesting engine
- **Android Studio** or Android SDK for Android builds
- **MetaTrader 4/5** (optional) for MQL4 development

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/QuantumTrader-Pro.git
   cd QuantumTrader-Pro
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
   ```

### Keep Your Fork Updated

Regularly sync your fork with the upstream repository:

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

---

## Development Setup

### Mobile App (Flutter)

```bash
# Install dependencies
flutter pub get

# Run code analysis
flutter analyze

# Run tests
flutter test

# Run on device/emulator
flutter run
```

### Bridge Server (Node.js)

```bash
cd bridge
npm install

# Run server
npm start

# Run in development mode (auto-restart)
npm run dev
```

### Backtest Engine (Python)

```bash
cd backtest
pip install -r requirements.txt  # If available

# Or install individually
pip install MetaTrader5 pandas numpy

# Run backtest (with environment variables)
export LHFX_USERNAME="your_demo_username"
export LHFX_PASSWORD="your_demo_password"
python3 lhfx_backtest.py
```

### MQL4 Development

1. **Copy files** to MT4's `MQL4/` directory:
   - `*.mq4` → `MQL4/Experts/` or `MQL4/Indicators/`
   - `*.mqh` → `MQL4/Include/`
2. **Compile** in MetaEditor
3. **Test** on demo account only

---

## Contribution Workflow

### 1. Create a Feature Branch

Always create a new branch for your work:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
# or
git checkout -b docs/documentation-update
```

**Branch Naming Convention:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Adding or updating tests
- `security/` - Security fixes or improvements

### 2. Make Your Changes

- Write clean, readable code
- Follow existing code style
- Add tests for new features
- Update documentation as needed
- Keep commits focused and atomic

### 3. Test Your Changes

Before committing, ensure:

```bash
# Flutter: Run analyzer and tests
flutter analyze
flutter test

# Node.js: Run linter (if configured)
cd bridge && npm run lint

# Python: Run linter (if configured)
cd backtest && pylint *.py  # If pylint installed
```

### 4. Commit Your Changes

See [Commit Guidelines](#commit-guidelines) below.

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub.

---

## Commit Guidelines

We follow **Semantic Commit Messages** for clarity and automated changelog generation.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Example:**
```
feat(android): Add biometric authentication for login

- Implement BiometricPrompt API for fingerprint/face unlock
- Add fallback to PIN/password if biometric fails
- Store biometric preference in encrypted storage

Closes #123
```

### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(bridge): Add JWT authentication` |
| `fix` | Bug fix | `fix(android): Resolve crash on Android 12+` |
| `docs` | Documentation only | `docs(readme): Update installation instructions` |
| `style` | Code style/formatting | `style(flutter): Format code with dartfmt` |
| `refactor` | Code refactoring | `refactor(ml): Optimize prediction algorithm` |
| `test` | Adding/updating tests | `test(bridge): Add WebSocket connection tests` |
| `chore` | Maintenance tasks | `chore(deps): Update Flutter to 3.16.0` |
| `security` | Security fixes | `security(auth): Patch credential exposure` |
| `perf` | Performance improvements | `perf(charts): Optimize chart rendering` |

### Scope Examples

- `android`, `flutter`, `ios` - Mobile app
- `bridge`, `websocket` - Bridge server
- `mql4`, `indicators`, `ea` - MQL4 code
- `backtest`, `ml` - Machine learning/backtesting
- `docs`, `readme` - Documentation
- `ci`, `workflow` - CI/CD changes
- `security`, `auth` - Security/authentication

### Commit Signing (Required)

All commits **must be signed** with GPG for security.

#### Setup GPG Signing

1. **Generate GPG key** (if you don't have one):
   ```bash
   gpg --full-generate-key
   # Choose: RSA, 4096 bits, no expiration (or set expiration)
   ```

2. **List your keys**:
   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```

3. **Configure Git** to use your key:
   ```bash
   git config --global user.signingkey YOUR_GPG_KEY_ID
   git config --global commit.gpgsign true
   ```

4. **Add GPG key to GitHub**:
   ```bash
   gpg --armor --export YOUR_GPG_KEY_ID
   # Copy output and add to GitHub Settings → SSH and GPG keys
   ```

#### Troubleshooting GPG Signing

If commits fail to sign:

```bash
# macOS
export GPG_TTY=$(tty)
echo 'export GPG_TTY=$(tty)' >> ~/.zshrc  # or ~/.bashrc

# Linux
export GPG_TTY=$(tty)
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

---

## Pull Request Process

### Before Submitting

- [ ] Code builds successfully (`flutter build apk` for Android)
- [ ] All tests pass (`flutter test`, `npm test` if applicable)
- [ ] Code follows style guidelines
- [ ] Commits are signed and follow semantic format
- [ ] Documentation is updated (if applicable)
- [ ] No secrets or credentials in code
- [ ] CHANGELOG.md updated (if significant change)

### PR Checklist

When opening a Pull Request, include:

#### PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Security fix

## How Has This Been Tested?
Describe the tests you ran to verify your changes:
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing on Android device
- [ ] Tested on demo MT4/MT5 account

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published
- [ ] All commits are signed with GPG
- [ ] No secrets or credentials are included

## Screenshots (if applicable)
Add screenshots for UI changes.

## Related Issues
Closes #issue_number
```

### Review Process

1. **Automated Checks**: CI/CD runs (build, tests, linters, security scans)
2. **Code Review**: At least one maintainer reviews your PR
3. **Feedback**: Address any requested changes
4. **Approval**: PR approved by maintainer
5. **Merge**: Maintainer merges PR (squash or rebase merge)

### After Merge

- Delete your feature branch (done automatically if using squash merge)
- Update your fork:
  ```bash
  git checkout main
  git pull upstream main
  git push origin main
  ```

---

## Coding Standards

### General Principles

- **KISS** (Keep It Simple, Stupid) - Favor simplicity over cleverness
- **DRY** (Don't Repeat Yourself) - Avoid code duplication
- **YAGNI** (You Aren't Gonna Need It) - Don't add functionality until needed
- **SOLID** principles for object-oriented code
- **Secure by default** - Never commit secrets, use environment variables

### Dart/Flutter Style

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style):

```dart
// Good: Clear, descriptive names
class UserAuthenticationService {
  Future<bool> authenticateUser(String username, String password) async {
    // Implementation
  }
}

// Bad: Unclear, abbreviated names
class UAS {
  Future<bool> auth(String u, String p) async {
    // Implementation
  }
}
```

**Key Points:**
- Use `lowerCamelCase` for variables, functions
- Use `UpperCamelCase` for classes, types
- Use `lowercase_with_underscores` for libraries, files
- Prefer `final` over `var` when variable won't change
- Use `const` constructors when possible
- Always handle `Future` errors with `try-catch` or `.catchError`

### JavaScript/Node.js Style

Follow [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript):

```javascript
// Good: Arrow functions, const/let
const calculateProfit = (trades) => {
  return trades.reduce((sum, trade) => sum + trade.profit, 0);
};

// Bad: var, anonymous functions
var calculateProfit = function(trades) {
  var sum = 0;
  for (var i = 0; i < trades.length; i++) {
    sum = sum + trades[i].profit;
  }
  return sum;
};
```

**Key Points:**
- Use `const` by default, `let` if reassignment needed, never `var`
- Prefer arrow functions `() =>` over `function`
- Use template literals `` `${value}` `` over string concatenation
- Always use semicolons
- Use destructuring: `const { name, age } = user;`

### Python Style

Follow [PEP 8](https://pep8.org/):

```python
# Good: Clear naming, type hints
def calculate_sharpe_ratio(returns: list[float], risk_free_rate: float = 0.0) -> float:
    """Calculate Sharpe ratio for a series of returns."""
    mean_return = sum(returns) / len(returns)
    std_dev = statistics.stdev(returns)
    return (mean_return - risk_free_rate) / std_dev if std_dev > 0 else 0.0

# Bad: Unclear, no types
def calc(r, rfr=0):
    m = sum(r)/len(r)
    s = statistics.stdev(r)
    return (m-rfr)/s if s>0 else 0
```

**Key Points:**
- Use `snake_case` for functions and variables
- Use `PascalCase` for classes
- Add type hints (Python 3.8+)
- Write docstrings for all public functions
- 4 spaces for indentation (no tabs)

### MQL4 Style

```mql4
// Good: Clear naming, comments
//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                 |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, double stopLossPips) {
   double accountBalance = AccountBalance();
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   return NormalizeDouble(riskAmount / (stopLossPips * pipValue), 2);
}

// Bad: Unclear, no documentation
double CalcSize(double r, double sl) {
   double b = AccountBalance();
   return NormalizeDouble((b*(r/100))/(sl*MarketInfo(Symbol(),MODE_TICKVALUE)),2);
}
```

---

## Testing

### Writing Tests

**Flutter (Dart):**
```dart
// test/services/mt4_service_test.dart
import 'package:test/test.dart';
import 'package:quantumtrader_pro/services/mt4_service.dart';

void main() {
  group('MT4Service', () {
    late MT4Service service;

    setUp(() {
      service = MT4Service();
    });

    test('connect returns false on invalid credentials', () async {
      final result = await service.connect(
        login: 0,
        password: 'invalid',
        server: 'fake-server',
      );
      expect(result, false);
    });
  });
}
```

### Running Tests

```bash
# Flutter
flutter test                    # Run all tests
flutter test test/services/     # Run specific directory
flutter test --coverage         # Generate coverage report

# Node.js (if configured)
cd bridge && npm test

# Python (if configured)
cd backtest && pytest
```

---

## Security

### Secure Coding Practices

1. **Never commit secrets**:
   ```bash
   # Use environment variables
   export API_KEY="your-secret-key"

   # In code
   apiKey = process.env.API_KEY  # Node.js
   apiKey = os.getenv("API_KEY")  # Python
   ```

2. **Use encrypted storage** for sensitive data:
   ```dart
   // Flutter: Use EncryptedSharedPreferences
   final prefs = await EncryptedSharedPreferences.getInstance();
   await prefs.setString('token', sensitiveToken);
   ```

3. **Validate all inputs**:
   ```dart
   if (input == null || input.isEmpty) {
     throw ArgumentError('Input cannot be empty');
   }
   ```

4. **Use prepared statements** (if using SQL):
   ```dart
   // Good: Prepared statement
   await db.query('SELECT * FROM users WHERE id = ?', [userId]);

   // Bad: SQL injection vulnerable
   await db.rawQuery('SELECT * FROM users WHERE id = $userId');
   ```

### Security Review

Before submitting PRs that touch:
- Authentication/authorization code
- Credential storage
- Network communication
- API endpoints

Request a security review by tagging your PR with `security` label.

### Reporting Security Issues

**DO NOT** open public issues for security vulnerabilities. Instead:
1. Email security@quantumtrader.example (or repository owner)
2. Or use GitHub Security Advisories (private disclosure)

See [SECURITY.md](SECURITY.md) for full details.

---

## License

By contributing to QuantumTrader Pro, you agree that your contributions will be licensed under the MIT License.

**Key Points:**
- You retain copyright to your contributions
- You grant MIT license to the project
- Your contributions become part of the open-source codebase
- Commercial use is permitted (MIT license)

**Important:** The project previously had a dual license (MIT + Proprietary). As of PR-2, the project is **MIT-only**. All contributions after this point are under MIT license.

---

## Questions?

- **General questions**: Open a [Discussion](https://github.com/Dezirae-Stark/QuantumTrader-Pro/discussions)
- **Bug reports**: Open an [Issue](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues)
- **Security issues**: See [SECURITY.md](SECURITY.md)
- **Feature requests**: Open an [Issue](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues) with `enhancement` label

---

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
- [MQL4 Documentation](https://docs.mql4.com/)
- [MetaTrader API](https://www.metatrader5.com/en/terminal/help/trading_api)
- [Git Commit Message Guidelines](https://www.conventionalcommits.org/)

---

Thank you for contributing to QuantumTrader Pro! 🚀📈
