from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    full_name: str
    currency: str = "PKR"


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    currency: str
    created_at: datetime


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class Location(BaseModel):
    lat: float
    lng: float
    address: Optional[str] = None


class ExpenseCreate(BaseModel):
    amount: float = Field(gt=0)
    description: str = Field(min_length=1)
    category: Optional[str] = None
    sub_category: Optional[str] = None
    date: Optional[datetime] = None
    payment_method: str = "cash"
    location: Optional[Location] = None
    receipt_url: Optional[str] = None
    is_income: bool = False


class ExpenseUpdate(BaseModel):
    amount: Optional[float] = Field(default=None, gt=0)
    description: Optional[str] = Field(default=None, min_length=1)
    category: Optional[str] = None
    sub_category: Optional[str] = None
    date: Optional[datetime] = None
    payment_method: Optional[str] = None
    location: Optional[Location] = None
    receipt_url: Optional[str] = None
    is_income: Optional[bool] = None


class ExpenseOut(BaseModel):
    id: str
    user_id: str
    amount: float
    description: str
    category: str
    sub_category: Optional[str] = None
    date: datetime
    payment_method: str = "cash"
    location: Optional[Location] = None
    receipt_url: Optional[str] = None
    is_income: bool = False
    confidence_score: Optional[float] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
