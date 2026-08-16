from datetime import datetime, timezone

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import HTTPException


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def oid(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail="Invalid id")


def serialize(doc: dict | None) -> dict | None:
    """Mongo doc -> plain dict: _id becomes a string 'id', any ObjectId field
    (e.g. user_id) is stringified. Datetimes are left untouched."""
    if doc is None:
        return None
    out = dict(doc)
    _id = out.pop("_id", None)
    if _id is not None:
        out["id"] = str(_id)
    for key, value in out.items():
        if isinstance(value, ObjectId):
            out[key] = str(value)
    return out
