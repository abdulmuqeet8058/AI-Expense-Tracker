AI EXPENSE TRACKER

A Flutter expense-management app with a FastAPI backend. It tracks income,
expenses and budgets, then uses machine learning to turn transaction history
into practical financial insights.

KEY FEATURES

- Secure registration, login and saved sessions
- Income and expense tracking with search and filters
- Monthly budgets, alerts and spending charts
- Automatic expense categorization with confidence scores
- Next-month spending forecasts and unusual-spending alerts
- Personalized financial insights
- Recurring bill and subscription detection
- Upcoming-payment and subscription price-increase warnings
- Light and dark themes

AI FEATURES

- Categorization: TF-IDF and XGBoost classify expense descriptions.
- Forecasting: XGBoost estimates next month's category spending.
- Anomaly detection: Isolation Forest finds unusual spending activity.
- Recurring payments: TF-IDF merchant matching and date-pattern analysis
  identify weekly, monthly, quarterly and yearly payments.

Recurring-payment detection needs at least three similar transactions. It can
recognize description variations, estimate the next payment date, calculate
monthly commitments and highlight price increases.

TECH STACK

Frontend: Flutter, Dart, Riverpod, Dio, Hive and fl_chart
Backend: Python, FastAPI, MongoDB, Motor and Pydantic
Machine learning: scikit-learn, XGBoost, pandas and NumPy
Security: JWT authentication, bcrypt and secure local token storage

RUN THE PROJECT

Requirements: Python 3.11+, Flutter and a running MongoDB service.

First-time backend setup:

cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.\.venv\Scripts\python.exe ml_training\train_categorizer.py
.\.venv\Scripts\python.exe ml_training\train_phase4b.py

Start the backend:

cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Start the Flutter app in another terminal:

cd frontend
flutter pub get
flutter run

The Android device and computer must use the same network. The configured API
address is http://192.168.100.5:8000/api.

API documentation: http://localhost:8000/docs

TESTING

Backend:

cd backend
.\.venv\Scripts\python.exe -m pytest

Flutter static analysis:

cd frontend
flutter analyze
