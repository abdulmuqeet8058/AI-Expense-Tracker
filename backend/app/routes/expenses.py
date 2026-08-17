import re
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pymongo import ReturnDocument

from app.auth import get_current_user
from app.database import expenses as expenses_col
from app.models import ExpenseCreate, ExpenseOut, ExpenseUpdate
from app.utils import now_utc, oid, serialize

router = APIRouter()

CATEGORIES = [
    "Food & Dining",
    "Transportation",
    "Shopping",
    "Entertainment",
    "Bills & Utilities",
    "Healthcare",
    "Education",
    "Groceries",
    "Travel",
    "Rent",
    "Insurance",
    "Personal Care",
    "Miscellaneous",
]

SORTABLE = {"date", "amount", "category", "created_at"}


def _month_bounds(year: int, month: int) -> tuple[datetime, datetime]:
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    end = (
        datetime(year + 1, 1, 1, tzinfo=timezone.utc)
        if month == 12
        else datetime(year, month + 1, 1, tzinfo=timezone.utc)
    )
    return start, end


@router.post("/", response_model=ExpenseOut)
async def create_expense(payload: ExpenseCreate, user: dict = Depends(get_current_user)):
    now = now_utc()
    doc = payload.model_dump()
    doc["date"] = doc.get("date") or now
    doc["category"] = doc.get("category") or "Miscellaneous"
    doc["user_id"] = oid(user["id"])
    doc["confidence_score"] = None
    doc["created_at"] = now
    doc["updated_at"] = now

    result = await expenses_col.insert_one(doc)
    doc["_id"] = result.inserted_id
    return ExpenseOut(**serialize(doc))


@router.get("/", response_model=list[ExpenseOut])
async def list_expenses(
    user: dict = Depends(get_current_user),
    category: Optional[str] = None,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    search: Optional[str] = None,
    is_income: Optional[bool] = None,
    limit: int = Query(50, ge=1, le=500),
    skip: int = Query(0, ge=0),
    sort: str = "-date",
):
    query: dict = {"user_id": oid(user["id"])}
    if category:
        query["category"] = category
    if is_income is not None:
        query["is_income"] = is_income
    if search:
        query["description"] = {"$regex": re.escape(search), "$options": "i"}
    if start or end:
        date_range: dict = {}
        if start:
            date_range["$gte"] = start
        if end:
            date_range["$lte"] = end
        query["date"] = date_range

    field = sort.lstrip("+-")
    if field not in SORTABLE:
        field = "date"
    direction = -1 if sort.startswith("-") else 1
    cursor = expenses_col.find(query).sort(field, direction).skip(skip).limit(limit)
    return [ExpenseOut(**serialize(doc)) async for doc in cursor]


@router.get("/categories")
async def list_categories(_: dict = Depends(get_current_user)):
    return CATEGORIES


@router.get("/summary/{category}")
async def category_summary(category: str, user: dict = Depends(get_current_user)):
    uid = oid(user["id"])
    now = now_utc()
    start, end = _month_bounds(now.year, now.month)
    base = {"user_id": uid, "category": category, "is_income": False}

    all_rows = await expenses_col.aggregate([
        {"$match": base},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}, "count": {"$sum": 1}}},
    ]).to_list(1)
    month_rows = await expenses_col.aggregate([
        {"$match": {**base, "date": {"$gte": start, "$lt": end}}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]).to_list(1)
    return {
        "category": category,
        "this_month_total": float(month_rows[0]["total"]) if month_rows else 0.0,
        "all_time_total": float(all_rows[0]["total"]) if all_rows else 0.0,
        "count": int(all_rows[0]["count"]) if all_rows else 0,
    }


@router.get("/{expense_id}", response_model=ExpenseOut)
async def get_expense(expense_id: str, user: dict = Depends(get_current_user)):
    doc = await expenses_col.find_one({"_id": oid(expense_id), "user_id": oid(user["id"])})
    if not doc:
        raise HTTPException(status_code=404, detail="Expense not found")
    return ExpenseOut(**serialize(doc))


@router.put("/{expense_id}", response_model=ExpenseOut)
async def update_expense(
    expense_id: str, payload: ExpenseUpdate, user: dict = Depends(get_current_user)
):
    updates = payload.model_dump(exclude_unset=True)
    updates["updated_at"] = now_utc()
    doc = await expenses_col.find_one_and_update(
        {"_id": oid(expense_id), "user_id": oid(user["id"])},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        raise HTTPException(status_code=404, detail="Expense not found")
    return ExpenseOut(**serialize(doc))


@router.delete("/{expense_id}")
async def delete_expense(expense_id: str, user: dict = Depends(get_current_user)):
    result = await expenses_col.delete_one(
        {"_id": oid(expense_id), "user_id": oid(user["id"])}
    )
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Expense not found")
    return {"deleted": True}
