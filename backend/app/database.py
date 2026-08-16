from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ASCENDING

from app.config import settings

client = AsyncIOMotorClient(settings.mongodb_uri)
db = client[settings.db_name]

users = db.users


async def ensure_indexes() -> None:
    await users.create_index("email", unique=True)
