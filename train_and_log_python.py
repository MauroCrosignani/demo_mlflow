from __future__ import annotations

import os
import pickle
import shutil
import sys
from pathlib import Path

import mlflow
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, root_mean_squared_error

os.environ.setdefault("GIT_PYTHON_REFRESH", "quiet")
os.environ.setdefault("PYTHONIOENCODING", "utf-8")
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def train_and_log_python_model(
    data_path: str = "data-raw/Combined_Flights_2022.parquet",
    mlflow_uri: str = "http://localhost:5000",
    experiment_name: str = "vuelos_retraso_mvp",
    sample_size: int = 5000,
) -> str:
    mlflow.set_tracking_uri(mlflow_uri)
    mlflow.set_experiment(experiment_name)

    df = pd.read_parquet(data_path).head(sample_size)
    df = df[["ArrDelayMinutes", "Distance", "DayOfWeek", "Month"]].dropna()

    x = df[["Distance", "DayOfWeek", "Month"]]
    y = df["ArrDelayMinutes"]

    model = LinearRegression()
    model.fit(x, y)
    preds = model.predict(x)

    rmse = root_mean_squared_error(y, preds)
    mae = mean_absolute_error(y, preds)

    run = mlflow.start_run()
    try:
        mlflow.log_param("sample_size", sample_size)
        mlflow.log_param("model_type", "linear_regression")
        mlflow.log_param("implementation_language", "python")
        mlflow.log_metric("rmse", rmse)
        mlflow.log_metric("mae", mae)

        tmp_dir = Path(".tmp_python_artifacts")
        tmp_dir.mkdir(exist_ok=True)
        model_path = tmp_dir / "modelo_vuelos_python.pkl"
        with model_path.open("wb") as f:
            pickle.dump(model, f)

        artifact_uri = run.info.artifact_uri
        if artifact_uri.startswith("/mlruns/") and Path("mlruns").exists():
            artifact_base = Path("mlruns") / artifact_uri.removeprefix("/mlruns/")
            artifact_dir = artifact_base / "modelo_vuelos_python"
            artifact_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(model_path, artifact_dir / "modelo_vuelos_python.pkl")
        else:
            mlflow.log_artifact(str(model_path), artifact_path="modelo_vuelos_python")

        shutil.rmtree(tmp_dir, ignore_errors=True)

        print(f"run_id={run.info.run_id}")
        print(f"rmse={rmse:.4f}")
        print(f"mae={mae:.4f}")
        mlflow.end_run(status="FINISHED")

        return run.info.run_id
    except Exception:
        shutil.rmtree(Path(".tmp_python_artifacts"), ignore_errors=True)
        mlflow.end_run(status="FAILED")
        raise


if __name__ == "__main__":
    train_and_log_python_model()
