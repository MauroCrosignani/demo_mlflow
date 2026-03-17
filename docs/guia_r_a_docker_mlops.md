# Guía Paso A Paso Para Pasar De R A Una Solución Dockerizable Y Entregable A MLOps

## Propósito

Este documento está pensado para una persona que sabe trabajar en R, pero no necesariamente sabe dockerizar modelos ni preparar un entregable para un equipo técnico de MLOps.

El objetivo es dejar una solución completa y transferible que permita:

- entrenar un modelo en R
- registrar runs y artefactos en MLflow
- servir el modelo como API
- entregar una estructura clara para integración técnica posterior

## Qué partes del proyecto importan

- Entrenamiento en R: `R/train_and_log_model.R`
- Carga del último modelo registrado: `R/load_latest_logged_model.R`
- API de inferencia en R: `plumber-r.R`
- Script para levantar la API: `serve_model_r.R`
- Monitor de drift y reentrenamiento: `R/monitor_and_retrain.R`
- Script ejecutable del monitor: `monitor.R`
- Tracking server: `Dockerfile`
- Contenedor de inferencia R: `Dockerfile.R`
- Orquestación objetivo: `docker-compose.yml`
- Preparación de datos: `scripts/prepare_flights_data.py`

## Paso 1. Preparar los datos

La demo usa un parquet local:

- `data-raw/Combined_Flights_2022.parquet`

Si ya existe el CSV fuente, construir el parquet:

```powershell
py scripts/prepare_flights_data.py --force
```

Si el CSV no existe y se cuenta con una URL directa:

```powershell
$env:FLIGHTS_CSV_URL="URL_DIRECTA_DEL_CSV"
py scripts/prepare_flights_data.py --force
```

Resultado esperado:

- `data-raw/Flights_2022_1.csv`
- `data-raw/Combined_Flights_2022.parquet`

## Paso 2. Levantar MLflow

En esta máquina, la forma más estable para demo y validación fue levantar MLflow en host:

```powershell
py -m mlflow server --workers 1 --backend-store-uri sqlite:///mlflow.db/host_mlflow.db --default-artifact-root ./mlruns --host 127.0.0.1 --port 5001
```

Verificar:

- UI disponible en `http://127.0.0.1:5001`

## Paso 3. Entrenar y registrar el modelo en R

Ejecutar:

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
Rscript pruebas_mvp.R
```

Qué hace este paso:

- carga el paquete local con `devtools::load_all()`
- lee el parquet con DuckDB
- entrena un modelo lineal con `tidymodels`
- registra parámetros, métricas y artefacto en MLflow

Qué verificar:

- aparece una nueva run en MLflow
- se registran métricas `rmse` y `mae`
- queda disponible un artefacto `.rds`

## Paso 4. Exponer el modelo como API en R

Levantar el servicio:

```powershell
Rscript serve_model_r.R
```

Verificar salud:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8001/ping"
```

Ejecutar una predicción:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8001/predict" -Method Post -ContentType "application/json" -Body '{"Distance":500,"DayOfWeek":3,"Month":7}'
```

Verificar documentación automática:

- `http://127.0.0.1:8001/__docs__/`

## Paso 5. Entender qué se entrega al equipo técnico

El equipo de MLOps no necesita rehacer el modelado en R. Lo que se les entrega es:

1. código fuente del entrenamiento
2. script de inferencia
3. Dockerfile del servicio de inferencia
4. docker-compose con la arquitectura objetivo
5. monitor de drift y reentrenamiento
6. instrucciones para preparar datos

El valor del entregable no es “el script de R” aislado, sino el conjunto:

- modelo versionable
- endpoint HTTP
- artefacto reproducible
- mecanismo de monitoreo

## Paso 6. Dockerizar la solución de R

El contenedor de inferencia en R ya está definido en:

- `Dockerfile.R`

Ese Dockerfile:

- parte de `rocker/r-ver:4.2.1`
- instala dependencias del sistema
- instala paquetes de R necesarios
- copia el código del proyecto
- expone el puerto `8001`
- arranca `serve_model_r.R`

Construcción manual:

```powershell
docker build -f Dockerfile.R -t demo-mlflow-r .
```

Ejecución manual:

```powershell
docker run --rm -p 8001:8001 -v ${PWD}/mlruns:/app/mlruns demo-mlflow-r
```

## Paso 7. Qué debe quedar claro para el traspaso

La persona que entrega desde R debe informar explícitamente:

- cuál es el archivo de datos de entrada
- qué columnas usa el modelo
- dónde queda el tracking server
- dónde quedan los artefactos
- qué endpoint expone la predicción
- qué variable o script dispara el reentrenamiento

Checklist de traspaso:

- parquet generado y documentado
- run de R validada en MLflow
- API `plumber` validada
- Dockerfile.R probado o al menos revisado
- script de monitoreo documentado
- guía técnica de integración disponible

## Paso 8. Limitaciones que conviene comunicar sin ocultarlas

- En Windows hubo fricción con Docker Desktop.
- La parte más sensible no fue el modelado en R sino la operación del entorno.
- El paquete `mlflow` de R requirió algunos workarounds para logging de artefactos en Windows.

Esto no invalida el enfoque, pero es importante que el equipo técnico lo sepa antes de moverlo a otro entorno.

## Resultado esperado

Si se siguieron estos pasos, la solución queda lista para que un equipo técnico pueda:

- montar MLflow
- levantar el servicio de inferencia en R
- integrarlo con otros servicios
- programar el monitor de drift
- mantener el flujo sin depender de trabajo manual del analista
