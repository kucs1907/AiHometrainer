# merged3/backend/routers/auth.py

import requests
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database.connection import SessionLocal
from models.tables import User
from schemas.auth import KakaoToken, UserOut

router = APIRouter(tags=["auth"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/kakao", response_model=UserOut)
def kakao_login(data: KakaoToken, db: Session = Depends(get_db)):
    # 1) 카카오 토큰 검증 & 프로필 조회
    headers = {"Authorization": f"Bearer {data.access_token}"}
    resp = requests.get("https://kapi.kakao.com/v2/user/me", headers=headers)
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid Kakao token")

    info = resp.json()
    kakao_id = str(info.get("id"))

    # 2) DB에서 조회 후 없으면 생성
    user = db.query(User).filter(User.kakao_id == kakao_id).first()
    if not user:
        user = User(kakao_id=kakao_id)
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"[Auth] 신규 유저 생성: id={user.id}, kakao_id={user.kakao_id}")
    else:
        print(f"[Auth] 기존 유저 로그인: id={user.id}, kakao_id={user.kakao_id}")

    return user
