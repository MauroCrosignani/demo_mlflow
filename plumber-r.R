library(jsonlite)
library(plumber)

modelo <- load_latest_logged_model()

#* Healthcheck simple del servicio
#* @get /ping
function() {
  list(status = "ok", servicio = "model_r")
}

#* Predicción de retraso de vuelos usando el modelo entrenado en R
#* @post /predict
#* @serializer unboxedJSON
function(req, res) {
  entrada <- jsonlite::fromJSON(req$postBody, simplifyDataFrame = TRUE)
  entrada_df <- as.data.frame(entrada)

  columnas_requeridas <- c("Distance", "DayOfWeek", "Month")
  faltantes <- setdiff(columnas_requeridas, names(entrada_df))
  if (length(faltantes) > 0) {
    res$status <- 400
    return(list(
      error = "Faltan columnas requeridas en el payload.",
      faltantes = faltantes
    ))
  }

  pred <- predict(modelo, new_data = entrada_df)

  list(
    prediction = as.numeric(pred$.pred[[1]]),
    model_engine = "R/tidymodels"
  )
}
