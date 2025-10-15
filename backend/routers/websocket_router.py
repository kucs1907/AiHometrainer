# backend/routers/websocket_router.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from datetime import datetime
from database.connection import SessionLocal
from models.exercise import ExerciseSession

router = APIRouter(tags=["websocket"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.websocket("/ws/exercise")
async def websocket_exercise(websocket: WebSocket):
    await websocket.accept()
    db: Session = next(get_db())
    try:
        while True:
            data = await websocket.receive_json()

            # 더미 추론 결과
            real_score, real_count, real_duration = 0.85, 15, 12.3

            sess = ExerciseSession(
                user_id=str(data["user_id"]),
                exercise=f"type_{data.get('exercise_type_id', 0)}",
                reps=real_count,
                correct_ratio=real_score,
                # start/end는 이벤트 훅이 처리 (KST)
            )
            db.add(sess)
            db.commit()
            db.refresh(sess)

            await websocket.send_json({
                "score": real_score,
                "count": real_count,
                "duration": real_duration,
                "log_id": sess.id,  # 프론트 호환 키
                "timestamp": (sess.start_time).isoformat(),
            })
    except WebSocketDisconnect:
        pass
    finally:
        db.close()
