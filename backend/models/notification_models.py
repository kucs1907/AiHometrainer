from sqlalchemy.orm import declarative_base
from sqlalchemy import Column, Integer, String, Boolean, DateTime, func, UniqueConstraint

Base = declarative_base()

class NotificationPref(Base):
    __tablename__ = "notification_prefs"
    user_id = Column(String, primary_key=True)
    enabled = Column(Boolean, default=True, nullable=False)
    hour = Column(Integer, default=20, nullable=False)     # 0-23
    minute = Column(Integer, default=0, nullable=False)    # 0-59
    timezone = Column(String, default="Asia/Seoul", nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

class NotificationToken(Base):
    __tablename__ = "notification_tokens"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, index=True, nullable=False)
    token = Column(String, nullable=False)
    platform = Column(String, default="android", nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    __table_args__ = (UniqueConstraint('user_id', 'token', name='uq_user_token'),)
