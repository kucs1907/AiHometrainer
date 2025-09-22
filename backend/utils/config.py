# backend/utils/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # DB / cache
    database_url: str | None = None
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0

    # model
    model_path: str = "./models/fitness_model.h5"
    label_encoder_path: str = "./models/label_encoder.joblib"
    exercises_models_dir: str = "./models/aiModel"  # per-exercise models  # ← 클래스 안으로 이동!

    # etc
    kakao_api_key: str | None = None

    # .env 읽기 + 알 수 없는 키 무시
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )

settings = Settings()
