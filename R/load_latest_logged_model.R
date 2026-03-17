#' Carga el último modelo registrado localmente en MLflow
#'
#' @description Busca el artefacto `modelo_vuelos.rds` más reciente dentro de la
#'   estructura local de `mlruns/` y lo devuelve como objeto entrenado.
#'
#' @param mlruns_dir Ruta al directorio local de artefactos de MLflow.
#'
#' @return Un objeto entrenado serializado en RDS.
#' @export
load_latest_logged_model <- function(mlruns_dir = "mlruns") {
  if (!dir.exists(mlruns_dir)) {
    cli::cli_abort(c("x" = "No existe el directorio de artefactos {.file {mlruns_dir}}."))
  }

  patrones <- list.files(
    path = mlruns_dir,
    pattern = "^modelo_vuelos\\.rds$",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(patrones) == 0) {
    cli::cli_abort(c(
      "x" = "No se encontró ningún artefacto {.file modelo_vuelos.rds} en {.file {mlruns_dir}}.",
      "i" = "Ejecuta primero el entrenamiento y registro en MLflow."
    ))
  }

  info <- file.info(patrones)
  ruta_modelo <- rownames(info)[which.max(info$mtime)]
  readRDS(ruta_modelo)
}
