from fastapi import APIRouter

router = APIRouter(prefix="/test", tags=["Test"])

@router.get("/")
def test_response():
    return {"message": "API 연결 테스트 성공"}