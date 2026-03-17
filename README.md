# demo_mlflow

PoC para comparar un flujo de MLOps con **R** y con **Python** sobre el mismo problema, usando **MLflow** como punto común de tracking.

La pregunta de trabajo es:

**¿Es una posibilidad real usar R para desarrollar modelos sin renunciar al flujo de MLOps?**

La demo muestra que **sí**, siempre que el estándar operativo sea el mismo: tracking, API y artefactos reproducibles.

## Qué quedó implementado

- entrenamiento y logging en MLflow desde R
- API de inferencia en R con `plumber`
- entrenamiento y logging equivalente en Python
- API de inferencia en Python con `FastAPI`
- `docker-compose.yml` con la arquitectura objetivo de tres servicios
- monitor de drift en R que dispara reentrenamiento
- script reproducible para preparar el dataset y el parquet

## Dataset base

Referencia Kaggle:

- `https://www.kaggle.com/datasets/robikscube/flight-delay-dataset-20182022`

Slug usado por el script:

- `robikscube/flight-delay-dataset-20182022`

## Paso 0: preparar datos de forma reproducible

El proyecto ahora incluye un script real de provisión de datos:

- detecta `kaggle.json`
- descarga el zip con la Kaggle API
- descomprime los CSV
- construye `data-raw/Combined_Flights_2022.parquet`

Archivo:

- `scripts/prepare_flights_data.py`

### Requisitos

1. Instalar la Kaggle API:

```powershell
py -m pip install kaggle
```

2. Descargar el token desde:

- `https://www.kaggle.com/settings`

3. Guardar `kaggle.json` en una de estas ubicaciones:

- `.\kaggle.json`
- `%USERPROFILE%\.kaggle\kaggle.json`
- el directorio definido en `KAGGLE_CONFIG_DIR`

Contenido esperado de `kaggle.json`:

```json
{
  "username": "TU_USUARIO",
  "key": "TU_API_KEY"
}
```

### Ejecutar

```powershell
py scripts/prepare_flights_data.py --force
```

Resultado esperado:

- `data-raw/Flights_2022_1.csv`
- `data-raw/Combined_Flights_2022.parquet`

## Demo operativa de 5-10 minutos

La secuencia más estable en esta máquina es usar MLflow en host y las APIs localmente.

### Terminal 1: levantar MLflow en host

```powershell
py -m mlflow server --workers 1 --backend-store-uri sqlite:///mlflow.db/host_mlflow.db --default-artifact-root ./mlruns --host 127.0.0.1 --port 5001
```

UI:

- `http://127.0.0.1:5001`

### Terminal 2: registrar una run desde R

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
Rscript pruebas_mvp.R
```

### Terminal 3: levantar y probar la API de R

```powershell
Rscript serve_model_r.R
```

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8001/ping"
Invoke-RestMethod -Uri "http://127.0.0.1:8001/predict" -Method Post -ContentType "application/json" -Body '{"Distance":500,"DayOfWeek":3,"Month":7}'
```

### Terminal 4: registrar la run espejo desde Python

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
py train_and_log_python.py
```

### Paso final: monitoreo y reentrenamiento desde R

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
Rscript monitor.R
```

## Orden exacto para presentar

1. Mostrar que los datos se pueden preparar de forma reproducible desde Kaggle y que el parquet no depende de una copia manual.
2. Abrir MLflow y formular la pregunta: si usar R obliga o no a salir del flujo MLOps.
3. Mostrar una run hecha en R.
4. Mostrar la API de inferencia en R.
5. Mostrar la run equivalente en Python en el mismo experimento.
6. Mostrar el monitor en R disparando reentrenamiento.
7. Cerrar con la conclusión.

## Conclusión de la demo

- R sí puede participar en un flujo de MLOps real.
- El lenguaje no es el principal determinante; lo son el tracking, la API y la estandarización de artefactos.
- Las fricciones observadas estuvieron más ligadas al entorno Windows y a Docker Desktop que al modelado en R.

## Guías de handoff

- Perfiles R hacia despliegue y entrega a MLOps: `docs/guia_r_a_docker_mlops.md`
- Técnicos MLOps para integración y operación: `docs/guia_tecnica_integracion_mlops.md`
