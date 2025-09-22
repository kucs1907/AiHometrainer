# merged3/backend/schemas/exercise.py

from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ExerciseLogIn(BaseModel):
    user_id: int
    exercise_type_id: int
    count: int
    duration: float
    score: Optional[float] = 0.0

class ExerciseLogOut(ExerciseLogIn):
    id: int
    timestamp: datetime

    class Config:
        orm_mode = True

class ExerciseTypeOut(BaseModel):
    id: int
    name: str

    class Config:
        orm_mode = True
