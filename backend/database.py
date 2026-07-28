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

# Lazy Motor Async Client initialization bound to active event loop
_client = None

def get_client():
    global _client
    if _client is None:
        client_kwargs = {"serverSelectionTimeoutMS": 5000}
        try:
            import certifi
            client_kwargs["tlsCAFile"] = certifi.where()
        except Exception:
            pass
        _client = AsyncIOMotorClient(MONGODB_URL, **client_kwargs)
    return _client

def get_db():
    return get_client()[DATABASE_NAME]

class CollectionProxy:
    """Proxy object so collections dynamically bind to the current asyncio event loop."""
    def __init__(self, collection_name: str):
        self._name = collection_name

    @property
    def _coll(self):
        return get_db()[self._name]

    def __getattr__(self, name: str):
        return getattr(self._coll, name)

# Collections (using CollectionProxy for dynamic event loop binding)
users_collection = CollectionProxy("users")
items_collection = CollectionProxy("items")
chats_collection = CollectionProxy("chats")
messages_collection = CollectionProxy("messages")
notifications_collection = CollectionProxy("notifications")
verifications_collection = CollectionProxy("verifications")

async def check_database_connection():
    """Verify database connectivity on startup."""
    try:
        # Ping the server to check connectivity
        await get_client().admin.command('ping')
        logger.info(f"✅ Successfully connected to MongoDB database: '{DATABASE_NAME}'")
        return True
    except Exception as e:
        logger.warning(f"⚠️ Could not connect to MongoDB Atlas at {MONGODB_URL}: {e}")
        logger.warning("⚠️ Running in offline/fallback mode. Ensure your MONGODB_URL is valid in .env")
        return False
