# Guía Técnica Paso A Paso Para Integrar Los Contenedores, Servir El Modelo Y Ejecutar Monitoreo De Drift

## Propósito

Este documento está pensado para perfiles técnicos de MLOps o infraestructura que no participaron en el desarrollo original del modelo.

El objetivo es permitir que el equipo pueda:

- levantar los servicios
- exponer los modelos por API
- registrar y consultar runs en MLflow
- ejecutar periódicamente el monitor de drift
- disparar reentrenamiento automático cuando corresponda

## Arquitectura prevista

El proyecto define tres servicios principales:

- `mlflow_server`
- `model_r`
- `model_python`

Puertos esperados:

- MLflow: `5000`
- API R: `8001`
- API Python: `8002`

Archivos relevantes:

- `docker-compose.yml`
- `Dockerfile`
- `Dockerfile.R`
- `Dockerfile.Py`
- `serve_model_r.R`
- `model_python_api.py`
- `monitor.R`

## Requisitos mínimos, recomendados y óptimos

### Mínimos

- Windows 10 o Linux
- 8 GB de RAM
- 2 núcleos
- 10 GB libres en disco
- Docker o, alternativamente, ejecución en host

Escenario realista:

- MLflow en host
- APIs probadas de a una
- monitoreo ejecutado manualmente o por scheduler

Riesgo:

- alto para `docker compose up -d --build` completo en Windows con otras aplicaciones abiertas

### Recomendados

- 16 GB de RAM
- 4 núcleos
- 20 GB libres en disco
- Docker Desktop o Docker Engine sin presión fuerte de memoria

Escenario realista:

- composición parcial o completa con bastante más estabilidad
- builds menos sensibles
- mejor margen para servir ambos modelos

Riesgo:

- medio en Windows
- bajo a medio en Linux

### Óptimos

- Linux o servidor con Docker Engine estable
- 32 GB de RAM
- 4 a 8 núcleos
- SSD con 30 GB o más libres

Escenario realista:

- operación sostenida
- builds reproducibles
- ejecución periódica del monitor con menor probabilidad de fallos transitorios

Riesgo:

- bajo

## Paso 1. Preparar insumos y directorios

Asegurar existencia de:

- `data-raw/Combined_Flights_2022.parquet`
- `mlruns/`
- `mlflow.db/`

Si el parquet no existe, generarlo:

```powershell
py scripts/prepare_flights_data.py --force
```

## Paso 2. Validar la composición

Revisar la configuración:

```powershell
docker compose config
```

Este comando debe resolver:

- servicios
- puertos
- volúmenes
- healthchecks

## Paso 3. Levantar MLflow

Opción A, objetivo final con Docker:

```powershell
docker compose up -d --build mlflow_server
```

Opción B, alternativa estable para Windows host:

```powershell
py -m mlflow server --workers 1 --backend-store-uri sqlite:///mlflow.db/host_mlflow.db --default-artifact-root ./mlruns --host 127.0.0.1 --port 5001
```

Verificación:

- `http://localhost:5000` si corre en Docker
- `http://127.0.0.1:5001` si corre en host

## Paso 4. Registrar modelos base

Registrar modelo en R:

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
Rscript pruebas_mvp.R
```

Registrar modelo en Python:

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
py train_and_log_python.py
```

Qué verificar:

- mismo experimento en MLflow
- runs visibles de R y Python
- artefactos `.rds` y `.pkl`

## Paso 5. Levantar el servicio de inferencia en R

Modo host:

```powershell
Rscript serve_model_r.R
```

Verificar:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8001/ping"
Invoke-RestMethod -Uri "http://127.0.0.1:8001/predict" -Method Post -ContentType "application/json" -Body '{"Distance":500,"DayOfWeek":3,"Month":7}'
```

Modo Docker:

```powershell
docker compose up -d --build model_r
```

Healthcheck esperado:

- `GET /ping`

## Paso 6. Levantar el servicio de inferencia en Python

Modo host:

```powershell
py -m uvicorn model_python_api:app --host 127.0.0.1 --port 8002
```

Verificar:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8002/ping"
Invoke-RestMethod -Uri "http://127.0.0.1:8002/predict" -Method Post -ContentType "application/json" -Body '{"Distance":500,"DayOfWeek":3,"Month":7}'
```

Modo Docker:

```powershell
docker compose up -d --build model_python
```

Documentación esperada:

- `http://127.0.0.1:8002/docs`

## Paso 7. Levantar la solución completa

Cuando el entorno Docker esté estable:

```powershell
docker compose up -d --build
```

Verificar:

- MLflow responde
- `model_r` responde en `/ping`
- `model_python` responde en `/ping`

Comandos útiles:

```powershell
docker compose ps
docker compose logs --no-color mlflow_server
docker compose logs --no-color model_r
docker compose logs --no-color model_python
```

## Paso 8. Configurar el monitoreo de drift

El script operativo es:

- `monitor.R`

Ese script delega en:

- `R/monitor_and_retrain.R`

Lógica actual:

- toma una muestra base del parquet
- toma una muestra reciente
- calcula cambio relativo de medias en variables clave
- obtiene un `drift_score`
- si supera el umbral, dispara `train_and_log_model()`

Ejecución manual:

```powershell
$env:MLFLOW_URI="http://127.0.0.1:5001"
Rscript monitor.R
```

Resultado esperado:

- imprime `drift_score`
- indica si hay o no reentrenamiento
- si hay drift suficiente, crea una nueva run en MLflow

## Paso 9. Programar ejecución periódica

En Windows, opción simple con Task Scheduler:

- crear una tarea que ejecute `Rscript monitor.R`
- definir `MLFLOW_URI` en el entorno de la tarea
- programar frecuencia diaria, horaria o según SLA

Ejemplo de comando base:

```powershell
cmd /c "set MLFLOW_URI=http://127.0.0.1:5001 && Rscript C:\ruta\demo_mlflow\monitor.R"
```

En Linux o servidor, opción simple con cron:

```bash
MLFLOW_URI=http://mlflow_server:5000 Rscript /ruta/demo_mlflow/monitor.R
```

Frecuencia orientativa:

- diaria si el ingreso de datos es frecuente
- semanal si la operación es de baja variación

## Paso 10. Qué observar en operación

Indicadores mínimos:

- estado de healthcheck de los tres servicios
- nuevas runs generadas por el monitor
- drift score observado en cada ejecución
- tiempo de respuesta de `/predict`
- crecimiento de `mlruns/` y `mlflow.db/`

## Paso 11. Riesgos operativos conocidos

- Windows y Docker Desktop fueron el entorno menos estable durante la PoC.
- El logging de artefactos en R sobre Windows requirió lógica adicional.
- Para operación sostenida, conviene migrar a un entorno Linux o contenedores estables.

## Paso 12. Criterio de éxito técnico

La integración puede considerarse lograda cuando:

1. MLflow responde y guarda runs de ambos lenguajes.
2. Las APIs de R y Python responden por HTTP.
3. El monitor corre sin intervención manual.
4. Una ejecución con drift suficiente deja una run nueva en MLflow.
5. El flujo puede ser operado por técnicos sin intervención del desarrollador original.
