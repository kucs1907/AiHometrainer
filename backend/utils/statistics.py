from sqlalchemy.orm import Session
from sqlalchemy import func
from models.tables import ExerciseLog
from typing import Dict

def compute_stats(db: Session, user_id: int) -> Dict[str, float]:
    """
    user_id 기준으로 평균 점수, 총 횟수, 총 소요시간, 세션 수 계산
    """
    result = (
        db.query(
            func.avg(ExerciseLog.score).label("avg_score"),
            func.sum(ExerciseLog.count).label("total_count"),
            func.sum(ExerciseLog.duration).label("total_duration"),
            func.count(ExerciseLog.id).label("session_count"),
        )
        .filter(ExerciseLog.user_id == user_id)
        .one()
    )
    return {
        "average_score": float(result.avg_score or 0.0),
        "total_count": int(result.total_count or 0),
        "total_duration": float(result.total_duration or 0.0),
        "session_count": int(result.session_count or 0),
    }
