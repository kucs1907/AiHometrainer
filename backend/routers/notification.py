from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database.connection import SessionLocal, engine
from models.notification_models import Base, NotificationPref, NotificationToken

# 테이블 보장
Base.metadata.create_all(bind=engine)

router = APIRouter(prefix="/notification", tags=["notification"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class PrefsIn(BaseModel):
    user_id: str = Field(..., description="앱의 사용자 식별자")
    enabled: bool
    hour: int = Field(..., ge=0, le=23)
    minute: int = Field(..., ge=0, le=59)
    timezone: str = "Asia/Seoul"

class PrefsOut(BaseModel):
    user_id: str
    enabled: bool
    hour: int
    minute: int
    timezone: str

class TokenIn(BaseModel):
    user_id: str
    token: str
    platform: str = "android"

@router.get("/prefs", response_model=PrefsOut)
def get_prefs(user_id: str, db: Session = Depends(get_db)):
    prefs = db.query(NotificationPref).filter(NotificationPref.user_id == user_id).first()
    if not prefs:
        prefs = NotificationPref(user_id=user_id, enabled=True, hour=20, minute=0, timezone="Asia/Seoul")
        db.add(prefs)
        db.commit()
        db.refresh(prefs)
    return PrefsOut(user_id=prefs.user_id, enabled=prefs.enabled, hour=prefs.hour, minute=prefs.minute, timezone=prefs.timezone)

@router.put("/prefs", response_model=PrefsOut)
def set_prefs(p: PrefsIn, db: Session = Depends(get_db)):
    prefs = db.query(NotificationPref).filter(NotificationPref.user_id == p.user_id).first()
    if not prefs:
        prefs = NotificationPref(user_id=p.user_id, enabled=p.enabled, hour=p.hour, minute=p.minute, timezone=p.timezone)
        db.add(prefs)
    else:
        prefs.enabled = p.enabled
        prefs.hour = p.hour
        prefs.minute = p.minute
        prefs.timezone = p.timezone
    db.commit()
    return PrefsOut(user_id=prefs.user_id, enabled=prefs.enabled, hour=prefs.hour, minute=prefs.minute, timezone=prefs.timezone)

@router.post("/register_token")
def register_token(t: TokenIn, db: Session = Depends(get_db)):
    existing = db.query(NotificationToken).filter(
        NotificationToken.user_id == t.user_id,
        NotificationToken.token == t.token
    ).first()
    if not existing:
        db.add(NotificationToken(user_id=t.user_id, token=t.token, platform=t.platform))
        db.commit()
    return {"ok": True}
