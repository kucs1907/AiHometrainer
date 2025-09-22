from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from database.connection import SessionLocal
from models.tables import ExerciseLog
# from utils.model_loader import load_model, predict  # 나중에 실제 모델 호출용

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
    # DB 세션 가져오기
    db: Session = next(get_db())
    try:
        while True:
            data = await websocket.receive_json()
            # 1) AI 추론 결과 (더미)
            # real_score, real_count, real_duration = predict(data["image"])
            real_score, real_count, real_duration = 0.85, 15, 12.3

            # 2) DB에 저장
            log = ExerciseLog(
                user_id=data["user_id"],
                exercise_type_id=data.get("exercise_type_id", 0),
                count=real_count,
                duration=real_duration,
                score=real_score
            )
            db.add(log)
            db.commit()
            db.refresh(log)

            # 3) 클라이언트로 응답
            await websocket.send_json({
                "score": real_score,
                "count": real_count,
                "duration": real_duration,
                "log_id": log.id,
                "timestamp": log.timestamp.isoformat(),
            })
    except WebSocketDisconnect:
        pass
    finally:
        db.close()
