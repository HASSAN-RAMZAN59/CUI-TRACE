from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
from datetime import datetime
from bson import ObjectId

from database import notifications_collection
from models import NotificationCreate, NotificationResponse
from security import decode_access_token

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])
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

def helper_notification(doc: dict) -> NotificationResponse:
    notif_id = str(doc.get("_id") or doc.get("id"))
    created_at = doc.get("createdAt")
    if not isinstance(created_at, datetime):
        created_at = datetime.utcnow()

    return NotificationResponse(
        id=notif_id,
        recipientId=doc.get("recipientId", "all"),
        title=doc.get("title", ""),
        body=doc.get("body", ""),
        type=doc.get("type", "system"),
        data=doc.get("data", {}),
        read=bool(doc.get("read", False)),
        createdAt=created_at
    )

@router.get("", response_model=List[NotificationResponse])
async def get_user_notifications(user_id: str = Depends(get_current_user_id)):
    """Fetch notifications for current user."""
    query = {"$or": [{"recipientId": user_id}, {"recipientId": "all"}]}
    cursor = notifications_collection.find(query).sort("createdAt", -1)
    notifs = []
    async for doc in cursor:
        notifs.append(helper_notification(doc))
    return notifs

@router.post("", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
async def create_notification(notif_data: NotificationCreate):
    """Create a system or user notification."""
    now = datetime.utcnow()
    doc = {
        "recipientId": notif_data.recipientId,
        "title": notif_data.title.strip(),
        "body": notif_data.body.strip(),
        "type": notif_data.type,
        "data": notif_data.data or {},
        "read": False,
        "createdAt": now
    }
    res = await notifications_collection.insert_one(doc)
    doc["_id"] = res.inserted_id
    return helper_notification(doc)

@router.put("/{notification_id}/read", status_code=status.HTTP_200_OK)
async def mark_notification_read(notification_id: str, user_id: str = Depends(get_current_user_id)):
    """Mark a notification as read."""
    query = {"_id": ObjectId(notification_id)} if ObjectId.is_valid(notification_id) else {"id": notification_id}
    await notifications_collection.update_one(query, {"$set": {"read": True}})
    return {"message": "Notification marked as read."}

@router.put("/read-all", status_code=status.HTTP_200_OK)
async def mark_all_notifications_read(user_id: str = Depends(get_current_user_id)):
    """Mark all notifications for user as read."""
    query = {"$or": [{"recipientId": user_id}, {"recipientId": "all"}]}
    await notifications_collection.update_many(query, {"$set": {"read": True}})
    return {"message": "All notifications marked as read."}

@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_notification(notification_id: str, user_id: str = Depends(get_current_user_id)):
    """Delete a single notification."""
    query = {"_id": ObjectId(notification_id)} if ObjectId.is_valid(notification_id) else {"id": notification_id}
    await notifications_collection.delete_one(query)
    return None

@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
async def delete_all_notifications(user_id: str = Depends(get_current_user_id)):
    """Delete all notifications for user."""
    query = {"$or": [{"recipientId": user_id}, {"recipientId": "all"}]}
    await notifications_collection.delete_many(query)
    return None
