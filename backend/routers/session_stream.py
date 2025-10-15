# routers/session_stream.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from utils.model_loader import load_model, predict
from services.rep_counter import RepCounter
from utils.db import SessionLocal, init_db
from models.exercise import ExerciseSession, SessionEvent
import datetime as dt
import json

# ★ 추가: 상태 확인을 위해 import
from starlette.websockets import WebSocketState

router = APIRouter(prefix="/sessions", tags=["Sessions"])
_model_bundle = load_model()

@router.on_event("startup")
def _startup():
    init_db()

# ★ 추가: 안전 전송 헬퍼
async def _safe_send_json(websocket: WebSocket, payload: dict):
    if websocket.client_state == WebSocketState.CONNECTED:
        await websocket.send_json(payload)

@router.websocket("/ws")
async def ws_session(websocket: WebSocket):
    await websocket.accept()
    db = SessionLocal()
    rep = None
    session_row = None

    # ★ 권장: exercise를 미리 함수 스코프에서 초기화
    exercise = "unknown"
    user_id = "unknown"

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except Exception:
                await _safe_send_json(websocket, {"type": "error", "message": "invalid json"})
                continue

            mtype = msg.get("type")
            if mtype == "start":
                user_id = msg.get("user_id", "unknown")
                exercise = msg.get("exercise", "unknown")

                rep = RepCounter(exercise)
                session_row = ExerciseSession(
                    user_id=user_id,
                    exercise=exercise,
                    reps=0,
                    correct_ratio=0.0,
                    start_time=dt.datetime.utcnow(),
                    end_time=dt.datetime.utcnow(),
                )
                db.add(session_row)
                db.commit()
                db.refresh(session_row)
                await _safe_send_json(websocket, {"type": "started", "session_id": session_row.id})

            elif mtype == "frame":
                if rep is None:
                    await _safe_send_json(websocket, {"type": "error", "message": "session not started"})
                    continue

                kps = msg.get("keypoints", [])
                if not isinstance(kps, list) or len(kps) < 17:
                    await _safe_send_json(websocket, {"type": "error", "message": "need 17 keypoints"})
                    continue

                keypoints = [
                    [float(kp.get("x", 0)), float(kp.get("y", 0)), float(kp.get("score", 1.0))]
                    for kp in kps[:17]
                ]
                result = predict(_model_bundle, keypoints, exercise=exercise)

                # ★ 여기만 핵심 변경: proba를 함께 넘겨 쿨다운 수용 + 평균 proba 반영
                proba = float(result.get("proba", 0.0) or 0.0)
                count = rep.step(result["label"], proba)

                if session_row:
                    ev = SessionEvent(
                        session_id=session_row.id,
                        label=result["label"],
                        proba=proba,
                        raw=json.dumps(result),
                    )
                    db.add(ev)
                    db.commit()

                await _safe_send_json(
                    websocket,
                    {
                        "type": "inference",
                        "label": result["label"],
                        "proba": proba,
                        "count": count,  # ← 서버 쿨다운 통과해 '수용된' 값만 방송
                        "proba_vector": result.get("proba_vector"),
                    },
                )

            elif mtype == "finish":
                if session_row and rep:
                    session_row.reps = rep.count
                    session_row.correct_ratio = rep.correct_ratio
                    session_row.end_time = dt.datetime.utcnow()
                    db.add(session_row)
                    db.commit()

                    await _safe_send_json(
                        websocket,
                        {
                            "type": "finished",
                            "session_id": session_row.id,
                            "reps": rep.count,
                            "correct_ratio": rep.correct_ratio,
                        },
                    )

                # ★ 서버가 닫는 전략: 여기서 한 번만 close 하고 종료
                if websocket.client_state == WebSocketState.CONNECTED:
                    try:
                        await websocket.close(code=1000)
                    except RuntimeError:
                        pass
                return  # break 말고 return으로 즉시 함수 종료

            else:
                await _safe_send_json(websocket, {"type": "error", "message": "unknown message type"})

    except WebSocketDisconnect:
        # 클라이언트가 먼저 끊은 경우
        pass

    except Exception as e:
        # 에러를 알릴 때도 연결 상태일 때만
        await _safe_send_json(websocket, {"type": "error", "message": str(e)})

    finally:
        db.close()
        # ★ 이미 닫혔으면 다시 닫지 않음
        if websocket.client_state == WebSocketState.CONNECTED:
            try:
                await websocket.close(code=1000)
            except RuntimeError:
                pass
