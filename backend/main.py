from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from database import check_database_connection
from auth import router as auth_router
from items import router as items_router
from notifications import router as notifications_router
from chats import router as chats_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Check MongoDB connection
    logger.info("🚀 Initializing FastAPI Backend Server...")
    await check_database_connection()
    yield
    # Shutdown logic
    logger.info("👋 Shutting down FastAPI Backend Server...")

app = FastAPI(
    title="CUI Trace Backend API",
    description="FastAPI & MongoDB Atlas Backend for Lost & Found App",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS Middleware for Flutter App integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth_router)
app.include_router(items_router)
app.include_router(notifications_router)
app.include_router(chats_router)

@app.get("/")
async def root():
    return {
        "status": "FastAPI backend is running successfully with MongoDB Atlas",
        "docs": "/docs",
        "endpoints": {
            "auth": "/api/signup, /api/login, /api/me, /api/users/profile",
            "items": "/api/items",
            "notifications": "/api/notifications",
            "chats": "/api/chats"
        }
    }
