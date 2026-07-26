from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from datetime import datetime
from bson import ObjectId

from database import users_collection
from models import UserSignup, UserLogin, UserResponse, TokenResponse, UserProfileUpdate
from security import verify_password, get_password_hash, create_access_token, decode_access_token

router = APIRouter(prefix="/api", tags=["Authentication"])
security = HTTPBearer()

def helper_user(user_doc: dict) -> UserResponse:
    """Format MongoDB user doc into UserResponse Pydantic model."""
    user_id = str(user_doc.get("_id") or user_doc.get("id"))
    created_at = user_doc.get("createdAt")
    if isinstance(created_at, str):
        try:
            created_at = datetime.fromisoformat(created_at)
        except ValueError:
            created_at = datetime.utcnow()
    elif not isinstance(created_at, datetime):
        created_at = datetime.utcnow()

    return UserResponse(
        id=user_id,
        email=user_doc.get("email", ""),
        username=user_doc.get("username", ""),
        displayName=user_doc.get("displayName", ""),
        createdAt=created_at
    )

@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(user_data: UserSignup):
    """Registers a new user, hashes password, saves to MongoDB, and returns JWT token."""
    email_clean = user_data.email.strip().lower()
    username_clean = user_data.username.strip().lower()

    # Check if email already exists
    existing_email = await users_collection.find_one({"email": email_clean})
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists."
        )

    # Check if username already exists
    existing_username = await users_collection.find_one({"username": username_clean})
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This username is already taken. Please choose another."
        )

    # Hash password and create user doc
    hashed_pwd = get_password_hash(user_data.password)
    now = datetime.utcnow()

    user_document = {
        "email": email_clean,
        "username": username_clean,
        "displayName": user_data.displayName.strip(),
        "password": hashed_pwd,
        "createdAt": now,
        "updatedAt": now
    }

    result = await users_collection.insert_one(user_document)
    user_document["_id"] = result.inserted_id

    # Format user response and generate JWT
    user_response = helper_user(user_document)
    token = create_access_token(data={"sub": user_response.id, "email": user_response.email})

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=user_response
    )

@router.post("/login", response_model=TokenResponse)
async def login(credentials: UserLogin):
    """Verifies user credentials and returns a secure JWT access token."""
    email_clean = credentials.email.strip().lower()

    user = await users_collection.find_one({"email": email_clean})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )

    if not verify_password(credentials.password, user.get("password", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )

    user_response = helper_user(user)
    token = create_access_token(data={"sub": user_response.id, "email": user_response.email})

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=user_response
    )

@router.get("/me", response_model=UserResponse)
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Fetch current logged-in user profile from JWT token."""
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token or token expired."
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload."
        )

    try:
        user = await users_collection.find_one({"_id": ObjectId(user_id)})
    except Exception:
        user = await users_collection.find_one({"id": user_id})

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )

    return helper_user(user)

@router.put("/users/profile", response_model=UserResponse)
async def update_user_profile(
    profile_data: UserProfileUpdate,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Update profile information (displayName, username) for logged-in user."""
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token."
        )
    
    user_id = payload["sub"]
    query = {"_id": ObjectId(user_id)} if ObjectId.is_valid(user_id) else {"id": user_id}

    update_fields = {}
    if profile_data.displayName:
        update_fields["displayName"] = profile_data.displayName.strip()
    if profile_data.username:
        update_fields["username"] = profile_data.username.strip().lower()

    if update_fields:
        await users_collection.update_one(query, {"$set": update_fields})

    updated_user = await users_collection.find_one(query)
    if not updated_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    return helper_user(updated_user)
