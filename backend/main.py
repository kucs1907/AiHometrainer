# backend/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ✅ 라우터는 모두 APIRouter 객체로 임포트
from routers.health import router as health_router
from routers.test import router as test_router
from routers.exercise import router as exercise_router
from routers.predict_router import router as predict_router       # 새 분류 HTTP 라우터
from routers.session_stream import router as session_router       # 새 WS 스트리밍 라우터 (정식)
from routers.auth import router as auth_router

# ✅ (NEW) 알림 라우터/스케줄러/모델 import
from routers.notification import router as notification_router
from scheduler.notification_scheduler import start_scheduler
from models.notification_models import Base as NotiBase
from database.connection import init_db, engine

# ⚠️ 비활성 라우터(개발용 더미)는 절대 include하지 마세요.
# from routers.websocket_router import router as disabled_ws_router  # <- 불필요/비활성

app = FastAPI(title="AI 홈트레이너 백엔드")

# ✅ CORS는 한 번만 (자격증명 쓰면 * 대신 개별 오리진 나열)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        # 배포 환경 오리진을 쓰는 경우 여기에 추가하세요. 예: "https://app.your-domain.com"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ 라우터는 각 1회만 등록
app.include_router(health_router)
app.include_router(test_router)
app.include_router(exercise_router)
app.include_router(predict_router)             # 새 HTTP: /predict/classify
app.include_router(session_router)             # 새 WS:  /sessions/ws  ← 여기가 정식 엔드포인트
app.include_router(auth_router, prefix="/auth")
app.include_router(notification_router)        # (NEW) /notification

@app.get("/")
def health():
    return {"status": "ok"}

# ✅ (NEW) startup 훅: DB 초기화 + 알림 테이블 보장 + 스케줄러 시작
@app.on_event("startup")
def _startup():
    init_db()
    NotiBase.metadata.create_all(bind=engine)
    start_scheduler()
