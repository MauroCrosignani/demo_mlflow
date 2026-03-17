devtools::load_all()

mlflow_uri <- Sys.getenv("MLFLOW_URI", unset = "http://localhost:5000")
sample_size <- as.integer(Sys.getenv("SAMPLE_SIZE", unset = "5000"))

modelo <- train_and_log_model(
  data_path = "data-raw/Combined_Flights_2022.parquet",
  mlflow_uri = mlflow_uri,
  sample_size = sample_size,
  modo_depuracion = TRUE
)

invisible(modelo)
