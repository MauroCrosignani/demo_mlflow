# Fase 04: Docker Compose con tres servicios

## Objetivo

Dejar la demo orquestada con tres servicios coherentes con la especificación:

- `mlflow_server`
- `model_r`
- `model_python`

## Cambios realizados

- Se extendió `docker-compose.yml` para incluir los servicios `model_r` y `model_python`.
- Se agregó `Dockerfile.R` para empaquetar la API de inferencia en R.
- Se agregó `Dockerfile.Py` para empaquetar la API de inferencia en Python.
- Se creó `model_python_api.py` con FastAPI y endpoints:
  - `GET /ping`
  - `POST /predict`
- Ambos servicios montan `./mlruns` como volumen para acceder a los modelos registrados.

## Verificación ejecutada

- `docker compose config` validó correctamente la composición con los tres servicios.
- La API de Python respondió localmente con:
  - `GET /ping -> ok`
  - `POST /predict -> 200 OK`
- La API de R ya había sido validada localmente en la fase anterior con:
  - `GET /ping -> ok`
  - `POST /predict -> 200 OK`
- El intento de `docker compose up -d --build model_r model_python` no terminó de validarse por un problema del engine de Docker Desktop en esta máquina:
  - timeout largo de build
  - respuestas `500 Internal Server Error` del API del daemon de Docker

## Accesos objetivo

- `http://localhost:5000`
- `http://localhost:8001/ping`
- `http://localhost:8002/ping`
- `http://localhost:8002/docs`

## Estado de la fase

Implementada. La validación completa en contenedores quedó bloqueada por Docker Desktop, no por la definición de `compose` ni por el código de las APIs.
