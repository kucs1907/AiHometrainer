# backend/models/tables.py

from sqlalchemy import (
    Column, Integer, String, Float, DateTime,
    ForeignKey, func
)
from sqlalchemy.orm import relationship
from utils.db import Base

class User(Base):
    __tablename__ = "users"
    id       = Column(Integer, primary_key=True, index=True)
    kakao_id = Column(String, unique=True, index=True, nullable=False)

    logs = relationship("ExerciseLog", back_populates="user")


class ExerciseType(Base):
    __tablename__ = "exercise_types"
    id   = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

    logs = relationship("ExerciseLog", back_populates="exercise_type")


class ExerciseLog(Base):
    __tablename__ = "exercise_logs"
    id               = Column(Integer, primary_key=True, index=True)
    user_id          = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    exercise_type_id = Column(Integer, ForeignKey("exercise_types.id"), index=True, nullable=False)
    count            = Column(Integer, nullable=False)
    duration         = Column(Float, nullable=False)  # 초 단위
    score            = Column(Float, nullable=False)
    timestamp        = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    user           = relationship("User", back_populates="logs")
    exercise_type = relationship("ExerciseType", back_populates="logs")
    landmarks      = relationship("PoseLandmark", back_populates="log")


class PoseLandmark(Base):
    __tablename__ = "pose_landmarks"
    id          = Column(Integer, primary_key=True, index=True)
    log_id      = Column(Integer, ForeignKey("exercise_logs.id"), nullable=False)
    landmark_id = Column(Integer, nullable=False)
    x           = Column(Float, nullable=False)
    y           = Column(Float, nullable=False)
    z           = Column(Float, nullable=False)

    log = relationship("ExerciseLog", back_populates="landmarks")
