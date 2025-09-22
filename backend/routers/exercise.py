from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Dict
from database.connection import SessionLocal, Base, engine
from models.tables import ExerciseLog, ExerciseType
from schemas.exercise import (
    ExerciseLogIn, ExerciseLogOut,
    ExerciseTypeOut
)
from utils.statistics import compute_stats

# 테이블 생성 (없으면)
Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

router = APIRouter(prefix="/exercise", tags=["exercise"])

@router.post(
    "/log",
    response_model=ExerciseLogOut,
    summary="운동 기록 저장",
    description="사용자의 score, count, duration을 DB에 저장"
)
def create_exercise_log(
    payload: ExerciseLogIn,
    db: Session = Depends(get_db)
):
    # 운동 종류 확인
    if not db.query(ExerciseType).filter_by(id=payload.exercise_type_id).first():
        raise HTTPException(status_code=404, detail="운동 종류를 찾을 수 없습니다.")
    log = ExerciseLog(**payload.dict())
    db.add(log)
    db.commit()
    db.refresh(log)
    return log

@router.get(
    "/history",
    response_model=List[ExerciseLogOut],
    summary="운동 기록 조회",
    description="user_id에 해당하는 모든 운동 기록 반환"
)
def get_exercise_history(
    user_id: int,
    db: Session = Depends(get_db)
):
    return (
        db.query(ExerciseLog)
          .filter(ExerciseLog.user_id == user_id)
          .order_by(ExerciseLog.timestamp.desc())
          .all()
    )

@router.get(
    "/type",
    response_model=List[ExerciseTypeOut],
    summary="운동 종류 조회",
    description="등록된 운동 종류 목록 반환"
)
def get_exercise_types(
    db: Session = Depends(get_db)
):
    return db.query(ExerciseType).order_by(ExerciseType.id).all()

@router.get(
    "/stats/{user_id}",
    response_model=Dict[str, float],
    summary="통계 조회",
    description="user_id 기준 운동 통계를 반환"
)
def get_exercise_stats(
    user_id: int,
    db: Session = Depends(get_db)
):
    return compute_stats(db, user_id)
