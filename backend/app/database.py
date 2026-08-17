from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ASCENDING, DESCENDING

from app.config import settings

client = AsyncIOMotorClient(settings.mongodb_uri)
db = client[settings.db_name]

users = db.users
expenses = db.expenses


async def ensure_indexes() -> None:
    await users.create_index("email", unique=True)
    await expenses.create_index("user_id")
    await expenses.create_index([("user_id", ASCENDING), ("date", DESCENDING)])
