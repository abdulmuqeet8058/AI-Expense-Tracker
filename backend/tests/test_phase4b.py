from datetime import datetime, timezone


def _month_before(moment: datetime, months: int) -> datetime:
    year = moment.year
    month = moment.month - months
    while month <= 0:
        month += 12
        year -= 1
    return datetime(year, month, 10, 12, tzinfo=timezone.utc)


def _expense(auth, *, amount: float, date: datetime, description: str = "Pizza dinner"):
    response = auth.client.post(
        "/api/expenses/",
        headers=auth.headers,
        json={
            "amount": amount,
            "description": description,
            "category": "Food & Dining",
            "payment_method": "card",
            "date": date.isoformat(),
        },
    )
    assert response.status_code == 200, response.text


def test_phase4b_endpoints_require_authentication(app_client):
    assert app_client.get("/api/ml/predict-spending").status_code == 401
    assert app_client.get("/api/ml/insights").status_code == 401


def test_forecast_anomaly_and_personalized_insights(auth):
    now = datetime.now(timezone.utc)
    for months, amount in [(4, 7000), (3, 7600), (2, 8100), (1, 8500)]:
        _expense(auth, amount=amount, date=_month_before(now, months))

    current_dates = [
        datetime(now.year, now.month, day, 12, tzinfo=timezone.utc)
        for day in (1, 2, 3)
    ]
    for date, amount in zip(current_dates, (900, 1100, 14000)):
        _expense(auth, amount=amount, date=date)

    forecast_response = auth.client.get(
        "/api/ml/predict-spending", headers=auth.headers
    )
    assert forecast_response.status_code == 200, forecast_response.text
    forecast = forecast_response.json()
    assert forecast["predictions"]["Food & Dining"] > 0
    assert forecast["total_predicted"] > 0
    assert forecast["model_mode"] in {"ml", "mixed", "history_fallback"}
    assert len(forecast["forecast_period"]) == 7

    insight_response = auth.client.get("/api/ml/insights", headers=auth.headers)
    assert insight_response.status_code == 200, insight_response.text
    result = insight_response.json()
    assert result["insights"]
    assert any(item["type"] == "forecast" for item in result["insights"])
    assert any(item["type"] == "anomaly" for item in result["anomalies"])
    assert result["models"]["forecast_model"] == "XGBoost regressor"
    assert result["models"]["anomaly_model"] == "Isolation Forest"


def test_ml_analytics_reports_all_phase4_models(auth):
    response = auth.client.get("/api/ml/analytics", headers=auth.headers)
    assert response.status_code == 200
    data = response.json()
    assert data["model"]["model"] == "TF-IDF + XGBoost classifier"
    assert "forecast_loaded" in data["intelligence"]
    assert "anomaly_loaded" in data["intelligence"]
