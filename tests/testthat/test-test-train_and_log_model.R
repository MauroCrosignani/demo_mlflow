library(testthat)
library(httr)

test_that("train_and_log_model lanza error si MLflow no está disponible (Fail-Fast)", {
  # Simulamos una URI que sabemos que no existe para forzar el fallo
  uri_falsa <- "http://localhost:9999"

  # Verificamos que lanza un error estructurado por cli (abort)
  expect_error(
    train_and_log_model(
      data_path = "ruta_falsa.parquet",
      mlflow_uri = uri_falsa,
      modo_depuracion = FALSE
    ),
    regexp = "No se pudo conectar al servidor de MLflow"
  )
})

# NOTA: Los tests que involucran entrenamiento real e interacciones con DuckDB/MLflow
# requerirían 'mocks' (simulaciones) o fixtures locales en un entorno de CI/CD.
# Por ahora validamos nuestro chequeo de robustez principal.
