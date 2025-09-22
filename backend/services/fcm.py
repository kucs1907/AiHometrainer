# backend/services/fcm.py
import os
import json
from typing import Optional, Dict, Any

import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleAuthRequest

SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]

class FCMClient:
    """
    Firebase Cloud Messaging HTTP v1 전송 클라이언트.
    환경 변수:
      - GOOGLE_APPLICATION_CREDENTIALS: 서비스 계정 JSON 경로
      - FCM_PROJECT_ID: Firebase 프로젝트 ID (예: 'aihometrainer')
    """
    def __init__(self, project_id: Optional[str] = None, sa_path: Optional[str] = None):
        # 우선순위: 인자 > 환경변수 > (없으면 런타임 에러)
        self.project_id = project_id or os.getenv("FCM_PROJECT_ID", "")
        if not self.project_id:
            raise RuntimeError("FCM_PROJECT_ID env is required.")

        self.sa_path = sa_path or os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
        if not self.sa_path or not os.path.exists(self.sa_path):
            raise RuntimeError("GOOGLE_APPLICATION_CREDENTIALS env points to a missing service account JSON.")

        self._credentials = service_account.Credentials.from_service_account_file(
            self.sa_path, scopes=SCOPES
        )
        self._authed_session = GoogleAuthRequest()

    def _get_access_token(self) -> str:
        if not self._credentials.valid:
            self._credentials.refresh(self._authed_session)
        return self._credentials.token

    def send_to_token(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        image_url: Optional[str] = None,  # 이미지 알림(빅 픽처)
    ) -> bool:
        access_token = self._get_access_token()
        url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"

        message: Dict[str, Any] = {
            "token": token,
            "notification": {"title": title, "body": body},
            "android": {"priority": "high", "notification": {}},
            "data": (data or {}),
        }
        if image_url:
            # 일부 런처는 notification.image, 일부는 android.notification.image 사용
            message["notification"]["image"] = image_url
            message["android"]["notification"]["image"] = image_url

        payload = {"message": message}
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json; UTF-8",
        }

        try:
            r = requests.post(url, headers=headers, data=json.dumps(payload), timeout=10)
            ok = 200 <= r.status_code < 300
            if not ok:
                print("[FCM v1] Error:", r.status_code, r.text[:400])
            return ok
        except Exception as e:
            print("[FCM v1] Exception:", e)
            return False
