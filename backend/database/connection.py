# backend/database/connection.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

# ⚠️ utils.db.Base 를 단일 베이스로 사용
from utils.db import Base

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def init_db():
    """
    앱 구동 시 테이블 생성.
    - ExerciseSession(신규) + ExerciseType(있다면)만 로드
    - ExerciseLog, PoseLandmark는 더 이상 생성 X
    """
    # 순환참조 방지: 로컬 import
    from models.exercise import ExerciseSession
    try:
        # ExerciseType을 계속 쓴다면 남겨둠 (tables.py가 Base를 utils.db.Base로 쓰도록 2) 패치 필요)
        from models.tables import ExerciseType  # 선택적
    except Exception:
        pass

    Base.metadata.create_all(bind=engine)
