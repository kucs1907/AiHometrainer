class RepCounter:
    def __init__(self, exercise: str):
        self.exercise = exercise
        self.state = "init"
        self.count = 0
        self.total = 0
        self.correct = 0

    def step(self, label: str) -> int:
        self.total += 1
        is_correct = label.endswith("_correct")
        if is_correct:
            self.correct += 1

        ex = self.exercise
        if ex in ("pushup","squat","pullup","dips"):
            if self.state in ("init","up") and is_correct:
                self.state = "down"
            elif self.state == "down" and not is_correct:
                self.state = "up"
                self.count += 1
        # plank -> hold-time; count remains 0
        return self.count

    @property
    def correct_ratio(self) -> float:
        if self.total == 0:
            return 0.0
        return self.correct / self.total
