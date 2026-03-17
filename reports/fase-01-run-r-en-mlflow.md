# Fase 01: Run real desde R en MLflow

## Objetivo

Demostrar que un flujo de entrenamiento desarrollado en R puede registrar una corrida real en MLflow local, con métricas y artefacto del modelo.

## Cambios realizados

- Se corrigió la configuración de MLflow en Docker para que el backend SQLite use una ruta válida dentro del contenedor.
- Se ajustó `train_and_log_model()` para registrar el workflow entrenado como artefacto `.rds`, alineado con la especificación.
- Se agregó una estrategia robusta para Windows: cuando el logging estándar de artefactos desde R no es confiable, el modelo se guarda en la estructura local de artefactos que MLflow ya expone en `mlruns/`.

## Verificación ejecutada

Comando usado:

```powershell
Rscript pruebas_mvp.R
```

Resultado observado:

- Conexión exitosa a `http://localhost:5000`
- Entrenamiento completado con muestra de 5000 filas
- Run registrada en el experimento `vuelos_retraso_mvp`
- Última run validada: `51ee5200bf7841ee994a15eeff7c7110`
- Métricas obtenidas:
  - `RMSE: 37.87`
  - `MAE: 21.54`

## Evidencia local

- Experimento disponible en la UI de MLflow: `http://localhost:5000`
- Artefacto del modelo guardado en:

```text
mlruns/1/51ee5200bf7841ee994a15eeff7c7110/artifacts/modelo_vuelos/modelo_vuelos.rds
```

## Decisiones técnicas

- `mlflow_log_model()` no soportó objetos `workflow` de `tidymodels` en este proyecto.
- En Windows, el paquete de R `mlflow` presentó problemas al invocar el CLI de Python para subir artefactos.
- Para no bloquear la demo, el artefacto `.rds` se publicó directamente en la ruta de artefactos del run local, que es suficiente para la PoC y coherente con la especificación del MVP.
- Se cerraron como `FAILED` las runs antiguas que habían quedado abiertas durante pruebas intermedias.

## Estado de la fase

Completada.
