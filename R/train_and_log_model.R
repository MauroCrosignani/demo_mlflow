#' Entrena y registra un modelo de predicción de retrasos de vuelos
#'
#' @description Esta función ingesta datos en formato Parquet utilizando DuckDB para
#'   minimizar el uso de RAM, entrena un modelo de regresión lineal simple con
#'   `{tidymodels}` para predecir los minutos de retraso, y registra los parámetros,
#'   métricas (RMSE, MAE) y el modelo en MLflow. Finalmente, devuelve un objeto `{vetiver}`.
#'
#' @param data_path Cadena de texto. Ruta al archivo Parquet de vuelos (ej. "data-raw/Combined_Flights_2022.parquet").
#' @param mlflow_uri Cadena de texto. URI del servidor de MLflow. Por defecto "http://localhost:5000".
#' @param experiment_name Cadena de texto. Nombre del experimento en MLflow.
#' @param sample_size Entero. Número de filas a extraer para el entrenamiento inicial.
#' @param modo_depuracion Lógico. Si es `TRUE`, imprime mensajes de diagnóstico en consola.
#'
#' @return Un objeto de clase `vetiver_model`.
#' @export
#'
#' @import recipes parsnip workflows yardstick
#' @import dplyr
#' @import duckdb
#' @import mlflow
#' @import vetiver
#' @import cli
#' @import httr
train_and_log_model <- function(data_path,
                                mlflow_uri = "http://localhost:5000",
                                experiment_name = "vuelos_retraso_mvp",
                                sample_size = 50000,
                                modo_depuracion = TRUE) {

  # 1. Validación Inicial (Fail-Fast) para MLflow
  if (modo_depuracion) cli::cli_alert_info("Verificando conexión con MLflow en {mlflow_uri}...")

  ping <- tryCatch(
    httr::GET(mlflow_uri, httr::timeout(3)),
    error = function(e) return(NULL)
  )

  if (is.null(ping) || ping$status_code >= 400) {
    cli::cli_abort(
      c(
        "x" = "No se pudo conectar al servidor de MLflow en {.url {mlflow_uri}}.",
        "i" = "Asegúrate de que el contenedor de MLflow esté corriendo."
      )
    )
  }

  if (modo_depuracion) cli::cli_alert_success("Conexión a MLflow exitosa.")

  # 2. Ingesta Eficiente con DuckDB
  if (modo_depuracion) cli::cli_alert_info("Conectando a DuckDB y leyendo muestra de {.file {data_path}}...")

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Usamos SQL directo para que DuckDB lea el Parquet y haga el LIMIT antes de traer a RAM R
  query <- glue::glue("SELECT * FROM read_parquet('{data_path}') LIMIT {sample_size}")
  df <- DBI::dbGetQuery(con, query)

  if (nrow(df) == 0) {
    cli::cli_abort("El archivo Parquet está vacío o la ruta es incorrecta.")
  }

  # Limpieza mínima para el MVP (asumimos ArrDelayMinutes como target)
  df_clean <- df |>
    dplyr::select(ArrDelayMinutes, Distance, DayOfWeek, Month) |>
    tidyr::drop_na()

  if (modo_depuracion) cli::cli_alert_success("Datos cargados: {nrow(df_clean)} filas en memoria.")

  # 3. Modelado con tidymodels
  if (modo_depuracion) cli::cli_alert_info("Entrenando modelo de regresión lineal...")

  receta <- recipes::recipe(ArrDelayMinutes ~ Distance + DayOfWeek + Month, data = df_clean)

  especificacion <- parsnip::linear_reg() |>
    parsnip::set_engine("lm") |>
    parsnip::set_mode("regression")

  flujo <- workflows::workflow() |>
    workflows::add_recipe(receta) |>
    workflows::add_model(especificacion)

  flujo_entrenado <- parsnip::fit(flujo, data = df_clean)

  # Calcular Métricas (RMSE y MAE) en datos de entrenamiento para el MVP
  predicciones <- stats::predict(flujo_entrenado, new_data = df_clean) |>
    dplyr::bind_cols(df_clean)

  metricas_fn <- yardstick::metric_set(yardstick::rmse, yardstick::mae)
  resultados_metricas <- metricas_fn(predicciones, truth = ArrDelayMinutes, estimate = .pred)

  rmse_val <- resultados_metricas |> dplyr::filter(.metric == "rmse") |> dplyr::pull(.estimate)
  mae_val <- resultados_metricas |> dplyr::filter(.metric == "mae") |> dplyr::pull(.estimate)

  # 4. Registro (Logging) en MLflow
  if (modo_depuracion) cli::cli_alert_info("Registrando experimento en MLflow...")

  mlflow::mlflow_set_tracking_uri(mlflow_uri)
  mlflow::mlflow_set_experiment(experiment_name)

  run <- mlflow::mlflow_start_run()

  # Logueamos hiperparámetros y métricas
  mlflow::mlflow_log_param("sample_size", sample_size)
  mlflow::mlflow_log_param("model_type", "linear_regression")
  mlflow::mlflow_log_metric("rmse", rmse_val)
  mlflow::mlflow_log_metric("mae", mae_val)

  # Logueamos el modelo como un artefacto
  mlflow::mlflow_log_model(flujo_entrenado, artifact_path = "modelo_vuelos")

  mlflow::mlflow_end_run(run_id = run$run_uuid)

  if (modo_depuracion) cli::cli_alert_success("Run completado. RMSE: {round(rmse_val, 2)} | MAE: {round(mae_val, 2)}")

  # 5. Creación del objeto Vetiver para la futura API
  modelo_vetiver <- vetiver::vetiver_model(
    flujo_entrenado,
    model_name = "flight_delay_model",
    description = "Modelo MVP para predicción de retrasos (Linear Regression)"
  )

  return(modelo_vetiver)
}
