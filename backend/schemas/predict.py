from pydantic import BaseModel, Field
from typing import List, Dict

class Keypoint(BaseModel):
    x: float
    y: float
    score: float

class PoseInput(BaseModel):
    user_id: str
    keypoints: List[Keypoint]

class PredictionResult(BaseModel):
    user_id: str = Field(..., example="u-123")
    label: str = Field(..., example="pushup_correct")
    proba: float = Field(..., example=0.92)
    proba_vector: Dict[str, float]
    message: str = Field(..., example="모델 추론 성공")
