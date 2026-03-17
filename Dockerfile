FROM python:3.10-slim

# Instalar curl y dependencias necesarias
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Instalar mlflow
RUN pip install mlflow

# Exponer el puerto de MLflow
EXPOSE 5000

# Comando para iniciar MLflow
CMD ["mlflow", "server", "--backend-store-uri", "sqlite:////mlflow/mlflow.db", "--default-artifact-root", "/mlruns", "--host", "0.0.0.0", "--port", "5000"]
