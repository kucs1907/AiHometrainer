# backend/utils/statistics.py
from sqlalchemy.orm import Session
from typing import Dict
from models.exercise import ExerciseSession

def compute_stats(db: Session, user_id: int) -> Dict[str, float]:
    """
    user_id 기준으로 평균 점수(correct_ratio), 총 횟수(reps), 총 소요시간, 세션 수 계산
    총 소요시간은 Python 레벨에서 합산 (DB 비종속적으로 처리)
    """
    rows = (
        db.query(ExerciseSession)
          .filter(ExerciseSession.user_id == str(user_id))
          .all()
    )

    session_count = len(rows)
    total_reps = 0
    total_duration = 0.0
    sum_score = 0.0
    scored = 0

    for r in rows:
        total_reps += (r.reps or 0)
        if r.end_time and r.start_time:
            total_duration += (r.end_time - r.start_time).total_seconds()
        if r.correct_ratio is not None:
            sum_score += float(r.correct_ratio)
            scored += 1

    avg_score = (sum_score / scored) if scored else 0.0

    return {
        "average_score": float(avg_score),
        "total_count": int(total_reps),
        "total_duration": float(total_duration),
        "session_count": int(session_count),
    }
