from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

# ===================== USER AUTH SCHEMAS =====================

class UserSignup(BaseModel):
    email: EmailStr = Field(..., example="user@example.com")
    username: str = Field(..., min_length=3, max_length=30, example="john_doe")
    displayName: str = Field(..., min_length=2, max_length=50, example="John Doe")
    password: str = Field(..., min_length=6, example="password123")

class UserLogin(BaseModel):
    email: EmailStr = Field(..., example="user@example.com")
    password: str = Field(..., example="password123")

class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    displayName: str
    createdAt: datetime

class TokenData(BaseModel):
    user_id: Optional[str] = None
    email: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

class UserProfileUpdate(BaseModel):
    displayName: Optional[str] = None
    username: Optional[str] = None

# ===================== ITEM SCHEMAS =====================

class SecurityQuestionSchema(BaseModel):
    question: str
    answer: Optional[str] = None
    options: Optional[List[str]] = []

class ItemCreate(BaseModel):
    title: str
    description: str
    location: str
    category: str
    isLost: bool
    date: Optional[datetime] = None
    imageUrl: Optional[str] = ""
    securityQuestions: Optional[List[Dict[str, Any]]] = []
    requiresVerification: Optional[bool] = False

class ItemUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None
    category: Optional[str] = None
    isLost: Optional[bool] = None
    imageUrl: Optional[str] = None
    securityQuestions: Optional[List[Dict[str, Any]]] = None
    requiresVerification: Optional[bool] = None
    isClaimed: Optional[bool] = None
    verifiedClaimerId: Optional[str] = None

class ItemResponse(BaseModel):
    id: str
    title: str
    description: str
    location: str
    category: str
    isLost: bool
    date: datetime
    reportDate: datetime
    uploader: str
    uploaderId: str
    imageUrl: str
    createdAt: datetime
    updatedAt: datetime
    securityQuestions: List[Dict[str, Any]] = []
    requiresVerification: bool = False
    isClaimed: bool = False
    verifiedClaimerId: Optional[str] = None
    verificationDate: Optional[datetime] = None

class VerificationAttemptCreate(BaseModel):
    itemId: str
    score: float
    status: str
    answers: Dict[str, Any]

# ===================== NOTIFICATION SCHEMAS =====================

class NotificationCreate(BaseModel):
    recipientId: str
    title: str
    body: str
    type: str
    data: Optional[Dict[str, Any]] = {}

class NotificationResponse(BaseModel):
    id: str
    recipientId: str
    title: str
    body: str
    type: str
    data: Dict[str, Any]
    read: bool
    createdAt: datetime

# ===================== CHAT SCHEMAS =====================

class ChatCreate(BaseModel):
    otherUserId: str
    otherUserName: str
    itemId: Optional[str] = None
    itemTitle: Optional[str] = None

class ChatMessageCreate(BaseModel):
    chatId: str
    text: str

class ChatMessageResponse(BaseModel):
    id: str
    chatId: str
    senderId: str
    text: str
    timestamp: datetime
    read: bool

class ChatResponse(BaseModel):
    id: str
    participants: List[str]
    participantNames: Dict[str, str]
    itemId: Optional[str] = None
    itemTitle: Optional[str] = None
    lastMessage: str = ""
    lastMessageTime: datetime
    unread: bool = False
