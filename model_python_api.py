from __future__ import annotations

import pickle
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


class PredictionRequest(BaseModel):
    Distance: float
    DayOfWeek: int
    Month: int


def load_latest_python_model(mlruns_dir: str = "mlruns"):
    candidates = sorted(
        Path(mlruns_dir).glob("**/modelo_vuelos_python.pkl"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        raise FileNotFoundError(
            "No se encontró ningún artefacto modelo_vuelos_python.pkl en mlruns/."
        )
    with candidates[0].open("rb") as f:
        return pickle.load(f)


app = FastAPI(title="Modelo Python", version="0.1.0")
model = load_latest_python_model()


@app.get("/ping")
def ping():
    return {"status": "ok", "service": "model_python"}


@app.post("/predict")
def predict(payload: PredictionRequest):
    try:
        features = [[payload.Distance, payload.DayOfWeek, payload.Month]]
        prediction = float(model.predict(features)[0])
        return {
            "prediction": prediction,
            "model_engine": "Python/scikit-learn",
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
