import numpy as np
from pathlib import Path
from .config import settings

class _LazyKeras:
    def __init__(self): self._keras=None
    @property
    def keras(self):
        if self._keras is None:
            from tensorflow import keras
            self._keras = keras
        return self._keras
_lazy = _LazyKeras()

def _list_exercise_models(base_dir: str):
    base = Path(base_dir); mapping = {}
    if not base.exists(): return mapping
    for h5 in base.glob("*_model.h5"):
        name = h5.name.replace("_model.h5","")
        enc = h5.with_name(f"{name}_encoder.joblib")
        mapping[name] = {"model_path": str(h5), "encoder_path": str(enc) if enc.exists() else None}
    return mapping

def _load_classes(exercise: str, enc_path: str|None):
    classes = ["correct","wrong"]
    if enc_path:
        try:
            import joblib
            le = joblib.load(enc_path)
            if hasattr(le,"classes_") and len(le.classes_)>0: classes=list(le.classes_)
        except Exception: pass
    return [c if c.startswith(f"{exercise}_") else f"{exercise}_{c}" for c in classes]

def load_model():
    bundle = {"global": None, "classes": None, "exercises": {}, "classes_by_ex": {}}
    try:
        p = Path(settings.model_path)
        if p.exists():
            m = _lazy.keras.models.load_model(p)
            classes = ["dips_correct","dips_wrong","plank_correct","plank_wrong","pullup_correct","pullup_wrong","pushup_correct","pushup_wrong","squat_correct","squat_wrong"]
            try:
                import joblib
                le_p = Path(settings.label_encoder_path)
                if le_p.exists():
                    le = joblib.load(le_p)
                    if hasattr(le,"classes_"): classes=list(le.classes_)
            except Exception: pass
            bundle["global"]=m; bundle["classes"]=classes
    except Exception as e:
        print("Global model load failed:", e)
    for ex, meta in _list_exercise_models(settings.exercises_models_dir).items():
        try:
            m = _lazy.keras.models.load_model(meta["model_path"])
            bundle["exercises"][ex]=m
            bundle["classes_by_ex"][ex]=_load_classes(ex, meta.get("encoder_path"))
        except Exception as e:
            print(f"Failed to load model for {ex}:", e)
    return bundle

def predict(model_bundle, keypoints, exercise: str|None=None):
    arr = np.array(keypoints, dtype=np.float32).reshape(1,-1)
    if exercise and exercise in model_bundle.get("exercises",{}):
        model = model_bundle["exercises"][exercise]
        classes = model_bundle["classes_by_ex"].get(exercise,[f"{exercise}_correct", f"{exercise}_wrong"])
        probs = model.predict(arr, verbose=0)[0]
        idx = int(np.argmax(probs))
        return {"label": classes[idx], "proba": float(probs[idx]), "proba_vector": {c: float(p) for c,p in zip(classes, probs)}}
    model = model_bundle.get("global"); classes = model_bundle.get("classes") or []
    if model is None or not classes:
        exs = list(model_bundle.get("exercises",{}).keys())
        if exs: return predict(model_bundle, keypoints, exercise=exs[0])
        raise RuntimeError("No model loaded.")
    probs = model.predict(arr, verbose=0)[0]
    idx = int(np.argmax(probs))
    return {"label": classes[idx], "proba": float(probs[idx]), "proba_vector": {c: float(p) for c,p in zip(classes, probs)}}
