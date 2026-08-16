import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.database import ensure_indexes
from app.routes import auth


@asynccontextmanager
async def lifespan(_: FastAPI):
    await ensure_indexes()
    yield


app = FastAPI(title="Smart Expense Tracker API", version="1.0.0", lifespan=lifespan)

if settings.cors_origins.strip() == "*":
    origins = ["*"]
else:
    origins = [origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

RATE_LIMIT = 100
WINDOW_SECONDS = 60.0
_hits: dict[str, deque] = defaultdict(deque)


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    ip = request.client.host if request.client else "unknown"
    now = time.monotonic()
    requests = _hits[ip]
    while requests and now - requests[0] > WINDOW_SECONDS:
        requests.popleft()
    if len(requests) >= RATE_LIMIT:
        return JSONResponse(status_code=429, content={"detail": "Too many requests, slow down."})
    requests.append(now)
    return await call_next(request)


@app.get("/api/health")
async def health():
    return {"status": "ok", "phase": 1}


app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
