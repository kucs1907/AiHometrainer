from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Integer, Float, DateTime, Text
from utils.db import Base
import datetime as dt

class ExerciseSession(Base):
    __tablename__ = "exercise_sessions"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(64))
    exercise: Mapped[str] = mapped_column(String(32))
    reps: Mapped[int] = mapped_column(Integer, default=0)
    correct_ratio: Mapped[float] = mapped_column(Float, default=0.0)
    start_time: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    end_time: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)

class SessionEvent(Base):
    __tablename__ = "session_events"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(Integer, index=True)
    ts: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    label: Mapped[str] = mapped_column(String(64))
    proba: Mapped[float] = mapped_column(Float)
    raw: Mapped[str] = mapped_column(Text)  # optional: store raw json if needed

# Simple Base alias for init
Base = Base
