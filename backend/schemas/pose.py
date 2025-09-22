from pydantic import BaseModel

class Keypoint(BaseModel):
    x: float
    y: float
    z: float
    score: float

class PoseInput(BaseModel):
    user_id: int
    exercise_type: str
    keypoints: list[Keypoint]
