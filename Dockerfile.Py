FROM python:3.10-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY model_python_api.py train_and_log_python.py ./

RUN pip install fastapi mlflow pandas pyarrow scikit-learn uvicorn

EXPOSE 8002

CMD ["uvicorn", "model_python_api:app", "--host", "0.0.0.0", "--port", "8002"]
