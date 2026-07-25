from pydantic import BaseModel, EmailStr, Field
from typing import Optional
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

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class TokenData(BaseModel):
    user_id: Optional[str] = None
    email: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
