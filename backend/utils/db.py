from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from .config import settings

DATABASE_URL = settings.database_url or "sqlite:///./app.db"

engine = create_engine(DATABASE_URL, future=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)

class Base(DeclarativeBase):
    pass

def init_db():
    from models.exercise import Base as ExerciseBase
    ExerciseBase.metadata.create_all(bind=engine)
