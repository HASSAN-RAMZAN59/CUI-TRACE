from fastapi import APIRouter, HTTPException, status, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
from datetime import datetime
from bson import ObjectId

from database import items_collection, users_collection, verifications_collection
from models import ItemCreate, ItemUpdate, ItemResponse, VerificationAttemptCreate
from security import decode_access_token

router = APIRouter(prefix="/api", tags=["Items & Verification"])
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

def helper_item(item_doc: dict) -> ItemResponse:
    item_id = str(item_doc.get("_id") or item_doc.get("id"))
    
    def parse_dt(field):
        if isinstance(field, datetime):
            return field
        if isinstance(field, str):
            try:
                return datetime.fromisoformat(field)
            except ValueError:
                pass
        return datetime.utcnow()

    return ItemResponse(
        id=item_id,
        title=item_doc.get("title", ""),
        description=item_doc.get("description", ""),
        location=item_doc.get("location", ""),
        category=item_doc.get("category", ""),
        isLost=bool(item_doc.get("isLost", True)),
        date=parse_dt(item_doc.get("date")),
        reportDate=parse_dt(item_doc.get("reportDate")),
        uploader=item_doc.get("uploader", "Anonymous"),
        uploaderId=item_doc.get("uploaderId", ""),
        imageUrl=item_doc.get("imageUrl", ""),
        createdAt=parse_dt(item_doc.get("createdAt")),
        updatedAt=parse_dt(item_doc.get("updatedAt")),
        securityQuestions=item_doc.get("securityQuestions", []),
        requiresVerification=bool(item_doc.get("requiresVerification", False)),
        isClaimed=bool(item_doc.get("isClaimed", False)),
        verifiedClaimerId=item_doc.get("verifiedClaimerId"),
        verificationDate=parse_dt(item_doc.get("verificationDate")) if item_doc.get("verificationDate") else None
    )

@router.post("/items", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
async def create_item(item_data: ItemCreate, user_id: str = Depends(get_current_user_id)):
    """Create a lost or found item."""
    user = await users_collection.find_one({"_id": ObjectId(user_id)}) if ObjectId.is_valid(user_id) else None
    if not user:
        user = await users_collection.find_one({"id": user_id})
    
    uploader_name = user.get("displayName") or user.get("username", "Anonymous") if user else "Anonymous"
    now = datetime.utcnow()

    item_doc = {
        "title": item_data.title.strip(),
        "description": item_data.description.strip(),
        "location": item_data.location.strip(),
        "category": item_data.category.strip(),
        "isLost": item_data.isLost,
        "date": item_data.date or now,
        "reportDate": now,
        "uploader": uploader_name,
        "uploaderId": user_id,
        "imageUrl": item_data.imageUrl or "",
        "createdAt": now,
        "updatedAt": now,
        "securityQuestions": item_data.securityQuestions or [],
        "requiresVerification": item_data.requiresVerification or False,
        "isClaimed": False,
        "verifiedClaimerId": None,
        "verificationDate": None
    }

    result = await items_collection.insert_one(item_doc)
    item_doc["_id"] = result.inserted_id
    return helper_item(item_doc)

@router.get("/items", response_model=List[ItemResponse])
async def get_items(
    isLost: Optional[bool] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = Query(50, ge=1, le=100)
):
    """Retrieve lost/found items with optional filtering."""
    query = {}
    if isLost is not None:
        query["isLost"] = isLost
    if category and category.lower() != "all":
        query["category"] = category
    if search:
        query["$or"] = [
            {"title": {"$regex": search, "$options": "i"}},
            {"description": {"$regex": search, "$options": "i"}},
            {"location": {"$regex": search, "$options": "i"}}
        ]

    cursor = items_collection.find(query).sort("createdAt", -1).limit(limit)
    items = []
    async for doc in cursor:
        items.append(helper_item(doc))
    return items

@router.get("/items/{item_id}", response_model=ItemResponse)
async def get_item_by_id(item_id: str):
    """Fetch single item details."""
    query = {"_id": ObjectId(item_id)} if ObjectId.is_valid(item_id) else {"id": item_id}
    item = await items_collection.find_one(query)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found.")
    return helper_item(item)

@router.get("/users/{user_id}/items", response_model=List[ItemResponse])
async def get_user_items(user_id: str):
    """Fetch items uploaded by a specific user."""
    cursor = items_collection.find({"uploaderId": user_id}).sort("createdAt", -1)
    items = []
    async for doc in cursor:
        items.append(helper_item(doc))
    return items

@router.put("/items/{item_id}", response_model=ItemResponse)
async def update_item(item_id: str, item_data: ItemUpdate, user_id: str = Depends(get_current_user_id)):
    """Update item details (only owner can update)."""
    query = {"_id": ObjectId(item_id)} if ObjectId.is_valid(item_id) else {"id": item_id}
    existing = await items_collection.find_one(query)
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found.")
    
    if existing.get("uploaderId") != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to edit this item.")

    update_fields = {k: v for k, v in item_data.dict(exclude_unset=True).items() if v is not None}
    update_fields["updatedAt"] = datetime.utcnow()

    await items_collection.update_one(query, {"$set": update_fields})
    updated_doc = await items_collection.find_one(query)
    return helper_item(updated_doc)

@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: str, user_id: str = Depends(get_current_user_id)):
    """Delete an item (only owner can delete)."""
    query = {"_id": ObjectId(item_id)} if ObjectId.is_valid(item_id) else {"id": item_id}
    existing = await items_collection.find_one(query)
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found.")
    
    if existing.get("uploaderId") != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this item.")

    await items_collection.delete_one(query)
    return None

# ===================== VERIFICATION ATTEMPTS =====================

@router.post("/items/{item_id}/verify", status_code=status.HTTP_201_CREATED)
async def save_verification_attempt(
    item_id: str,
    attempt: VerificationAttemptCreate,
    user_id: str = Depends(get_current_user_id)
):
    """Save security question verification attempt for an item."""
    doc = {
        "itemId": item_id,
        "userId": user_id,
        "score": attempt.score,
        "status": attempt.status,
        "answers": attempt.answers,
        "createdAt": datetime.utcnow()
    }
    result = await verifications_collection.insert_one(doc)
    return {"message": "Verification attempt saved.", "id": str(result.inserted_id)}

@router.get("/items/{item_id}/verify/check/{user_id}")
async def check_user_can_verify(item_id: str, user_id: str):
    """Check if user has already attempted verification."""
    existing = await verifications_collection.find_one({"itemId": item_id, "userId": user_id})
    return {"canAttempt": existing is None}
