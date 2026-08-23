from datetime import datetime, timezone
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from pymongo import ReturnDocument

from app.auth import get_current_user
from app.database import budgets
from app.database import expenses as expenses_col
from app.models import BudgetCreate, BudgetOut, BudgetUpdate
from app.utils import now_utc, oid, serialize

router = APIRouter()


def _month_bounds(year: int, month: int) -> tuple[datetime, datetime]:
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    end = (
        datetime(year + 1, 1, 1, tzinfo=timezone.utc)
        if month == 12
        else datetime(year, month + 1, 1, tzinfo=timezone.utc)
    )
    return start, end


async def _spent_for(uid: ObjectId, category: str, month: int, year: int) -> float:
    start, end = _month_bounds(year, month)
    rows = await expenses_col.aggregate(
        [
            {
                "$match": {
                    "user_id": uid,
                    "category": category,
                    "is_income": False,
                    "date": {"$gte": start, "$lt": end},
                }
            },
            {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
        ]
    ).to_list(1)
    return float(rows[0]["total"]) if rows else 0.0


async def _budget_out(uid: ObjectId, doc: dict) -> BudgetOut:
    data = serialize(doc)
    data["current_spent"] = await _spent_for(uid, doc["category"], doc["month"], doc["year"])
    return BudgetOut(**data)


@router.post("/", response_model=BudgetOut)
async def create_budget(payload: BudgetCreate, user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    now = now_utc()
    key = {
        "user_id": uid,
        "category": payload.category,
        "month": payload.month,
        "year": payload.year,
    }

    # Re-setting a budget for the same category/month just updates it instead of
    # piling up duplicates.
    existing = await budgets.find_one(key)
    if existing:
        doc = await budgets.find_one_and_update(
            {"_id": existing["_id"]},
            {
                "$set": {
                    "monthly_limit": payload.monthly_limit,
                    "alert_threshold": payload.alert_threshold,
                    "updated_at": now,
                }
            },
            return_document=ReturnDocument.AFTER,
        )
    else:
        doc = payload.model_dump()
        doc.update({"user_id": uid, "created_at": now, "updated_at": now})
        res = await budgets.insert_one(doc)
        doc["_id"] = res.inserted_id

    return await _budget_out(uid, doc)


@router.get("/", response_model=list[BudgetOut])
async def list_budgets(
    user: dict = Depends(get_current_user),
    month: Optional[int] = None,
    year: Optional[int] = None,
):
    uid = oid(user["id"])
    q: dict = {"user_id": uid}
    if month:
        q["month"] = month
    if year:
        q["year"] = year

    out = []
    async for d in budgets.find(q).sort([("year", -1), ("month", -1)]):
        out.append(await _budget_out(uid, d))
    return out


@router.get("/alerts", response_model=list[BudgetOut])
async def budget_alerts(user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    now = now_utc()
    firing = []
    async for d in budgets.find({"user_id": uid, "month": now.month, "year": now.year}):
        bo = await _budget_out(uid, d)
        if bo.monthly_limit > 0 and (bo.current_spent / bo.monthly_limit) * 100 >= bo.alert_threshold:
            firing.append(bo)
    return firing


@router.get("/{budget_id}", response_model=BudgetOut)
async def get_budget(budget_id: str, user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    doc = await budgets.find_one({"_id": oid(budget_id), "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="Budget not found")
    return await _budget_out(uid, doc)


@router.put("/{budget_id}", response_model=BudgetOut)
async def update_budget(
    budget_id: str, payload: BudgetUpdate, user: dict = Depends(get_current_user)
):
    uid = oid(user["id"])
    updates = payload.model_dump(exclude_unset=True)
    updates["updated_at"] = now_utc()

    doc = await budgets.find_one_and_update(
        {"_id": oid(budget_id), "user_id": uid},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        raise HTTPException(status_code=404, detail="Budget not found")
    return await _budget_out(uid, doc)


@router.delete("/{budget_id}")
async def delete_budget(budget_id: str, user: dict = Depends(get_current_user)):
    res = await budgets.delete_one({"_id": oid(budget_id), "user_id": oid(user["id"])})
    if res.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Budget not found")
    return {"deleted": True}
