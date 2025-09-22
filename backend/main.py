# backend/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ✅ 라우터는 모두 APIRouter 객체로 임포트
from routers.health import router as health_router
from routers.test import router as test_router
from routers.exercise import router as exercise_router
from routers.predict_router import router as predict_router       # 새 분류 HTTP 라우터
from routers.session_stream import router as session_router       # 새 WS 스트리밍 라우터
from routers.auth import router as auth_router

# ✅ (NEW) 알림 라우터/스케줄러/모델 import
from routers.notification import router as notification_router
from scheduler.notification_scheduler import start_scheduler
from models.notification_models import Base as NotiBase
from database.connection import init_db, engine

app = FastAPI(title="AI 홈트레이너 백엔드")

# ✅ CORS는 한 번만 (자격증명 쓰면 * 대신 개별 오리진 나열)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        # 필요하면 아래처럼 로컬 IP 개발 서버도 추가 (웹 테스트용일 때만 필요)
        # "http://192.168.219.103:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ⚠️ init_db는 startup에서 호출하도록 변경 (중복 초기화 방지)
# init_db()

# ✅ 라우터는 각 1회만 등록
app.include_router(health_router)
app.include_router(test_router)
app.include_router(exercise_router)
app.include_router(predict_router)             # 새 HTTP: /predict/classify
app.include_router(session_router)             # 새 WS:  /sessions/ws
app.include_router(auth_router, prefix="/auth")
app.include_router(notification_router)        # (NEW) /notification

@app.get("/")
def health():
    return {"status": "ok"}

# ✅ (NEW) startup 훅: DB 초기화 + 알림 테이블 보장 + 스케줄러 시작
@app.on_event("startup")
def _startup():
    # 기존 DB 초기화 로직을 여기로 이동
    init_db()

    # 알림 관련 테이블 보장
    NotiBase.metadata.create_all(bind=engine)

    # 매분 체크해서 "사용자 설정 시간에, ON일 때만" 하루 1회 발송
    start_scheduler()
