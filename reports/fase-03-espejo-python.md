# Fase 03: Espejo en Python y comparación en MLflow

## Objetivo

Registrar un modelo equivalente en Python dentro del mismo tracking server de MLflow para comparar ejecuciones de R y Python en una sola interfaz.

## Cambios realizados

- Se agregó `train_and_log_python.py`.
- El script usa el mismo dataset, las mismas variables y el mismo tipo de modelo lineal usados en R:
  - target: `ArrDelayMinutes`
  - features: `Distance`, `DayOfWeek`, `Month`
- La run de Python se registra en el mismo experimento `vuelos_retraso_mvp`.
- Se registra además el parámetro `implementation_language = python` para distinguir fácilmente las corridas.

## Verificación ejecutada

Comando:

```powershell
py train_and_log_python.py
```

Resultado observado:

- Run de R de referencia para comparación explícita: `fe0c865dfb3648d1b18cf3ecfccb7fa9`
- Run validada: `8f9dfa6124754714a3c0e7bedc8f4c8b`
- Nueva run visible en `http://localhost:5000`
- Métricas registradas:
  - `rmse = 37.8731`
  - `mae = 21.5383`
- Artefacto disponible en:

```text
mlruns/1/8f9dfa6124754714a3c0e7bedc8f4c8b/artifacts/modelo_vuelos_python/modelo_vuelos_python.pkl
```

- Comparación visual posible con las runs de R ya existentes en el mismo experimento
- Las runs nuevas de R y Python quedaron etiquetadas con `implementation_language`
- Se cerraron como `FAILED` las runs intermedias de Python que habían quedado abiertas durante las pruebas

## Estado de la fase

Completada.
