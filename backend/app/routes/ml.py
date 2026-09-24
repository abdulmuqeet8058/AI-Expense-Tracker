from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_current_user
from app.database import budgets, expenses, predictions
from app.ml.categorizer import categorizer
from app.ml.intelligence import financial_intelligence
from app.ml.recurring import recurring_payment_detector
from app.models import (
    CategorizeIn,
    CategorizeOut,
    FeedbackIn,
    RecurringPaymentsOut,
)
from app.utils import now_utc, oid

router = APIRouter()


def _last_n_months(moment: datetime, count: int) -> list[tuple[int, int]]:
    months: list[tuple[int, int]] = []
    year, month = moment.year, moment.month
    for _ in range(count):
        months.append((year, month))
        month -= 1
        if month == 0:
            year -= 1
            month = 12
    return list(reversed(months))


def _month_start(year: int, month: int) -> datetime:
    return datetime(year, month, 1, tzinfo=timezone.utc)


def _next_month(moment: datetime) -> tuple[int, int]:
    if moment.month == 12:
        return moment.year + 1, 1
    return moment.year, moment.month + 1


async def _forecast_context(
    user_id,
    now: datetime,
) -> tuple[dict[str, list[float]], list[tuple[int, int]]]:
    month_keys = _last_n_months(now, 6)
    documents = await expenses.find({
        "user_id": user_id,
        "is_income": {"$ne": True},
        "date": {"$gte": _month_start(*month_keys[0])},
    }).to_list(length=5000)

    totals: dict[str, dict[tuple[int, int], float]] = {}
    for document in documents:
        moment = document.get("date")
        if not isinstance(moment, datetime):
            continue
        category = document.get("category") or "Miscellaneous"
        key = (moment.year, moment.month)
        totals.setdefault(category, {})[key] = (
            totals.setdefault(category, {}).get(key, 0.0)
            + float(document.get("amount") or 0)
        )

    # Turn the partial current month into a run-rate estimate before using it
    # as the most recent lag for the next-month prediction.
    days_in_month = (
        _month_start(*_next_month(now)) - _month_start(now.year, now.month)
    ).days
    current_key = (now.year, now.month)
    history: dict[str, list[float]] = {}
    for category, values in totals.items():
        adjusted = dict(values)
        if adjusted.get(current_key, 0) > 0:
            adjusted[current_key] *= days_in_month / max(now.day, 1)
        history[category] = [round(adjusted.get(key, 0.0), 2) for key in month_keys]
    return history, month_keys


@router.post("/categorize", response_model=CategorizeOut)
async def categorize_expense(payload: CategorizeIn, _: dict = Depends(get_current_user)):
    return categorizer.categorize(
        description=payload.description,
        amount=payload.amount,
        payment_method=payload.payment_method,
        when=payload.date,
    )


@router.post("/categorize-bulk", response_model=list[CategorizeOut])
async def categorize_bulk(payload: list[CategorizeIn], _: dict = Depends(get_current_user)):
    if len(payload) > 100:
        raise HTTPException(status_code=400, detail="Maximum 100 expenses per request")
    return [
        categorizer.categorize(item.description, item.amount, item.payment_method, item.date)
        for item in payload
    ]


@router.get("/predict-spending")
async def predict_spending(user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    now = now_utc()
    history, month_keys = await _forecast_context(uid, now)
    target_year, target_month = _next_month(now)
    forecast, model_mode = financial_intelligence.predict_spending(
        history,
        target_year=target_year,
        target_month=target_month,
    )
    return {
        "predictions": forecast,
        "total_predicted": round(sum(forecast.values()), 2),
        "months_analyzed": len(month_keys),
        "forecast_period": f"{target_year:04d}-{target_month:02d}",
        "model_mode": model_mode,
        "currency": user.get("currency", "PKR"),
    }


@router.get("/recurring-payments", response_model=RecurringPaymentsOut)
async def recurring_payments(user: dict = Depends(get_current_user)):
    now = now_utc()
    documents = (
        await expenses.find({
            "user_id": oid(user["id"]),
            "is_income": {"$ne": True},
            "date": {"$gte": now - timedelta(days=730)},
        })
        .sort("date", 1)
        .to_list(length=5000)
    )
    return recurring_payment_detector.analyze(
        documents,
        currency=user.get("currency", "PKR"),
        as_of=now,
    )


@router.post("/feedback/{expense_id}")
async def save_feedback(
    expense_id: str,
    payload: FeedbackIn,
    user: dict = Depends(get_current_user),
):
    uid = oid(user["id"])
    expense = await expenses.find_one({"_id": oid(expense_id), "user_id": uid})
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    predicted = expense.get("category", "Miscellaneous")
    await predictions.insert_one({
        "user_id": uid,
        "expense_id": expense["_id"],
        "predicted_category": predicted,
        "correct_category": payload.correct_category,
        "was_correct": predicted == payload.correct_category,
        "model_mode": expense.get("categorization_source", "unknown"),
        "created_at": now_utc(),
    })
    await expenses.update_one(
        {"_id": expense["_id"]},
        {"$set": {
            "category": payload.correct_category,
            "categorization_source": "user_corrected",
            "updated_at": now_utc(),
        }},
    )
    return {"saved": True, "previous_category": predicted, "category": payload.correct_category}


@router.get("/analytics")
async def categorization_analytics(user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    feedback_count = await predictions.count_documents({"user_id": uid})
    correct_count = await predictions.count_documents({"user_id": uid, "was_correct": True})
    return {
        "model": categorizer.model_info(),
        "intelligence": financial_intelligence.model_info(),
        "feedback_count": feedback_count,
        "feedback_accuracy": round(correct_count / feedback_count, 4) if feedback_count else None,
    }


@router.get("/insights")
async def spending_insights(user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    now = now_utc()
    previous_month = _last_n_months(now, 2)[0]
    expense_docs = await expenses.find({
        "user_id": uid,
        "date": {"$gte": _month_start(*previous_month)},
    }).to_list(length=5000)
    budget_docs = await budgets.find({
        "user_id": uid,
        "month": now.month,
        "year": now.year,
    }).to_list(length=200)

    history, _ = await _forecast_context(uid, now)
    target_year, target_month = _next_month(now)
    forecast, _ = financial_intelligence.predict_spending(
        history,
        target_year=target_year,
        target_month=target_month,
    )

    daily: dict[str, float] = {}
    for document in expense_docs:
        moment = document.get("date")
        if (
            not isinstance(moment, datetime)
            or document.get("is_income") is True
            or moment.year != now.year
            or moment.month != now.month
        ):
            continue
        key = moment.strftime("%Y-%m-%d")
        daily[key] = daily.get(key, 0.0) + float(document.get("amount") or 0)
    daily_totals = [
        {"date": date, "total": round(total, 2)}
        for date, total in sorted(daily.items())
    ]

    personalized = financial_intelligence.generate_insights(
        expense_docs,
        budget_docs,
        forecast,
    )
    anomalies = financial_intelligence.detect_anomalies(daily_totals)
    return {
        "insights": personalized,
        "anomalies": anomalies,
        "models": financial_intelligence.model_info(),
    }
