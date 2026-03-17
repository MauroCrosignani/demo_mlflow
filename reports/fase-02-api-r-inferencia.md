# Fase 02: API de inferencia en R

## Objetivo

Exponer el modelo entrenado en R como un servicio HTTP simple, reproducible y documentado automáticamente.

## Cambios realizados

- Se agregó `load_latest_logged_model()` para cargar el último artefacto `modelo_vuelos.rds` desde `mlruns/`.
- Se creó `plumber-r.R` con dos endpoints:
  - `GET /ping`
  - `POST /predict`
- Se creó `serve_model_r.R` para levantar la API en el puerto `8001`.
- Se actualizaron `DESCRIPTION` y `NAMESPACE` para reflejar las dependencias y exports usados en esta fase.

## Verificación ejecutada

Secuencia usada:

```powershell
Rscript serve_model_r.R
GET  http://127.0.0.1:8001/ping
POST http://127.0.0.1:8001/predict
```

Payload validado:

```json
{
  "Distance": 500,
  "DayOfWeek": 3,
  "Month": 7
}
```

Resultado observado:

- `GET /ping` respondió con estado `ok`
- `POST /predict` devolvió una predicción numérica
- Swagger quedó disponible en `http://127.0.0.1:8001/__docs__/`

Respuesta de ejemplo:

```json
{
  "prediction": 13.3511,
  "model_engine": "R/tidymodels"
}
```

## Decisiones técnicas

- La API carga el modelo más reciente desde `mlruns/` para evitar acoplarla a un `run_id` fijo.
- Se usó `plumber` por su soporte nativo para documentación Swagger/OpenAPI.
- El servicio quedó separado del entrenamiento para reflejar un flujo más cercano a producción.

## Estado de la fase

Completada.
