from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from utils.model_loader import load_model, predict
from services.rep_counter import RepCounter
from utils.db import SessionLocal, init_db
from models.exercise import ExerciseSession, SessionEvent
import datetime as dt
import json

router = APIRouter(prefix="/sessions", tags=["Sessions"])
_model_bundle = load_model()

@router.on_event("startup")
def _startup():
    init_db()

@router.websocket("/ws")
async def ws_session(websocket: WebSocket):
    await websocket.accept()
    db = SessionLocal()
    rep = None
    session_row = None
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except Exception:
                await websocket.send_json({"type":"error","message":"invalid json"})
                continue

            mtype = msg.get("type")
            if mtype == "start":
                user_id = msg.get("user_id","unknown")
                exercise = msg.get("exercise","unknown")
                rep = RepCounter(exercise)
                session_row = ExerciseSession(
                    user_id=user_id, exercise=exercise, reps=0,
                    correct_ratio=0.0, start_time=dt.datetime.utcnow(), end_time=dt.datetime.utcnow()
                )
                db.add(session_row)
                db.commit()
                db.refresh(session_row)
                await websocket.send_json({"type":"started","session_id":session_row.id})
            elif mtype == "frame":
                if rep is None:
                    await websocket.send_json({"type":"error","message":"session not started"})
                    continue
                kps = msg.get("keypoints", [])
                if not isinstance(kps, list) or len(kps) < 17:
                    await websocket.send_json({"type":"error","message":"need 17 keypoints"})
                    continue
                keypoints = [[float(kp.get("x",0)), float(kp.get("y",0)), float(kp.get("score",1.0))] for kp in kps[:17]]
                result = predict(_model_bundle, keypoints, exercise=exercise)
                count = rep.step(result["label"])
                if session_row:
                    ev = SessionEvent(session_id=session_row.id, label=result["label"], proba=result["proba"], raw=json.dumps(result))
                    db.add(ev)
                    db.commit()
                await websocket.send_json({
                    "type":"inference",
                    "label": result["label"],
                    "proba": result["proba"],
                    "count": count,
                    "proba_vector": result["proba_vector"]
                })
            elif mtype == "finish":
                if session_row and rep:
                    session_row.reps = rep.count
                    session_row.correct_ratio = rep.correct_ratio
                    session_row.end_time = dt.datetime.utcnow()
                    db.add(session_row)
                    db.commit()
                    await websocket.send_json({"type":"finished","session_id": session_row.id, "reps": rep.count, "correct_ratio": rep.correct_ratio})
                break
            else:
                await websocket.send_json({"type":"error","message":"unknown message type"})
    except WebSocketDisconnect:
        pass
    finally:
        db.close()
        await websocket.close()
