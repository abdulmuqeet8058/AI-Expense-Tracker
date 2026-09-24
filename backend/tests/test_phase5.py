import calendar
from datetime import datetime, timezone

from app.ml.recurring import recurring_payment_detector


def _months_before(moment: datetime, months: int, day: int) -> datetime:
    month_index = moment.month - 1 - months
    year = moment.year + month_index // 12
    month = month_index % 12 + 1
    valid_day = min(day, calendar.monthrange(year, month)[1])
    return datetime(year, month, valid_day, 12, tzinfo=timezone.utc)


def _add_subscription(
    auth,
    *,
    description: str,
    amount: float,
    date: datetime,
):
    response = auth.client.post(
        "/api/expenses/",
        headers=auth.headers,
        json={
            "amount": amount,
            "description": description,
            "category": "Entertainment",
            "payment_method": "card",
            "date": date.isoformat(),
        },
    )
    assert response.status_code == 200, response.text


def test_recurring_payments_requires_authentication(app_client):
    response = app_client.get("/api/ml/recurring-payments")
    assert response.status_code == 401


def test_detects_monthly_payment_and_price_increase(auth):
    now = datetime.now(timezone.utc)
    anchor_day = max(1, min(28, now.day - 3))
    entries = [
        ("Netflix monthly subscription", 1000),
        ("NETFLIX.COM subscription", 1000),
        ("Netflix payment", 1200),
    ]
    for months, (description, amount) in zip((2, 1, 0), entries):
        _add_subscription(
            auth,
            description=description,
            amount=amount,
            date=_months_before(now, months, anchor_day),
        )

    response = auth.client.get(
        "/api/ml/recurring-payments",
        headers=auth.headers,
    )
    assert response.status_code == 200, response.text
    data = response.json()

    assert data["summary"]["detected_count"] == 1
    assert data["summary"]["monthly_commitment"] == 1200
    assert data["summary"]["price_increases"] == 1
    assert data["summary"]["currency"] == "PKR"

    payment = data["recurring_payments"][0]
    assert payment["category"] == "Entertainment"
    assert payment["cadence"] == "Monthly"
    assert payment["occurrence_count"] == 3
    assert payment["expected_amount"] == 1200
    assert payment["price_change_percent"] == 20
    assert payment["confidence"] >= 0.58
    assert payment["detection_method"] == "tfidf_periodicity"


def test_ignores_expenses_without_a_reliable_pattern(auth):
    now = datetime.now(timezone.utc)
    for months, description in zip(
        (5, 2, 0),
        ("Cinema ticket", "Theme park", "Music concert"),
    ):
        _add_subscription(
            auth,
            description=description,
            amount=1500,
            date=_months_before(now, months, 5),
        )
    for months in (13, 12, 1, 0):
        _add_subscription(
            auth,
            description="Irregular membership",
            amount=2500,
            date=_months_before(now, months, 8),
        )

    response = auth.client.get(
        "/api/ml/recurring-payments",
        headers=auth.headers,
    )
    assert response.status_code == 200
    assert response.json()["recurring_payments"] == []


def test_monthly_detection_allows_billing_date_movement():
    result = recurring_payment_detector.analyze(
        [
            {
                "description": "Netflix subscription",
                "amount": 1000,
                "category": "Entertainment",
                "date": datetime(2026, 7, 14, tzinfo=timezone.utc),
            },
            {
                "description": "Netflix subscription",
                "amount": 1000,
                "category": "Entertainment",
                "date": datetime(2026, 8, 11, tzinfo=timezone.utc),
            },
            {
                "description": "Netflix.com subscription",
                "amount": 1200,
                "category": "Entertainment",
                "date": datetime(2026, 9, 21, tzinfo=timezone.utc),
            },
        ],
        as_of=datetime(2026, 9, 21, 13, tzinfo=timezone.utc),
    )

    assert result["summary"]["detected_count"] == 1
    assert result["recurring_payments"][0]["cadence"] == "Monthly"
