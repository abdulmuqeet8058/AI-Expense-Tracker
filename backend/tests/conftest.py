"""Shared pytest fixtures for the Phase 1 authentication API."""
import uuid
from types import SimpleNamespace

import pytest

CATEGORIES = [
    "Food & Dining", "Transportation", "Shopping", "Entertainment",
    "Bills & Utilities", "Healthcare", "Education", "Groceries", "Travel",
    "Rent", "Insurance", "Personal Care", "Miscellaneous",
]

try:
    import motor.motor_asyncio
    from mongomock_motor import AsyncMongoMockClient

    motor.motor_asyncio.AsyncIOMotorClient = AsyncMongoMockClient
    _MOCK_READY = True
except Exception:
    _MOCK_READY = False


@pytest.fixture(scope="session")
def app_client():
    if not _MOCK_READY:
        pytest.skip("mongomock-motor not installed")

    from fastapi.testclient import TestClient
    from app.main import app

    with TestClient(app) as client:
        yield client


@pytest.fixture
def categories():
    return list(CATEGORIES)


@pytest.fixture
def auth(app_client):
    email = f"user_{uuid.uuid4().hex[:12]}@example.com"
    password = "S3cret!pass"
    response = app_client.post(
        "/api/auth/register",
        json={"email": email, "password": password, "full_name": "Test User"},
    )
    assert response.status_code in (200, 201), response.text
    token = response.json()["access_token"]
    return SimpleNamespace(
        client=app_client,
        headers={"Authorization": f"Bearer {token}"},
        email=email,
        password=password,
    )
