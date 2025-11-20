# QuantumTrader-Pro Architecture

> **Version:** 2.1.0
> **Last Updated:** 2025-01-15
> **Maintainer:** Dezirae Stark

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Architecture Layers](#architecture-layers)
- [Component Diagram](#component-diagram)
- [Data Flow](#data-flow)
- [Technology Stack](#technology-stack)
- [Development Workflow](#development-workflow)

---

## Overview

QuantumTrader-Pro is a multi-platform algorithmic trading system that combines quantum mechanics principles with machine learning for forex and cryptocurrency trading. The system consists of multiple interconnected components:

- **Python Backend**: ML prediction engine, broker abstraction, API server
- **Flutter Desktop/Mobile**: Cross-platform trading dashboard
- **Bridge Server**: WebSocket/REST bridge for MT4/MT5 integration
- **Expert Advisors**: MQL4/MQL5 trading bots
- **Configuration System**: YAML-based environment configuration

## Repository Structure

```
QuantumTrader-Pro/
│
├── 📱 Flutter App (Desktop/Mobile)
│   ├── lib/                          # Flutter/Dart source code
│   │   ├── models/                   # Data models and state management
│   │   ├── screens/                  # UI screens (dashboard, portfolio, etc.)
│   │   ├── services/                 # Business logic and API services
│   │   └── widgets/                  # Reusable UI components
│   ├── android/                      # Android-specific configuration
│   ├── assets/                       # Images, icons, samples
│   └── pubspec.yaml                  # Flutter dependencies
│
├── 🐍 Python Backend
│   ├── backend/                      # Core backend modules
│   │   ├── validators/               # JSON schema validation
│   │   └── config_loader.py          # Configuration management
│   ├── ml/                           # Machine learning engine
│   │   ├── quantum_predictor.py      # Quantum-inspired prediction model
│   │   ├── predictor_daemon_v2.py    # Prediction service daemon
│   │   └── postprocessing.py         # Prediction sanity checks
│   ├── brokers/                      # Broker abstraction layer
│   │   ├── base_provider.py          # Abstract broker interface
│   │   ├── factory.py                # Broker provider factory
│   │   ├── generic_rest_provider.py  # Generic REST API broker
│   │   └── mt4_bridge_provider.py    # MT4 bridge integration
│   └── backtest/                     # Backtesting framework
│
├── 🌉 Bridge Server
│   └── bridge/                       # Node.js WebSocket/REST bridge
│       ├── server.js                 # Main server entry point
│       ├── middleware/               # Express middleware
│       └── data/                     # Market data cache
│
├── 📊 Trading Expert Advisors
│   ├── mql4/                         # MetaTrader 4 Expert Advisors
│   └── mql5/                         # MetaTrader 5 Expert Advisors
│
├── ⚙️ Configuration & Schemas
│   ├── configs/                      # YAML configuration files
│   │   └── config.yaml               # Main application config
│   └── schemas/                      # JSON schema definitions
│       ├── prediction_response.json  # Prediction API schema
│       ├── market_snapshot.json      # Market data schema
│       ├── signal_object.json        # Trading signal schema
│       ├── order_request.json        # Order placement schema
│       ├── order_response.json       # Order status schema
│       └── account_info.json         # Account info schema
│
├── 🧪 Testing
│   └── tests/                        # Python unit tests
│       ├── test_json_schema.py       # Schema validation tests
│       ├── test_broker_providers.py  # Broker abstraction tests
│       ├── test_prediction_sanity.py # Prediction validation tests
│       └── test_phase4_schemas.py    # Phase 4 schema tests
│
├── 📚 Documentation
│   ├── docs/                         # Detailed documentation
│   │   ├── policies/                 # Governance policies
│   │   └── security/                 # Security documentation
│   ├── README.md                     # Main project documentation
│   ├── ARCHITECTURE.md               # This file - architecture overview
│   ├── CONTRIBUTING.md               # Contribution guidelines
│   ├── SECURITY.md                   # Security policy
│   ├── BUILD_GUIDE.md                # Build instructions
│   ├── DESKTOP_SETUP.md              # Desktop app setup
│   ├── TESTING.md                    # Testing guide
│   └── IMPLEMENTATION_GUIDE.md       # Phase implementation guide
│
├── 🔧 Scripts & Tools
│   ├── scripts/                      # Utility scripts
│   │   └── ops/                      # Operational scripts
│   └── test_ml.sh                    # ML testing script
│
├── 📦 Output & Predictions
│   └── predictions/                  # Generated predictions output
│       └── predictions_output.json   # Latest predictions
│
└── 🔐 Configuration Files
    ├── .env.example                  # Environment variables template
    ├── .gitignore                    # Git ignore rules
    ├── .gitleaks.toml                # Secret scanning configuration
    ├── docker-compose.test.yml       # Docker test configuration
    └── Dockerfile.ml                 # ML service Docker image
```

## Architecture Layers

### 1. Presentation Layer (Flutter)

**Location:** `lib/`

**Responsibilities:**
- User interface rendering
- User interaction handling
- State management (Provider pattern)
- Local data persistence (Hive)
- Chart visualization (fl_chart, syncfusion)

**Key Components:**
- `screens/`: Full-screen views (dashboard, portfolio, quantum, settings)
- `widgets/`: Reusable UI components (signal cards, trend indicators)
- `models/`: Data models and app state
- `services/`: API clients and business logic

### 2. Application Layer (Python Backend)

**Location:** `backend/`, `ml/`, `brokers/`

**Responsibilities:**
- ML prediction generation
- Broker communication
- Configuration management
- Data validation
- Business logic

**Key Components:**
- **ML Engine** (`ml/`):
  - Quantum-inspired prediction algorithms
  - Chaos theory analysis
  - Prediction post-processing
  - Daemon service for continuous operation

- **Broker Abstraction** (`brokers/`):
  - Unified interface for all brokers
  - Provider implementations (MT4, MT5, Oanda, Binance, Generic)
  - Order management
  - Account information retrieval

- **Validation** (`backend/validators/`):
  - JSON schema validation
  - Business logic validation
  - Data sanity checks

### 3. Integration Layer (Bridge Server)

**Location:** `bridge/`

**Responsibilities:**
- WebSocket real-time communication
- REST API endpoints
- MT4/MT5 bridge functionality
- Market data caching
- Request routing

**Technology:** Node.js, Express, WebSocket

### 4. Trading Layer (Expert Advisors)

**Location:** `mql4/`, `mql5/`

**Responsibilities:**
- Execute trades on MT4/MT5
- Monitor positions
- Risk management
- Communication with bridge server

**Technology:** MQL4/MQL5

### 5. Data Layer

**Components:**
- **Configuration:** YAML files in `configs/`
- **Schemas:** JSON schemas in `schemas/`
- **Predictions:** Output files in `predictions/`
- **Local Storage:** Hive databases (Flutter)
- **Bridge Cache:** Market data files in `bridge/data/`

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        QuantumTrader-Pro                         │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│  Flutter App     │◄────────┤  Bridge Server   │◄────────┤  MetaTrader 4/5  │
│  (Desktop/Mobile)│         │  (Node.js)       │         │  + Expert Advisor│
└────────┬─────────┘         └────────┬─────────┘         └──────────────────┘
         │                            │
         │ REST API                   │ WebSocket/REST
         │                            │
         ▼                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Python Backend                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ ML Engine    │  │ Broker       │  │ Validators   │          │
│  │              │  │ Abstraction  │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
         │                            │
         │ Predictions                │ Orders/Quotes
         │                            │
         ▼                            ▼
┌──────────────────┐         ┌──────────────────┐
│  Prediction File │         │  Broker APIs     │
│  (JSON)          │         │  (REST/WS)       │
└──────────────────┘         └──────────────────┘
```

## Data Flow

### Prediction Generation Flow

```
1. [Predictor Daemon] Starts polling (configurable interval)
   ↓
2. [Broker Provider] Fetch market data (OHLC candles)
   ↓
3. [ML Engine] Generate predictions
   ↓
4. [Postprocessing] Validate and sanitize predictions
   ↓
5. [Validators] Validate against JSON schema
   ↓
6. [File Output] Write to predictions/predictions_output.json
   ↓
7. [Flutter App] Poll or fetch predictions
   ↓
8. [Dashboard] Display signals and predictions
```

### Trading Execution Flow

```
1. [Dashboard] User reviews signal
   ↓
2. [Flutter Service] Validate order parameters
   ↓
3. [Broker Service] Send order request
   ↓
4. [Broker Provider] Route to correct broker
   ↓
5. [Broker API] Execute order
   ↓
6. [Order Response] Return order confirmation
   ↓
7. [Dashboard] Update UI with order status
```

### Real-Time Data Flow

```
1. [MT4/MT5 EA] Publishes tick data
   ↓
2. [Bridge Server] Receives via WebSocket
   ↓
3. [Bridge Cache] Stores in data/ files
   ↓
4. [Flutter App] Subscribes to price stream
   ↓
5. [Dashboard Charts] Update in real-time
```

## Technology Stack

### Frontend (Flutter/Dart)
- **Framework:** Flutter 3.0+
- **State Management:** Provider, GetX
- **Charts:** fl_chart, Syncfusion Flutter Charts
- **Storage:** Hive, shared_preferences, flutter_secure_storage
- **HTTP:** dio, http
- **WebSocket:** web_socket_channel

### Backend (Python)
- **Language:** Python 3.11+
- **ML/Data:** NumPy, pandas, scikit-learn
- **HTTP:** requests
- **Validation:** jsonschema
- **Config:** PyYAML

### Bridge (Node.js)
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **WebSocket:** ws
- **Validation:** express-validator
- **Environment:** dotenv

### Trading (MQL4/MQL5)
- **Platform:** MetaTrader 4/5
- **Language:** MQL4/MQL5

### DevOps
- **Version Control:** Git, GitHub
- **CI/CD:** GitHub Actions (planned Phase 7)
- **Secrets:** GitHub Secrets, .env files
- **Documentation:** Markdown

## Development Workflow

### 1. Local Development Setup

```bash
# Clone repository
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro

# Python backend setup
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your configuration

# Flutter app setup
flutter pub get

# Bridge server setup
cd bridge
npm install
cd ..
```

### 2. Running Components

```bash
# Start Python prediction daemon
python ml/predictor_daemon_v2.py --symbols EURUSD,GBPUSD --interval 10

# Start bridge server (if using MT4/MT5)
cd bridge
node server.js
cd ..

# Run Flutter app
flutter run -d linux  # or windows, macos
```

### 3. Testing

```bash
# Python tests
pytest tests/ -v

# Flutter tests
flutter test

# ML validation
./test_ml.sh
```

### 4. Building for Production

```bash
# Flutter desktop build
flutter build linux --release  # or windows, macos

# Python backend (via Docker)
docker build -f Dockerfile.ml -t quantumtrader-ml .

# Bridge server
cd bridge
npm run build  # if applicable
```

## Configuration Management

### Environment Variables

Primary configuration via `.env` file:
- `ENV`: production | staging | demo | development
- `BROKER_PROVIDER`: mt4 | mt5 | oanda | binance | generic
- `BROKER_API_URL`: Broker API endpoint
- `USE_SYNTHETIC_DATA`: true | false (forced false in production)

### YAML Configuration

Main config in `configs/config.yaml`:
- Broker settings
- ML engine parameters
- API server configuration
- Trading parameters
- Risk management rules

### JSON Schemas

All API responses validated against schemas in `schemas/`:
- Ensures data integrity
- Prevents invalid signals
- Type safety across components

## Security Considerations

1. **Secrets Management:**
   - Never commit `.env` files
   - Use GitHub Secrets for CI/CD
   - Rotate API keys regularly

2. **Data Validation:**
   - All inputs validated via JSON schemas
   - Prediction sanity checks prevent invalid trades
   - Broker responses validated

3. **Production Safety:**
   - Synthetic data disabled in production
   - Strict validation enforced
   - Fail-safe defaults

4. **Code Scanning:**
   - Gitleaks prevents secret leaks
   - Dependabot for dependency updates
   - Security advisories in SECURITY.md

## Extension Points

### Adding a New Broker

1. Implement `BaseBrokerProvider` in `brokers/your_broker_provider.py`
2. Register with `@register_broker('your_broker')` decorator
3. Update `configs/config.yaml` with broker config
4. Add to Flutter `BrokerProvider` enum
5. Test with `test_broker_providers.py`

### Adding New ML Models

1. Create model in `ml/your_model.py`
2. Implement prediction interface
3. Add postprocessing if needed
4. Update `predictor_daemon_v2.py` to include model
5. Test with backtesting framework

### Adding New Schemas

1. Define schema in `schemas/your_schema.json`
2. Add validation function in `backend/validators/json_validator.py`
3. Create tests in `tests/test_your_schema.py`
4. Document schema in this file

## Performance Considerations

- **Prediction Latency:** Target <500ms per symbol
- **Bridge Throughput:** 100+ ticks/second
- **Flutter Rendering:** 60fps maintained
- **Memory Usage:** <500MB per component
- **Database:** Hive for fast local storage

## Monitoring & Logging

- **Python Backend:** Structured logging to `logs/daemon.log`
- **Bridge Server:** Express logging middleware
- **Flutter App:** Logger package with file output
- **Metrics:** Performance tracking in config

---

## References

- [README.md](README.md) - Project overview and quickstart
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute
- [BUILD_GUIDE.md](BUILD_GUIDE.md) - Detailed build instructions
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Phase-by-phase implementation
- [SECURITY.md](SECURITY.md) - Security policy and reporting

## Changelog

- **v2.1.0** (2025-01-15): Phase 1-5 complete, broker abstraction, modern UI
- **v2.0.0** (2024-11-13): Initial production release
- **v1.0.0** (2024-01-01): MVP release

---

**Built with ❤️ by Dezirae Stark**

For questions or support, open an issue on [GitHub](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues).
