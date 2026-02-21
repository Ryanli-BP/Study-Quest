from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_db, AsyncSessionLocal
from app.routers import auth, upload, quiz, tokens, gacha
from app.services.gacha import seed_characters


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    async with AsyncSessionLocal() as db:
        await seed_characters(db)
        await db.commit()
    yield
    # Shutdown (nothing to clean up for SQLite)


app = FastAPI(
    title="AI Learning Companion API",
    description="Backend for the HackLondon 2026 AI Learning Companion app",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten this in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(upload.router)
app.include_router(quiz.router)
app.include_router(tokens.router)
app.include_router(gacha.router)


@app.get("/", tags=["health"])
async def root():
    return {"status": "ok", "message": "AI Learning Companion API is running"}


@app.get("/health", tags=["health"])
async def health():
    return {"status": "healthy"}
