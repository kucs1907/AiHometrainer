# backend/routers/predict_router.py
from fastapi import APIRouter, HTTPException, Query
from schemas.predict import PoseInput, PredictionResult
from utils.model_loader import load_model, predict

router = APIRouter(prefix="/predict", tags=["Predict"])

# 모델 로딩은 프로세스 시작 시 1회
_model_bundle = load_model()


@router.post("/classify", response_model=PredictionResult)
async def classify_pose(
    pose: PoseInput,
    exercise: str | None = Query(
        None, description="운동명: pushup/pullup/squat/plank/dips"
    ),
):
    try:
        # PoseInput.keypoints -> [[x, y, score], ...] 형태로 변환
        keypoints = [[kp.x, kp.y, kp.score] for kp in pose.keypoints]

        # utils.model_loader.predict(...)는 dict를 반환한다고 가정
        # 예: {"label": "...", "proba": 0.87, "proba_vector": [...], "source": "real"|"dummy"}
        result = predict(_model_bundle, keypoints, exercise=exercise) or {}

        label = str(result.get("label", "unknown"))
        proba = float(result.get("proba", 0.0))
        proba_vector = result.get("proba_vector", [])
        source = result.get("source")  # 선택적
        message = "모델 추론 성공" if source == "real" else "더미 추론 성공" if source else "모델 추론 성공"

        return PredictionResult(
            user_id=pose.user_id,
            label=label,
            proba=proba,
            proba_vector=proba_vector,
            message=message,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
