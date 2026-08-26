def test_ai_categorization_requires_login(app_client):
    response = app_client.post("/api/ml/categorize", json={"description": "Uber ride"})
    assert response.status_code == 401


def test_ai_returns_category_confidence_and_alternatives(auth):
    response = auth.client.post(
        "/api/ml/categorize",
        headers=auth.headers,
        json={
            "description": "Uber ride to office",
            "amount": 850,
            "payment_method": "wallet",
        },
    )
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["category"] == "Transportation"
    assert 0 <= result["confidence"] <= 1
    assert result["model_mode"] in {"ml", "rules_fallback"}
    assert isinstance(result["alternatives"], list)


def test_expense_is_auto_categorized_and_feedback_is_saved(auth):
    created = auth.client.post(
        "/api/expenses/",
        headers=auth.headers,
        json={
            "description": "Dinner at Pizza Hut",
            "amount": 2400,
            "payment_method": "card",
        },
    )
    assert created.status_code == 200, created.text
    expense = created.json()
    assert expense["category"] == "Food & Dining"
    assert expense["confidence_score"] is not None
    assert expense["categorization_source"] in {"ml", "rules_fallback"}

    feedback = auth.client.post(
        f"/api/ml/feedback/{expense['id']}",
        headers=auth.headers,
        json={"correct_category": "Entertainment"},
    )
    assert feedback.status_code == 200, feedback.text
    assert feedback.json()["category"] == "Entertainment"

    analytics = auth.client.get("/api/ml/analytics", headers=auth.headers)
    assert analytics.status_code == 200
    assert analytics.json()["feedback_count"] == 1
    assert analytics.json()["model"]["model"] == "TF-IDF + XGBoost classifier"
