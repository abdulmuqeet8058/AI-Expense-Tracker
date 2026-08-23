import io
import csv
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from app.auth import get_current_user
from app.database import expenses as expenses_col, budgets
from app.utils import serialize, oid

router = APIRouter()


def _month_start(dt, months_back=0):
    y, m = dt.year, dt.month
    m -= months_back
    while m <= 0:
        m += 12
        y -= 1
    return datetime(y, m, 1, tzinfo=timezone.utc)


def _last_n_months(dt, n):
    out = []
    y, m = dt.year, dt.month
    for _ in range(n):
        out.append((y, m))
        m -= 1
        if m == 0:
            m, y = 12, y - 1
    return list(reversed(out))


def _month_label(y, m):
    return f"{y:04d}-{m:02d}"


async def _category_spend(uid, category, since):
    res = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "category": category,
                    "date": {"$gte": since}, "is_income": {"$ne": True}}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]).to_list(length=1)
    return res[0]["total"] if res else 0.0


@router.get("/dashboard")
async def dashboard(user=Depends(get_current_user)):
    uid = oid(user["id"])
    now = datetime.now(timezone.utc)
    m_start = _month_start(now)

    # spent vs income this month in one pass
    totals = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": m_start}}},
        {"$group": {"_id": "$is_income", "total": {"$sum": "$amount"}}},
    ]).to_list(length=None)
    total_spent = total_income = 0.0
    for t in totals:
        if t["_id"]:
            total_income = t["total"]
        else:
            total_spent = t["total"]

    top_rows = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": m_start}, "is_income": {"$ne": True}}},
        {"$group": {"_id": "$category", "total": {"$sum": "$amount"}}},
        {"$sort": {"total": -1}},
        {"$limit": 5},
    ]).to_list(length=None)
    top_categories = [
        {"category": r["_id"] or "Miscellaneous", "total": round(r["total"], 2)}
        for r in top_rows
    ]

    bud_docs = await budgets.find(
        {"user_id": uid, "month": now.month, "year": now.year}
    ).to_list(length=200)
    budget_progress = []
    for b in bud_docs:
        limit = float(b.get("monthly_limit") or 0)
        spent = await _category_spend(uid, b.get("category"), m_start)
        budget_progress.append({
            "id": str(b["_id"]),
            "category": b.get("category"),
            "monthly_limit": limit,
            "current_spent": round(spent, 2),
            "percent": round((spent / limit * 100) if limit else 0.0, 1),
            "alert_threshold": b.get("alert_threshold", 80),
        })

    recent_docs = await expenses_col.find({"user_id": uid}).sort("date", -1).limit(5).to_list(length=5)
    recent = [serialize(d) for d in recent_docs]

    return {
        "total_spent_month": round(total_spent, 2),
        "total_income_month": round(total_income, 2),
        "budget_progress": budget_progress,
        "recent": recent,
        "top_categories": top_categories,
        "headline_insight": None,
        "currency": user.get("currency", "PKR"),
    }


@router.get("/charts")
async def charts(user=Depends(get_current_user)):
    uid = oid(user["id"])
    now = datetime.now(timezone.utc)
    m_start = _month_start(now)
    months = _last_n_months(now, 6)
    six_start = datetime(months[0][0], months[0][1], 1, tzinfo=timezone.utc)

    cat_rows = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": m_start}, "is_income": {"$ne": True}}},
        {"$group": {"_id": "$category", "total": {"$sum": "$amount"}}},
        {"$sort": {"total": -1}},
    ]).to_list(length=None)
    by_category = [
        {"category": r["_id"] or "Miscellaneous", "total": round(r["total"], 2)}
        for r in cat_rows
    ]

    daily_rows = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": m_start}, "is_income": {"$ne": True}}},
        {"$group": {
            "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$date"}},
            "total": {"$sum": "$amount"},
        }},
        {"$sort": {"_id": 1}},
    ]).to_list(length=None)
    daily = [{"date": r["_id"], "total": round(r["total"], 2)} for r in daily_rows]

    monthly_rows = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": six_start}, "is_income": {"$ne": True}}},
        {"$group": {
            "_id": {"y": {"$year": "$date"}, "m": {"$month": "$date"}},
            "total": {"$sum": "$amount"},
        }},
    ]).to_list(length=None)
    monthly_map = {(r["_id"]["y"], r["_id"]["m"]): round(r["total"], 2) for r in monthly_rows}
    monthly = [{"month": _month_label(y, m), "total": monthly_map.get((y, m), 0.0)} for y, m in months]

    return {"by_category": by_category, "daily": daily, "monthly": monthly}


@router.get("/reports")
async def reports(user=Depends(get_current_user)):
    uid = oid(user["id"])
    now = datetime.now(timezone.utc)
    m_start = _month_start(now)
    prev_start = _month_start(now, 1)

    totals = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": m_start}}},
        {"$group": {"_id": "$is_income", "total": {"$sum": "$amount"}, "count": {"$sum": 1}}},
    ]).to_list(length=None)
    spent = income = 0.0
    spend_count = 0
    for t in totals:
        if t["_id"]:
            income = t["total"]
        else:
            spent = t["total"]
            spend_count = t["count"]

    cat_rows = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": m_start}, "is_income": {"$ne": True}}},
        {"$group": {"_id": "$category", "total": {"$sum": "$amount"}}},
        {"$sort": {"total": -1}},
    ]).to_list(length=None)
    by_category = [
        {"category": r["_id"] or "Miscellaneous", "total": round(r["total"], 2)}
        for r in cat_rows
    ]

    prev = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "date": {"$gte": prev_start, "$lt": m_start},
                    "is_income": {"$ne": True}}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]).to_list(length=1)
    prev_spent = prev[0]["total"] if prev else 0.0

    change_pct = ((spent - prev_spent) / prev_spent * 100) if prev_spent else None
    net = income - spent
    savings_rate = (net / income * 100) if income else None

    return {
        "month": _month_label(now.year, now.month),
        "total_spent": round(spent, 2),
        "total_income": round(income, 2),
        "net": round(net, 2),
        "savings_rate": round(savings_rate, 1) if savings_rate is not None else None,
        "transaction_count": spend_count,
        "avg_transaction": round(spent / spend_count, 2) if spend_count else 0.0,
        "top_category": by_category[0] if by_category else None,
        "by_category": by_category,
        "vs_last_month": {
            "last_month_spent": round(prev_spent, 2),
            "change_pct": round(change_pct, 1) if change_pct is not None else None,
            "direction": ("up" if change_pct and change_pct > 0 else "down") if change_pct is not None else None,
        },
        "currency": user.get("currency", "PKR"),
    }


@router.get("/trends/{category}")
async def trends(category: str, user=Depends(get_current_user)):
    uid = oid(user["id"])
    now = datetime.now(timezone.utc)
    months = _last_n_months(now, 6)
    start = datetime(months[0][0], months[0][1], 1, tzinfo=timezone.utc)

    rows = await expenses_col.aggregate([
        {"$match": {"user_id": uid, "category": category,
                    "date": {"$gte": start}, "is_income": {"$ne": True}}},
        {"$group": {
            "_id": {"y": {"$year": "$date"}, "m": {"$month": "$date"}},
            "total": {"$sum": "$amount"},
        }},
    ]).to_list(length=None)
    month_map = {(r["_id"]["y"], r["_id"]["m"]): round(r["total"], 2) for r in rows}
    series = [{"month": _month_label(y, m), "total": month_map.get((y, m), 0.0)} for y, m in months]

    return {
        "category": category,
        "months": series,
    }


@router.get("/export/{format}")
async def export(format: str, user=Depends(get_current_user)):
    fmt = format.lower()
    if fmt not in ("csv", "json"):
        raise HTTPException(status_code=400, detail="format must be 'csv' or 'json'")

    uid = oid(user["id"])
    docs = await expenses_col.find({"user_id": uid}).sort("date", -1).to_list(length=None)
    rows = [serialize(d) for d in docs]

    if fmt == "csv":
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["id", "date", "amount", "category", "sub_category",
                         "description", "payment_method", "is_income"])
        for r in rows:
            writer.writerow([
                r.get("id"), _iso(r.get("date")), r.get("amount"), r.get("category"),
                r.get("sub_category"), r.get("description"),
                r.get("payment_method"), r.get("is_income"),
            ])
        buf.seek(0)
        return StreamingResponse(
            iter([buf.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=expenses.csv"},
        )

    payload = json.dumps(rows, default=_json_default)
    return StreamingResponse(
        iter([payload]),
        media_type="application/json",
        headers={"Content-Disposition": "attachment; filename=expenses.json"},
    )


def _iso(value):
    if isinstance(value, datetime):
        return value.isoformat()
    return "" if value is None else str(value)


def _json_default(o):
    if isinstance(o, datetime):
        return o.isoformat()
    return str(o)
