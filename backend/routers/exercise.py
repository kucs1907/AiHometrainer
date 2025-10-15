# backend/routers/exercise.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Dict
from datetime import datetime

from database.connection import SessionLocal, engine
from utils.db import Base
from models.exercise import ExerciseSession
try:
    from models.tables import ExerciseType
except Exception:
    ExerciseType = None

from schemas.exercise import (
    ExerciseLogIn, ExerciseLogOut,
    ExerciseTypeOut
)
from utils.statistics import compute_stats

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

router = APIRouter(prefix="/exercise", tags=["exercise"])

# ---- user_id 정규화 유틸 ----
def normalize_user_id(v) -> str:
    s = str(v)
    return s[2:] if s.startswith("u-") else s  # 'u-1' -> '1'
# --------------------------------

@router.post(
    "/log",
    response_model=ExerciseLogOut,
    summary="운동 기록(세션) 저장",
    description="기존 ExerciseLogIn 스키마로 받아 exercise_sessions에 저장"
)
def create_exercise_log(
    payload: ExerciseLogIn,
    db: Session = Depends(get_db)
):
    # exercise 이름 결정
    exercise_name = None
    if ExerciseType:
        et = db.query(ExerciseType).filter_by(id=payload.exercise_type_id).first()
        if not et:
            raise HTTPException(status_code=404, detail="운동 종류를 찾을 수 없습니다.")
        exercise_name = et.name
    else:
        exercise_name = f"type_{payload.exercise_type_id}"

    # 세션 생성: count->reps, score->correct_ratio
    sess = ExerciseSession(
        user_id=normalize_user_id(payload.user_id),
        exercise=exercise_name,
        reps=payload.count,
        correct_ratio=payload.score or 0.0,
        # start/end는 이벤트 훅(KST)에서 처리
    )
    db.add(sess)
    db.commit()
    db.refresh(sess)

    # duration 계산(종료 미지정이면 payload.duration 사용)
    if sess.end_time and sess.start_time:
        duration = (sess.end_time - sess.start_time).total_seconds()
    else:
        duration = payload.duration or 0.0

    return ExerciseLogOut(
        id=sess.id,
        user_id=int(normalize_user_id(sess.user_id)),
        exercise_type_id=payload.exercise_type_id,
        count=sess.reps,
        duration=float(duration),
        score=float(sess.correct_ratio or 0.0),
        timestamp=sess.start_time,
        exercise=sess.exercise,  # ✅ 세션명 포함
    )

@router.get(
    "/history",
    response_model=List[ExerciseLogOut],
    summary="운동 기록(세션) 조회",
    description="user_id에 해당하는 모든 세션 반환 (기존 ExerciseLogOut 호환)"
)
def get_exercise_history(
    user_id: int,
    db: Session = Depends(get_db)
):
    uid = normalize_user_id(user_id)          # "1"
    uid_legacy = f"u-{uid}"                   # "u-1" (과거 데이터 호환)
    rows = (
        db.query(ExerciseSession)
          .filter(ExerciseSession.user_id.in_([uid, uid_legacy]))
          .order_by(ExerciseSession.start_time.desc())
          .all()
    )

    data: List[ExerciseLogOut] = []
    for r in rows:
        if r.end_time and r.start_time:
            duration = (r.end_time - r.start_time).total_seconds()
        else:
            duration = 0.0
        data.append(
            ExerciseLogOut(
                id=r.id,
                user_id=int(normalize_user_id(r.user_id)),
                exercise_type_id=0,  # 필요 시 조인해 채워도 됨
                count=r.reps or 0,
                duration=float(duration),
                score=float(r.correct_ratio or 0.0),
                timestamp=r.start_time,
                exercise=r.exercise,  # ✅ 포함
            )
        )
    return data

@router.get(
    "/type",
    response_model=List[ExerciseTypeOut],
    summary="운동 종류 조회",
    description="등록된 운동 종류 목록 반환"
)
def get_exercise_types(
    db: Session = Depends(get_db)
):
    if not ExerciseType:
        return []
    return db.query(ExerciseType).order_by(ExerciseType.id).all()

@router.get(
    "/stats/{user_id}",
    response_model=Dict[str, float],
    summary="통계 조회",
    description="user_id 기준 운동 통계를 반환 (세션 기반)"
)
def get_exercise_stats(
    user_id: int,
    db: Session = Depends(get_db)
):
    # utils.statistics도 normalize를 쓰도록 바꾸는 게 베스트지만,
    # 여기서도 호환해두면 안전.
    # 원하면 utils.statistics 쪽도 동일 방식으로 정규화 적용하세요.
    return compute_stats(db, int(normalize_user_id(user_id)))
