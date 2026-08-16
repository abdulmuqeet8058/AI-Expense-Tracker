from fastapi import APIRouter, Depends, HTTPException
from pymongo.errors import DuplicateKeyError

from app.auth import (
    create_access_token,
    create_refresh_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.database import users
from app.models import Token, UserCreate, UserLogin, UserOut
from app.utils import now_utc

router = APIRouter()


def _user_out(doc: dict) -> UserOut:
    # works for both a raw mongo doc (_id) and an already-serialized dict (id)
    return UserOut(
        id=str(doc.get("id") or doc.get("_id")),
        email=doc["email"],
        full_name=doc["full_name"],
        currency=doc.get("currency", "PKR"),
        created_at=doc["created_at"],
    )


def _tokens_for(user_out: UserOut) -> Token:
    return Token(
        access_token=create_access_token(user_out.id),
        refresh_token=create_refresh_token(user_out.id),
        user=user_out,
    )


@router.post("/register", response_model=Token)
async def register(payload: UserCreate):
    email = payload.email.lower()
    if await users.find_one({"email": email}):
        raise HTTPException(status_code=400, detail="Email already registered")

    doc = {
        "email": email,
        "password": hash_password(payload.password),
        "full_name": payload.full_name,
        "currency": payload.currency,
        "created_at": now_utc(),
    }
    try:
        res = await users.insert_one(doc)
    except DuplicateKeyError:
        # lost a race against the unique index
        raise HTTPException(status_code=400, detail="Email already registered")

    doc["_id"] = res.inserted_id
    return _tokens_for(_user_out(doc))


@router.post("/login", response_model=Token)
async def login(payload: UserLogin):
    doc = await users.find_one({"email": payload.email.lower()})
    if not doc or not verify_password(payload.password, doc["password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _tokens_for(_user_out(doc))


@router.post("/logout")
async def logout(_: dict = Depends(get_current_user)):
    # JWTs are stateless; the client drops the token. Endpoint exists for symmetry.
    return {"message": "logged out"}


@router.get("/me", response_model=UserOut)
async def me(current: dict = Depends(get_current_user)):
    return _user_out(current)
