# QuantumTrader-Pro
Quantum-powered trading system for MT4 with machine learning, Telegram control, and probability dashboard.

README.md

📈 First Sterling QuantumTrader Pro

Author: Dezirae Stark
License: Proprietary – All rights reserved (see LICENSE.txt)
Version: 1.0.0

🔮 Overview

First Sterling QuantumTrader Pro is an advanced, modular trading system for MetaTrader 4 (MT4), combining:

Quantum probability-inspired forecasting

Dynamic momentum analysis using Bill Williams’ AO & AC

Smart visual dashboards with predictive overlays

Machine learning-assisted signal filtering

Telegram bot remote control


Designed to forecast market behavior 3–8 candles into the future across multiple symbols with powerful data visualizations and real-time control.

📦 Components

🧠 Expert Advisor (EA)

File: QuantumTrader_EA.mq4

Role: Core trade engine with toggles for aggressive/conservative logic, long/short permission, and quantum-based entry logic


📊 Dashboard Indicator

File: QuantumTrader_Dashboard.mq4

Role: Color-coded trend probability zones, live feedback, intuitive GUI


🤖 Machine Learning Signal Processor

File: QuantumML_SignalProcessor.py

Role: Uses Random Forest Classifier for signal filtering and real-time predictions based on AO/AC and quantum model inputs


📱 Telegram Bot

File: QuantumTrader_TelegramBot.py

Role: Secure remote control and monitoring of the EA with commands like /status, /toggle, etc.


🗂️ Config & Data Files

QuantumSignals_Live.csv: Real-time signal logs

Predictions.csv: ML batch prediction input

TelegramCommands.json: Bot command registry


🖥️ Features

✅ Quantum probability engine

✅ 3–8 candle projection logic

✅ Aggressive/Conservative toggle

✅ Trailing SL/TP logic

✅ Dashboard registration + auto-link to EA

✅ Multi-symbol trade monitoring

✅ Full trade log with P/L tracking

✅ Mobile-friendly layout + Telegram integration


📱 Mobile & Remote Access

Telegram bot allows full monitoring + control of trading status

Future version supports mobile-optimized web interface (planned)


⚠️ License & Legal Use

This software is licensed under a Proprietary License.

❌ Commercial use is strictly prohibited without express permission

✅ You may view, study, or use personally (non-commercial)

🚫 Unauthorized distribution, resale, or cloning will result in prosecution


Read LICENSE.txt for full legal terms.

🔧 Installation Guide

1. Copy .mq4 files into your MT4 Experts and Indicators folders


2. Run QuantumML_SignalProcessor.py (requires Python 3.10+, pandas, sklearn)


3. Configure Telegram bot token and run QuantumTrader_TelegramBot.py


4. Load EA and Dashboard on MT4 chart


5. Use Telegram for real-time status or control



📬 Contact & Permissions

For commercial use, collaborations, or legal questions, contact: Dezirae Stark
📧 [seidhberendir@tutamail.com]
🔗 GitHub: [Dezirae-Stark]


---

Made with precision, vision, and honor.
“Let the probabilities speak.”

