#' Monitorea drift simple y dispara reentrenamiento en R
#'
#' @description Compara una muestra base y una muestra reciente del dataset de
#'   vuelos usando cambios relativos de media en variables numéricas clave. Si el
#'   puntaje máximo de drift supera un umbral configurable, dispara un nuevo
#'   entrenamiento y registro en MLflow.
#'
#' @param data_path Ruta al archivo Parquet.
#' @param mlflow_uri URI del servidor de MLflow.
#' @param experiment_name Nombre del experimento de MLflow.
#' @param baseline_size Tamaño de la muestra base.
#' @param recent_size Tamaño de la muestra reciente.
#' @param drift_threshold Umbral de drift para disparar reentrenamiento.
#' @param retrain_sample_size Tamaño de muestra usado si se dispara reentrenamiento.
#' @param modo_depuracion Si es `TRUE`, imprime mensajes de diagnóstico.
#'
#' @return Una lista con `trigger_retraining`, `drift_score` y `metricas_drift`.
#' @export
monitor_and_retrain <- function(data_path,
                                mlflow_uri = "http://localhost:5000",
                                experiment_name = "vuelos_retraso_mvp",
                                baseline_size = 1000,
                                recent_size = 1000,
                                drift_threshold = 0.05,
                                retrain_sample_size = 5000,
                                modo_depuracion = TRUE) {
  if (modo_depuracion) cli::cli_alert_info("Analizando drift en {.file {data_path}}...")

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  total_filas <- DBI::dbGetQuery(
    con,
    glue::glue("SELECT COUNT(*) AS n FROM read_parquet('{data_path}')")
  )$n[[1]]

  if (total_filas < max(baseline_size, recent_size)) {
    cli::cli_abort("No hay suficientes filas para monitorear drift con los tamaños solicitados.")
  }

  recent_offset <- max(total_filas - recent_size, 0)
  columnas <- "Distance, DayOfWeek, Month"

  baseline <- DBI::dbGetQuery(
    con,
    glue::glue("SELECT {columnas} FROM read_parquet('{data_path}') LIMIT {baseline_size}")
  ) |>
    tidyr::drop_na()

  recent <- DBI::dbGetQuery(
    con,
    glue::glue("SELECT {columnas} FROM read_parquet('{data_path}') LIMIT {recent_size} OFFSET {recent_offset}")
  ) |>
    tidyr::drop_na()

  media_base <- vapply(baseline, mean, numeric(1))
  media_reciente <- vapply(recent, mean, numeric(1))
  drift_relativo <- abs(media_reciente - media_base) / pmax(abs(media_base), 1e-6)
  drift_score <- unname(max(drift_relativo))

  if (modo_depuracion) {
    cli::cli_alert_info("Puntaje máximo de drift detectado: {round(drift_score, 4)}")
  }

  trigger_retraining <- drift_score >= drift_threshold

  if (trigger_retraining) {
    if (modo_depuracion) {
      cli::cli_alert_warning(
        "Drift por encima del umbral ({round(drift_score, 4)} >= {drift_threshold}). Se dispara reentrenamiento."
      )
    }

    train_and_log_model(
      data_path = data_path,
      mlflow_uri = mlflow_uri,
      experiment_name = experiment_name,
      sample_size = retrain_sample_size,
      modo_depuracion = modo_depuracion
    )
  } else if (modo_depuracion) {
    cli::cli_alert_success("No se detectó drift suficiente para reentrenar.")
  }

  list(
    trigger_retraining = trigger_retraining,
    drift_score = drift_score,
    metricas_drift = drift_relativo
  )
}
