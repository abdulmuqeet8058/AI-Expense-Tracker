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
    categorization_source: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None


class BudgetCreate(BaseModel):
    category: str
    monthly_limit: float = Field(gt=0)
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2000, le=2100)
    alert_threshold: float = Field(default=80, ge=0, le=100)


class BudgetUpdate(BaseModel):
    category: Optional[str] = None
    monthly_limit: Optional[float] = Field(default=None, gt=0)
    month: Optional[int] = Field(default=None, ge=1, le=12)
    year: Optional[int] = Field(default=None, ge=2000, le=2100)
    alert_threshold: Optional[float] = Field(default=None, ge=0, le=100)


class BudgetOut(BaseModel):
    id: str
    user_id: str
    category: str
    monthly_limit: float
    month: int
    year: int
    alert_threshold: float = 80
    current_spent: float = 0
    created_at: datetime
    updated_at: Optional[datetime] = None


class CategorizeIn(BaseModel):
    description: str = Field(min_length=1)
    amount: Optional[float] = Field(default=None, gt=0)
    payment_method: Optional[str] = None
    date: Optional[datetime] = None


class CategoryAlternative(BaseModel):
    category: str
    confidence: float


class CategorizeOut(BaseModel):
    category: str
    confidence: float
    alternatives: list[CategoryAlternative] = Field(default_factory=list)
    model_mode: str


class FeedbackIn(BaseModel):
    correct_category: str = Field(min_length=1)
