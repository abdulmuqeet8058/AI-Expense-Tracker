SMART EXPENSE TRACKER - PHASE 4A

Phase 4A adds trained AI expense categorization on top of the Phase 3 finance features.

CURRENT FEATURES

- Flutter application with Material 3 light and dark themes
- Onboarding flow for first-time users
- User registration and login
- JWT access and refresh token generation
- Secure token storage on the client
- Automatic saved-session validation at startup
- Authenticated dashboard and logout
- Add income and expense transactions
- Fixed financial categories and payment methods
- Search, filter, date range, and sorting controls
- Transaction detail view and deletion
- Local Hive cache for the expense list
- Monthly category budgets with configurable alert thresholds
- Live budget usage and over-budget warnings
- Dashboard totals, net balance, top categories, and recent activity
- Daily, monthly, and category spending charts
- Category breakdowns and six-month spending trends
- Monthly financial reports and data export endpoints
- Automatic expense categorization using TF-IDF text features and XGBoost
- Live AI suggestions, confidence scores, and alternative categories
- User corrections stored as feedback for future model improvement
- FastAPI backend with MongoDB
- API health endpoint and interactive Swagger documentation
- Basic in-memory API rate limiting

TECH STACK

Frontend:
- Flutter and Dart
- Riverpod state management
- Dio HTTP client
- fl_chart data visualization
- flutter_secure_storage
- shared_preferences

Backend:
- Python 3.11+
- FastAPI and Uvicorn
- MongoDB with Motor
- Pydantic
- scikit-learn, XGBoost, pandas, NumPy, SciPy, and joblib
- bcrypt password hashing
- JWT authentication

PROJECT STRUCTURE

Expense tracker/
|-- backend/
|   |-- app/
|   |   |-- routes/auth.py
|   |   |-- routes/budgets.py
|   |   |-- routes/analytics.py
|   |   |-- routes/ml.py
|   |   |-- ml/categorizer.py
|   |   |-- auth.py
|   |   |-- config.py
|   |   |-- database.py
|   |   |-- main.py
|   |   |-- models.py
|   |   `-- utils.py
|   |-- tests/test_auth.py
|   |-- ml_training/generate_data.py
|   |-- ml_training/train_categorizer.py
|   |-- .env.example
|   `-- requirements.txt
|-- frontend/
|   |-- lib/
|   |   |-- models/user.dart
|   |   |-- providers/
|   |   |-- screens/
|   |   |-- services/
|   |   |-- app.dart
|   |   |-- config.dart
|   |   |-- main.dart
|   |   `-- theme.dart
|   `-- pubspec.yaml
`-- README.txt

RUNNING LOCALLY

1. Start MongoDB

MongoDB must be running at:

mongodb://localhost:27017

On Windows, check the MongoDB service with:

Get-Service MongoDB
Start-Service MongoDB

2. Start the backend

Open PowerShell in the project folder and run:

cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
python ml_training\train_categorizer.py
python -m uvicorn app.main:app --reload

The API is available at:

http://localhost:8000

Swagger API documentation:

http://localhost:8000/docs

3. Start the Flutter application

Open another terminal:

cd frontend
flutter pub get
flutter run

The default API address is configured for the current physical Android device network:

http://192.168.100.5:8000/api

For Chrome or desktop, run:

flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api

TESTING

Backend:

cd backend
pytest

Flutter:

cd frontend
flutter analyze
flutter test

PLANNED NEXT PHASES

Phase 4B will add spending forecasts, anomaly detection, and personalized insights.
Phase 5 will add AI-assisted receipt scanning.
