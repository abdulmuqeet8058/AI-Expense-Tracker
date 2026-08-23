from datetime import datetime, timezone


def test_create_budget_and_calculate_live_spending(auth):
    now = datetime.now(timezone.utc)
    created_expense = auth.client.post(
        "/api/expenses/",
        headers=auth.headers,
        json={
            "amount": 2500,
            "description": "Monthly groceries",
            "category": "Groceries",
            "date": now.isoformat(),
        },
    )
    assert created_expense.status_code in (200, 201), created_expense.text

    created_budget = auth.client.post(
        "/api/budgets/",
        headers=auth.headers,
        json={
            "category": "Groceries",
            "monthly_limit": 10000,
            "month": now.month,
            "year": now.year,
            "alert_threshold": 80,
        },
    )
    assert created_budget.status_code in (200, 201), created_budget.text
    body = created_budget.json()
    assert body["category"] == "Groceries"
    assert body["current_spent"] == 2500


def test_dashboard_and_chart_endpoints(auth):
    dashboard = auth.client.get("/api/analytics/dashboard", headers=auth.headers)
    assert dashboard.status_code == 200, dashboard.text
    assert "total_spent_month" in dashboard.json()
    assert "budget_progress" in dashboard.json()
    assert "top_categories" in dashboard.json()

    charts = auth.client.get("/api/analytics/charts", headers=auth.headers)
    assert charts.status_code == 200, charts.text
    assert set(charts.json()) == {"by_category", "daily", "monthly"}
