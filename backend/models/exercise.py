# backend/models/exercise.py
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Integer, Float, DateTime, Text, event
from utils.db import Base
import datetime as dt

# --- 고정 규칙: 저장 시점 = UTC now + 9시간(KST), tz 없는 naive로 저장 -------------
def now_kst_naive() -> dt.datetime:
    # datetime.utcnow()는 tzinfo=None (naive, UTC 기준)
    return dt.datetime.utcnow() + dt.timedelta(hours=9)
# -----------------------------------------------------------------------------

class ExerciseSession(Base):
    __tablename__ = "exercise_sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    exercise: Mapped[str] = mapped_column(String(32), nullable=False)
    reps: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    correct_ratio: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)

    # DB 컬럼 타입이 timestamp without time zone 이므로 timezone=False
    # 값은 이벤트 훅에서 무조건 now_kst_naive()로 채움
    start_time: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False),
        nullable=False,
    )
    # 완료 시점에만 채울 것이므로 NULL 허용
    end_time: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )

class SessionEvent(Base):
    __tablename__ = "session_events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)

    ts: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False),
        nullable=False,
    )

    label: Mapped[str] = mapped_column(String(64), nullable=False)
    proba: Mapped[float] = mapped_column(Float, nullable=False)
    raw: Mapped[str] = mapped_column(Text)

# -------------------- 이벤트 훅: 무조건 +9h 강제 --------------------
@event.listens_for(ExerciseSession, "before_insert")
def _es_before_insert(mapper, connection, target):
    # 시작 시간은 어떤 값이 오든 "지금 KST"로 저장
    target.start_time = now_kst_naive()
    # 만약 insert 시 end_time까지 넣는 경로가 있다면 그것도 강제로 지금 KST
    if target.end_time is not None:
        target.end_time = now_kst_naive()

@event.listens_for(ExerciseSession, "before_update")
def _es_before_update(mapper, connection, target):
    # end_time을 세팅하려는 업데이트면 무조건 "지금 KST"로 저장
    if target.end_time is not None:
        target.end_time = now_kst_naive()

@event.listens_for(SessionEvent, "before_insert")
def _se_before_insert(mapper, connection, target):
    # 이벤트 타임스탬프도 무조건 "지금 KST"로 저장
    target.ts = now_kst_naive()

# Simple Base alias for init
Base = Base
