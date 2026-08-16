import uuid


def _new_email():
    return f"auth_{uuid.uuid4().hex[:12]}@example.com"


def test_register_returns_token(app_client):
    email = _new_email()
    r = app_client.post(
        "/api/auth/register",
        json={"email": email, "password": "pw12345678", "full_name": "New User"},
    )
    assert r.status_code in (200, 201), r.text
    body = r.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["user"]["email"] == email
    # currency defaults to PKR when not supplied
    assert body["user"]["currency"] == "PKR"


def test_register_duplicate_email_rejected(app_client):
    payload = {"email": _new_email(), "password": "pw12345678", "full_name": "Dup"}
    first = app_client.post("/api/auth/register", json=payload)
    assert first.status_code in (200, 201), first.text

    second = app_client.post("/api/auth/register", json=payload)
    assert second.status_code in (400, 409), second.text


def test_login_ok_and_wrong_password(app_client):
    email = _new_email()
    app_client.post(
        "/api/auth/register",
        json={"email": email, "password": "rightpass1", "full_name": "Login User"},
    )

    ok = app_client.post("/api/auth/login", json={"email": email, "password": "rightpass1"})
    assert ok.status_code == 200, ok.text
    assert ok.json()["access_token"]

    bad = app_client.post("/api/auth/login", json={"email": email, "password": "nope"})
    assert bad.status_code in (400, 401)


def test_me_returns_current_user(auth):
    r = auth.client.get("/api/auth/me", headers=auth.headers)
    assert r.status_code == 200, r.text
    assert r.json()["email"] == auth.email


def test_me_requires_token(app_client):
    r = app_client.get("/api/auth/me")
    # HTTPBearer returns 403 when the header is missing, 401 on a bad token.
    assert r.status_code in (401, 403)
