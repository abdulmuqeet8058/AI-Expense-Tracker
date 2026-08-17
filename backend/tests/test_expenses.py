def test_categories_endpoint(auth, categories):
    r = auth.client.get("/api/expenses/categories", headers=auth.headers)
    assert r.status_code == 200, r.text
    cats = r.json()
    assert len(cats) == 13
    assert set(cats) == set(categories)


def test_create_expense_auto_categorizes(auth, categories):
    r = auth.client.post(
        "/api/expenses/",
        headers=auth.headers,
        json={"amount": 1450.0, "description": "Dinner at Kolachi restaurant"},
    )
    assert r.status_code in (200, 201), r.text
    body = r.json()
    assert body["id"]
    assert body["amount"] == 1450.0
    # category was left null, so the ML service should have filled it in
    assert body["category"] in categories


def test_create_list_and_delete(auth):
    c, h = auth.client, auth.headers

    created = []
    for desc, amt in [("Uber to the office", 300.0), ("Groceries at Imtiaz", 2200.0)]:
        r = c.post("/api/expenses/", headers=h, json={"amount": amt, "description": desc})
        assert r.status_code in (200, 201), r.text
        created.append(r.json()["id"])

    listed = c.get("/api/expenses/", headers=h)
    assert listed.status_code == 200, listed.text
    ids = [e["id"] for e in listed.json()]
    for cid in created:
        assert cid in ids

    d = c.delete(f"/api/expenses/{created[0]}", headers=h)
    assert d.status_code == 200, d.text
    assert d.json().get("deleted") is True

    after = c.get("/api/expenses/", headers=h)
    ids_after = [e["id"] for e in after.json()]
    assert created[0] not in ids_after
    assert created[1] in ids_after


def test_expenses_require_auth(app_client):
    r = app_client.get("/api/expenses/")
    assert r.status_code in (401, 403)
