from apscheduler.schedulers.background import BackgroundScheduler
from sqlalchemy.orm import Session
from datetime import datetime
import pytz

from database.connection import SessionLocal
from services.fcm import FCMClient
from models.notification_models import NotificationPref, NotificationToken

TITLE = "리마인드"
BODY = "설정한 시간 알림입니다."
IMAGE_URL = None  # 사진 알림 원하면 HTTPS 이미지 URL로 교체

def send_daily_notifications():
    db: Session = SessionLocal()
    fcm = FCMClient()
    try:
        # ON인 사용자만
        prefs_list = db.query(NotificationPref).filter(NotificationPref.enabled == True).all()
        for p in prefs_list:
            tzinfo = pytz.timezone(p.timezone or "Asia/Seoul")
            now = datetime.now(tzinfo)

            # ⏰ "해당 시:분"에만 보냄 (하루 1회 동작)
            if now.hour == p.hour and now.minute == p.minute:
                tokens = db.query(NotificationToken).filter(NotificationToken.user_id == p.user_id).all()
                for t in tokens:
                    fcm.send_to_token(
                        t.token,
                        TITLE,
                        BODY,
                        data={"type": "daily_reminder"},
                        image_url=IMAGE_URL
                    )
    finally:
        db.close()

def start_scheduler() -> BackgroundScheduler:
    sched = BackgroundScheduler(timezone="UTC")
    # ✅ 매 분 '초=0'에 정확히 실행
    sched.add_job(
        send_daily_notifications,
        trigger="cron",
        second=0,
        id="daily_notification_job",
        replace_existing=True,
        misfire_grace_time=30,  # 시작 지연 시 30초 내면 실행
        coalesce=True,          # 누락된 실행이 여러 개면 1회로 합치기
    )
    sched.start()
    print("[Scheduler] daily_notification_job started (cron: second=0)")
    return sched