# backend/routers/session_stream.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState
from typing import Dict, Any, List, Optional
from statistics import mean
import traceback
from datetime import datetime, timezone, timedelta

from database.connection import SessionLocal
from models.exercise import ExerciseSession
from utils.model_loader import load_model, predict

router = APIRouter(prefix="/sessions", tags=["Sessions"])
_model_bundle = load_model()

KST = timezone(timedelta(hours=9))
def now_kst() -> datetime:
    return datetime.now(tz=KST)

async def _safe_send(ws: WebSocket, payload: Dict[str, Any]):
    if ws.client_state == WebSocketState.CONNECTED:
        await ws.send_json(payload)

class SessionState:
    def __init__(self, user_id: str, exercise: str, session_id: int):
        self.user_id = str(user_id)
        self.exercise = exercise
        self.session_id = session_id
        self.probas: List[float] = []
        self.finished: bool = False     # 중복 finish 방지

    def add_proba(self, p: float):
        self.probas.append(float(p))

    def correct_ratio(self) -> float:
        return float(mean(self.probas)) if self.probas else 0.0

@router.websocket("/ws")
async def sessions_ws(ws: WebSocket):
    await ws.accept()
    db = SessionLocal()

    state: Optional[SessionState] = None
    last_client_reps: int = 0

    try:
        # 클라가 바로 start를 보내지 못하는 상황 대비(선택)
        await _safe_send(ws, {"type": "hello", "note": "send start -> frame -> finish"})

        while True:
            msg = await ws.receive_json()
            t = msg.get("type")

            if t == "start":
                user_id = str(msg.get("user_id") or "1")
                exercise = str(msg.get("exercise") or "squat")

                # 1) 시작 시점에 DB row 생성 (session_id 확보)
                row = ExerciseSession(
                    user_id=user_id,           # 모델이 str/Int 혼용이면 스키마에 맞춰 형변환
                    exercise=exercise,
                    start_time=now_kst(),      # ▶ 칼럼명이 start_time인 모델 기준
                    reps=0,
                    correct_ratio=0.0,
                )
                db.add(row)
                db.commit()
                db.refresh(row)

                state = SessionState(user_id, exercise, row.id)

                # started + session_id 알림
                await _safe_send(ws, {"type": "started", "session_id": row.id})

            elif t == "frame":
                if state is None:
                    continue
                keypoints = msg.get("keypoints") or []

                # [{x,y,score}×17] → 51차원 벡터
                if keypoints and isinstance(keypoints[0], dict):
                    flat: List[float] = []
                    for p in keypoints:
                        flat.extend([
                            float(p.get("x", 0.0)),
                            float(p.get("y", 0.0)),
                            float(p.get("score", 0.0)),
                        ])
                    features = flat
                else:
                    features = keypoints

                res = predict(_model_bundle, features, exercise=state.exercise) or {}
                label = str(res.get("label", "unknown"))
                proba = float(res.get("proba", 0.0))
                state.add_proba(proba)

                # 중간 inferences (서버 카운트는 사용하지 않음)
                await _safe_send(ws, {
                    "type": "inference",
                    "label": label,
                    "proba": proba,
                })

            elif t == "finish":
                if state is None:
                    await _safe_send(ws, {"type": "error", "message": "no session"})
                    continue

                # 중복 finish 방지
                if state.finished:
                    # 멱등 응답: 현재 DB 값을 읽어 회신
                    row = db.get(ExerciseSession, state.session_id)
                    await _safe_send(ws, {
                        "type": "finished",
                        "session_id": state.session_id,
                        "reps": int(row.reps) if row else last_client_reps,
                        "correct_ratio": float(row.correct_ratio or 0.0) if row else 0.0,
                    })
                    continue
                state.finished = True

                # 클라 reps 폴백 저장
                client_reps = msg.get("client_reps")
                last_client_reps = int(client_reps) if client_reps is not None else 0

                # 2) 기존 row 업데이트 (UPDATE)
                row = db.get(ExerciseSession, state.session_id)
                if row is not None:
                    row.reps = last_client_reps
                    row.correct_ratio = state.correct_ratio()
                    row.end_time = now_kst()   # ▶ 칼럼명이 end_time인 모델 기준
                    db.commit()
                    db.refresh(row)

                    await _safe_send(ws, {
                        "type": "finished",
                        "session_id": row.id,
                        "reps": int(row.reps),
                        "correct_ratio": float(row.correct_ratio or 0.0),
                    })
                else:
                    # 혹시 start INSERT가 실패했던 극단적 예외 대비: 새로 저장 (최소 보존)
                    row = ExerciseSession(
                        user_id=state.user_id,
                        exercise=state.exercise,
                        start_time=now_kst(),
                        end_time=now_kst(),
                        reps=last_client_reps,
                        correct_ratio=state.correct_ratio(),
                    )
                    db.add(row)
                    db.commit()
                    db.refresh(row)
                    await _safe_send(ws, {
                        "type": "finished",
                        "session_id": row.id,
                        "reps": int(row.reps),
                        "correct_ratio": float(row.correct_ratio or 0.0),
                    })

            else:
                await _safe_send(ws, {"type": "error", "message": f"unknown type: {t}"})

    except WebSocketDisconnect:
        # 안전망: finish 미수신 상태에서 끊기면, 최소한 end_time만 찍어둠
        try:
            if state and not state.finished:
                row = db.get(ExerciseSession, state.session_id)
                if row and row.end_time is None:
                    row.end_time = now_kst()
                    db.commit()
        except Exception:
            traceback.print_exc()
    except Exception as e:
        traceback.print_exc()
        await _safe_send(ws, {"type": "error", "message": str(e)})
    finally:
        db.close()
        if ws.client_state == WebSocketState.CONNECTED:
            try:
                await ws.close(code=1000)
            except RuntimeError:
                pass
