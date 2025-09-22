# merged3/backend/schemas/auth.py

from pydantic import BaseModel

class KakaoToken(BaseModel):
    access_token: str

class UserOut(BaseModel):
    id: int
    kakao_id: str

    class Config:
        orm_mode = True
