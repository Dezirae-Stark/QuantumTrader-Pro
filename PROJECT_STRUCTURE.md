# Project Structure Guide

> Quick reference for navigating the QuantumTrader-Pro codebase

## Quick Navigation

| Component | Location | Purpose |
|-----------|----------|---------|
| **Flutter App** | `lib/` | Desktop/mobile trading interface |
| **ML Engine** | `ml/` | Prediction algorithms and daemon |
| **Brokers** | `brokers/` | Broker abstraction layer |
| **Bridge** | `bridge/` | MT4/MT5 WebSocket/REST bridge |
| **Expert Advisors** | `mql4/`, `mql5/` | MetaTrader trading bots |
| **Config** | `configs/` | YAML configuration files |
| **Schemas** | `schemas/` | JSON schema definitions |
| **Tests** | `tests/` | Python unit tests |
| **Docs** | `docs/`, `*.md` | Documentation |

## Directory Purpose

### Frontend (Flutter)

```
lib/
├── models/         # Data models, app state (Provider)
├── screens/        # Full-screen views
│   ├── modern_dashboard_screen.dart   # Main trading dashboard
│   ├── broker_config_screen.dart      # Broker configuration
│   ├── portfolio_screen.dart          # Portfolio view
│   ├── quantum_screen.dart            # Quantum predictions
│   └── settings_screen.dart           # App settings
├── services/       # Business logic, API clients
│   ├── broker_service.dart            # Broker abstraction
│   ├── ml_service.dart                # ML API client
│   ├── mt4_service.dart               # MT4 API client
│   └── telegram_service.dart          # Telegram notifications
└── widgets/        # Reusable components
    ├── signal_card.dart               # Trading signal display
    ├── trend_indicator.dart           # Trend visualization
    └── connection_status.dart         # Broker connection status
```

### Backend (Python)

```
backend/
├── validators/     # JSON schema validation
│   └── json_validator.py              # Validator implementation
└── config_loader.py                   # Configuration management

ml/
├── quantum_predictor.py               # Main prediction model
├── predictor_daemon_v2.py             # Prediction service daemon
└── postprocessing.py                  # Prediction sanity checks

brokers/
├── base_provider.py                   # Abstract broker interface
├── factory.py                         # Broker provider factory
├── generic_rest_provider.py           # Generic REST implementation
└── mt4_bridge_provider.py             # MT4 bridge implementation
```

### Configuration & Schemas

```
configs/
└── config.yaml     # Main application configuration

schemas/
├── prediction_response.json           # Prediction API response schema
├── market_snapshot.json               # Market data schema
├── signal_object.json                 # Trading signal schema
├── order_request.json                 # Order placement schema
├── order_response.json                # Order status schema
└── account_info.json                  # Account info schema
```

### Testing

```
tests/
├── test_json_schema.py                # Schema validation tests
├── test_broker_providers.py           # Broker abstraction tests
├── test_prediction_sanity.py          # Prediction validation tests
└── test_phase4_schemas.py             # Additional schema tests
```

## File Naming Conventions

### Python
- **Modules:** `snake_case.py`
- **Classes:** `PascalCase`
- **Functions:** `snake_case()`
- **Constants:** `UPPER_SNAKE_CASE`

### Dart/Flutter
- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables:** `camelCase`
- **Private:** `_privateVariable`

### Documentation
- **README files:** `UPPERCASE.md` (README.md, ARCHITECTURE.md)
- **Guides:** `UPPERCASE.md` (BUILD_GUIDE.md, TESTING.md)
- **Policies:** `UPPERCASE.md` (SECURITY.md, CONTRIBUTING.md)

## Code Organization Principles

### 1. Separation of Concerns
- **Presentation:** Flutter UI (`lib/screens/`, `lib/widgets/`)
- **Business Logic:** Services (`lib/services/`, `ml/`, `brokers/`)
- **Data:** Models (`lib/models/`, data classes in Python)
- **Validation:** Validators (`backend/validators/`)

### 2. Single Responsibility
- Each file has one clear purpose
- Classes do one thing well
- Functions are small and focused

### 3. Dependency Direction
```
UI (screens) → Services → Models
Services → Validators → Schemas
Daemon → ML Engine → Broker Providers
```

### 4. Configuration Over Code
- Settings in `configs/config.yaml`, not hardcoded
- Environment-specific configuration via `ENV` variable
- Broker selection via configuration, not code changes

## Adding New Components

### New ML Model

1. Create `ml/your_model.py`
2. Implement prediction interface (match quantum_predictor.py)
3. Add to `predictor_daemon_v2.py`
4. Add tests in `tests/test_your_model.py`
5. Document in ARCHITECTURE.md

### New Broker Provider

1. Create `brokers/your_broker_provider.py`
2. Extend `BaseBrokerProvider`
3. Add `@register_broker('your_broker')` decorator
4. Update `configs/config.yaml`
5. Add Flutter enum in `lib/services/broker_service.dart`
6. Test with `tests/test_broker_providers.py`

### New Screen (Flutter)

1. Create `lib/screens/your_screen.dart`
2. Add to `lib/main.dart` navigation
3. Create supporting widgets in `lib/widgets/`
4. Add required services in `lib/services/`
5. Update app state in `lib/models/app_state.dart` if needed

### New Schema

1. Define `schemas/your_schema.json`
2. Add validation in `backend/validators/json_validator.py`
3. Create tests in `tests/test_your_schema.py`
4. Document in ARCHITECTURE.md

## Common Tasks

### Run Prediction Daemon
```bash
python ml/predictor_daemon_v2.py --symbols EURUSD,GBPUSD --interval 10
```

### Start Bridge Server
```bash
cd bridge
node server.js
```

### Run Flutter App
```bash
flutter run -d linux  # or windows, macos, android
```

### Run Tests
```bash
# Python
pytest tests/ -v

# Flutter
flutter test
```

### Build for Release
```bash
# Flutter Desktop
flutter build linux --release

# Python Docker
docker build -f Dockerfile.ml -t quantumtrader-ml .
```

## Documentation Structure

```
docs/
├── policies/       # Governance and contribution policies
└── security/       # Security documentation

Root level:
├── README.md                  # Main project overview
├── ARCHITECTURE.md            # System architecture (detailed)
├── PROJECT_STRUCTURE.md       # This file (quick reference)
├── CONTRIBUTING.md            # Contribution guidelines
├── SECURITY.md                # Security policy
├── BUILD_GUIDE.md             # Build instructions
├── DESKTOP_SETUP.md           # Desktop app setup
├── TESTING.md                 # Testing guide
└── IMPLEMENTATION_GUIDE.md    # Phase-by-phase implementation
```

## Configuration Files

```
.env.example        # Environment variable template (copy to .env)
.gitignore          # Git ignore rules
.gitleaks.toml      # Secret scanning configuration
pubspec.yaml        # Flutter dependencies
docker-compose.test.yml         # Docker test setup
Dockerfile.ml       # ML service Docker image
```

## Output Directories

```
predictions/        # Generated prediction files
├── predictions_output.json     # Latest predictions

bridge/data/        # Bridge server market data cache
├── EURUSD_market.json
├── GBPUSD_market.json
└── ...

logs/               # Application logs (created at runtime)
├── daemon.log      # Prediction daemon logs
└── ...
```

## Git Workflow

### Branch Structure
- `main`: Production-ready code
- `desktop`: Desktop app development (current)
- `feature/*`: Feature branches
- `hotfix/*`: Emergency fixes

### Commit Message Format
```
<type>: <description>

<detailed explanation if needed>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:** feat, fix, docs, style, refactor, test, chore

## Dependencies

### Python
- NumPy, pandas: Data processing
- scikit-learn: ML algorithms
- jsonschema: Validation
- PyYAML: Configuration
- requests: HTTP client

### Flutter
- provider, get: State management
- fl_chart, syncfusion_flutter_charts: Charts
- dio, http: HTTP clients
- hive: Local storage
- web_socket_channel: WebSocket

### Node.js (Bridge)
- express: Web framework
- ws: WebSocket
- express-validator: Validation
- dotenv: Environment variables

## Environment Variables

See `.env.example` for full list. Key variables:

```bash
# Environment
ENV=production                   # production|staging|demo|development

# Broker
BROKER_PROVIDER=mt4              # mt4|mt5|oanda|binance|generic
BROKER_API_URL=http://localhost:8080
BROKER_API_KEY=                  # Optional
BROKER_API_SECRET=               # Optional

# Features
USE_SYNTHETIC_DATA=false         # true|false (forced false in production)

# Security
JWT_SECRET=                      # For API authentication
```

## Troubleshooting

### Import Errors (Python)
- Ensure project root in `PYTHONPATH`
- Use `sys.path.insert(0, os.path.dirname(...))` in scripts

### Flutter Build Errors
- Run `flutter pub get`
- Check `pubspec.yaml` for version conflicts
- Clean build: `flutter clean && flutter pub get`

### Broker Connection Issues
- Verify `BROKER_API_URL` in `.env`
- Check bridge server is running
- Test connection in broker config screen

### Schema Validation Failures
- Check schema files in `schemas/`
- Review validation logs
- Use `safe_validate_and_log()` for debugging

## Performance Tips

1. **Python:**
   - Use NumPy for array operations
   - Batch predictions when possible
   - Cache broker data appropriately

2. **Flutter:**
   - Use `const` constructors
   - Implement `shouldRebuild` in providers
   - Lazy load data
   - Optimize chart rendering

3. **Bridge:**
   - Use connection pooling
   - Implement request debouncing
   - Cache market data

## Security Checklist

- [ ] No secrets in code (use `.env`)
- [ ] `.env` in `.gitignore`
- [ ] Gitleaks pre-commit hook enabled
- [ ] Broker API keys properly secured
- [ ] Schema validation on all inputs
- [ ] Synthetic data disabled in production

---

For detailed architecture information, see [ARCHITECTURE.md](ARCHITECTURE.md).

For contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

For build instructions, see [BUILD_GUIDE.md](BUILD_GUIDE.md).
