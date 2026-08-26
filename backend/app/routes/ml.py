from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_current_user
from app.database import expenses, predictions
from app.ml.categorizer import categorizer
from app.models import CategorizeIn, CategorizeOut, FeedbackIn
from app.utils import now_utc, oid

router = APIRouter()


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
        "feedback_count": feedback_count,
        "feedback_accuracy": round(correct_count / feedback_count, 4) if feedback_count else None,
    }
