SMART EXPENSE TRACKER - PHASE 1

Phase 1 establishes the application foundation and authentication flow.

CURRENT FEATURES

- Flutter application with Material 3 light and dark themes
- Onboarding flow for first-time users
- User registration and login
- JWT access and refresh token generation
- Secure token storage on the client
- Automatic saved-session validation at startup
- Authenticated home screen and logout
- FastAPI backend with MongoDB
- API health endpoint and interactive Swagger documentation
- Basic in-memory API rate limiting

TECH STACK

Frontend:
- Flutter and Dart
- Riverpod state management
- Dio HTTP client
- flutter_secure_storage
- shared_preferences

Backend:
- Python 3.11+
- FastAPI and Uvicorn
- MongoDB with Motor
- Pydantic
- bcrypt password hashing
- JWT authentication

PROJECT STRUCTURE

Expense tracker/
|-- backend/
|   |-- app/
|   |   |-- routes/auth.py
|   |   |-- auth.py
|   |   |-- config.py
|   |   |-- database.py
|   |   |-- main.py
|   |   |-- models.py
|   |   `-- utils.py
|   |-- tests/test_auth.py
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

The default API address is configured for an Android emulator:

http://10.0.2.2:8000/api

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

PLANNED NEXT PHASE

Phase 2 will introduce expense and income management, categories, searching, filtering, and local
expense caching.
