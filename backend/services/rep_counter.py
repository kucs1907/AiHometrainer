# services/rep_counter.py
from __future__ import annotations
from datetime import datetime, timedelta
from typing import Optional

# ✅ 서버에서 '수용'할 최소 간격(초)
SERVER_REP_COOLDOWN_SEC = 1  # ← 원하면 2,3 등으로 조절

class RepCounter:
    """
    - state: init/up/down 전이로 1회 완성
    - count: '수용된'(쿨다운 통과) 반복 횟수
    - correct_ratio:
        * proba가 들어오면: 수용된 rep들의 평균 proba
        * proba가 안 들어오면: 기존처럼 correct/total 프레임 비율
    """
    def __init__(self, exercise: str):
        self.exercise = exercise
        self.state = "init"
        self.count = 0

        # 프레임 기반 통계(프로바 미사용 시 폴백)
        self.total = 0
        self.correct = 0

        # 쿨다운 상태
        self._last_rep_at: Optional[datetime] = None

        # 수용된 rep들의 평균 proba 계산용
        self._acc_sum = 0.0
        self._acc_n = 0

    # --- 내부 유틸 ---
    def _cooldown_passed(self, now: Optional[datetime] = None) -> bool:
        now = now or datetime.utcnow()
        if self._last_rep_at is None:
            return True
        return (now - self._last_rep_at) >= timedelta(seconds=SERVER_REP_COOLDOWN_SEC)

    def _accept_rep(self, proba: Optional[float], now: Optional[datetime] = None) -> None:
        """전이 성립 + 쿨다운 통과 시에만 수용(+1)"""
        now = now or datetime.utcnow()
        if not self._cooldown_passed(now):
            return
        self.count += 1
        self._last_rep_at = now
        if proba is not None:
            try:
                self._acc_sum += float(proba)
                self._acc_n += 1
            except Exception:
                pass

    # --- 외부 호출 메서드 ---
    def step(self, label: str, proba: Optional[float] = None) -> int:
        """
        모델의 label(예: 'pushup_correct' / 'pushup_wrong')과
        선택적으로 proba(0~1)를 넣으면,
        상태 전이를 보고 쿨다운 통과 시 count를 +1 수용.
        반환: 현재 수용된 count
        """
        # 프레임 통계(폴백용)
        self.total += 1
        is_correct_frame = label.endswith("_correct")
        if is_correct_frame:
            self.correct += 1

        ex = self.exercise
        if ex in ("pushup", "squat", "pullup", "dips"):
            # 내려가는 동작 진입
            if self.state in ("init", "up") and is_correct_frame:
                self.state = "down"
            # 내려갔다가 올라오는 전이 → rep 후보
            elif self.state == "down" and not is_correct_frame:
                self.state = "up"
                # ✅ 쿨다운 통과 시에만 '수용'
                self._accept_rep(proba)
        # plank는 hold-time 계열 → count 증가 없음(필요 시 확장)

        return self.count

    @property
    def correct_ratio(self) -> float:
        """
        가능하면 수용된 rep들의 평균 proba를 반환,
        없으면 기존 프레임 correct/total 비율을 반환.
        """
        if self._acc_n > 0:
            return self._acc_sum / self._acc_n
        if self.total == 0:
            return 0.0
        return self.correct / self.total
