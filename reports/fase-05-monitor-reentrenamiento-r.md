# Fase 05: Monitor de drift y trigger de reentrenamiento en R

## Objetivo

Demostrar que un flujo desarrollado en R puede evaluar drift y disparar automáticamente un reentrenamiento sin intervención manual.

## Cambios realizados

- Se agregó `monitor_and_retrain()` en R.
- La función:
  - toma una muestra base y una muestra reciente del parquet
  - calcula drift relativo por cambio de medias
  - genera un `drift_score`
  - dispara `train_and_log_model()` si el puntaje supera un umbral
- Se agregó `monitor.R` como script ejecutable del flujo de monitoreo.

## Verificación ejecutada

Comando:

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
Rscript monitor.R
```

Resultado observado:

- `drift_score = 0.4606`
- `trigger_retraining = TRUE`
- Se disparó automáticamente `train_and_log_model()`
- Nueva run terminada en MLflow host local: `2c74070ce12e48f5857f10c8ee37cfed`
- Métricas de drift detectadas:
  - `Distance = 0.4606`
  - `DayOfWeek = 0.3901`
  - `Month = 0.2500`

## Notas de entorno

- La validación final se ejecutó contra `http://127.0.0.1:5001`.
- Se usó `5001` en vez de `5000` porque Docker Desktop quedó inestable después de los intentos de build de la fase 4.
- El flujo validado sigue siendo el mismo: R monitorea drift y registra el reentrenamiento en un tracking server real de MLflow.

## Estado de la fase

Completada.
