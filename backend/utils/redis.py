import os
import redis.asyncio as aioredis
from .config import settings

# 비동기 Redis 클라이언트
redis_client = aioredis.from_url(
    f"redis://{settings.redis_host}:{settings.redis_port}/{settings.redis_db}",
    encoding="utf-8", decode_responses=True
)