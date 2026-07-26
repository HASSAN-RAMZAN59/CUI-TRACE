import os
import logging
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

# Load environment variables relative to this file location
env_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=env_path)

MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "cui_trace_db")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Motor Async Client
client = AsyncIOMotorClient(MONGODB_URL, serverSelectionTimeoutMS=5000)
db = client[DATABASE_NAME]

# Collections
users_collection = db["users"]
items_collection = db["items"]
chats_collection = db["chats"]
messages_collection = db["messages"]
notifications_collection = db["notifications"]
verifications_collection = db["verifications"]

async def check_database_connection():
    """Verify database connectivity on startup."""
    try:
        # Ping the server to check connectivity
        await client.admin.command('ping')
        logger.info(f"✅ Successfully connected to MongoDB database: '{DATABASE_NAME}'")
        return True
    except Exception as e:
        logger.warning(f"⚠️ Could not connect to MongoDB Atlas at {MONGODB_URL}: {e}")
        logger.warning("⚠️ Running in offline/fallback mode. Ensure your MONGODB_URL is valid in .env")
        return False
