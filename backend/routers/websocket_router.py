# backend/routers/websocket_router.py
from fastapi import APIRouter, WebSocket

# 이 라우터는 개발용 더미였던 /ws/exercise 엔드포인트를 완전히 비활성화합니다.
# 실제 스트리밍/저장은 /sessions/ws (routers/session_stream.py)만 사용하세요.

router = APIRouter(tags=["websocket (disabled)"])

@router.websocket("/ws/exercise")
async def websocket_exercise(websocket: WebSocket):
    await websocket.accept()
    # 명확한 에러를 내려주고 즉시 종료
    await websocket.send_json({
        "type": "error",
        "message": "This endpoint is disabled. Use /sessions/ws instead."
    })
    await websocket.close(code=1001)
