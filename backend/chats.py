from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
from datetime import datetime
from bson import ObjectId

from database import chats_collection, messages_collection, users_collection
from models import ChatCreate, ChatResponse, ChatMessageCreate, ChatMessageResponse
from security import decode_access_token

router = APIRouter(prefix="/api/chats", tags=["Chat & Messaging"])
security = HTTPBearer()

async def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token."
        )
    return payload["sub"]

def helper_chat(doc: dict) -> ChatResponse:
    chat_id = str(doc.get("_id") or doc.get("id"))
    last_time = doc.get("lastMessageTime")
    if not isinstance(last_time, datetime):
        last_time = datetime.utcnow()

    return ChatResponse(
        id=chat_id,
        participants=doc.get("participants", []),
        participantNames=doc.get("participantNames", {}),
        itemId=doc.get("itemId"),
        itemTitle=doc.get("itemTitle"),
        lastMessage=doc.get("lastMessage", ""),
        lastMessageTime=last_time,
        unread=bool(doc.get("unread", False))
    )

def helper_message(doc: dict) -> ChatMessageResponse:
    msg_id = str(doc.get("_id") or doc.get("id"))
    ts = doc.get("timestamp")
    if not isinstance(ts, datetime):
        ts = datetime.utcnow()

    return ChatMessageResponse(
        id=msg_id,
        chatId=str(doc.get("chatId")),
        senderId=str(doc.get("senderId")),
        text=doc.get("text", ""),
        timestamp=ts,
        read=bool(doc.get("read", False))
    )

@router.post("", response_model=ChatResponse, status_code=status.HTTP_201_CREATED)
async def create_or_get_chat(chat_data: ChatCreate, current_user_id: str = Depends(get_current_user_id)):
    """Create a new chat or retrieve existing chat between current user and recipient."""
    other_user_id = chat_data.otherUserId
    
    # Search for existing chat containing both participants
    query = {"participants": {"$all": [current_user_id, other_user_id]}}
    existing = await chats_collection.find_one(query)
    if existing:
        return helper_chat(existing)

    # Fetch current user name
    curr_user = await users_collection.find_one({"_id": ObjectId(current_user_id)}) if ObjectId.is_valid(current_user_id) else None
    if not curr_user:
        curr_user = await users_collection.find_one({"id": current_user_id})
    curr_name = curr_user.get("displayName") or curr_user.get("username", "User") if curr_user else "User"

    now = datetime.utcnow()
    new_chat = {
        "participants": [current_user_id, other_user_id],
        "participantNames": {
            current_user_id: curr_name,
            other_user_id: chat_data.otherUserName
        },
        "itemId": chat_data.itemId,
        "itemTitle": chat_data.itemTitle,
        "lastMessage": "",
        "lastMessageTime": now,
        "unread": False
    }

    res = await chats_collection.insert_one(new_chat)
    new_chat["_id"] = res.inserted_id
    return helper_chat(new_chat)

@router.get("", response_model=List[ChatResponse])
async def get_user_chats(current_user_id: str = Depends(get_current_user_id)):
    """Fetch all active chats for current user."""
    cursor = chats_collection.find({"participants": current_user_id}).sort("lastMessageTime", -1)
    chats = []
    async for doc in cursor:
        chats.append(helper_chat(doc))
    return chats

@router.post("/{chat_id}/messages", response_model=ChatMessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(chat_id: str, msg_data: ChatMessageCreate, current_user_id: str = Depends(get_current_user_id)):
    """Send a message within a chat."""
    now = datetime.utcnow()
    msg_doc = {
        "chatId": chat_id,
        "senderId": current_user_id,
        "text": msg_data.text.strip(),
        "timestamp": now,
        "read": False
    }

    res = await messages_collection.insert_one(msg_doc)
    msg_doc["_id"] = res.inserted_id

    # Update last message on chat
    query = {"_id": ObjectId(chat_id)} if ObjectId.is_valid(chat_id) else {"id": chat_id}
    await chats_collection.update_one(
        query,
        {"$set": {"lastMessage": msg_data.text.strip(), "lastMessageTime": now, "unread": True}}
    )

    return helper_message(msg_doc)

@router.get("/{chat_id}/messages", response_model=List[ChatMessageResponse])
async def get_chat_messages(chat_id: str, current_user_id: str = Depends(get_current_user_id)):
    """Fetch message history for a specific chat."""
    cursor = messages_collection.find({"chatId": chat_id}).sort("timestamp", 1)
    messages = []
    async for doc in cursor:
        messages.append(helper_message(doc))
    return messages
