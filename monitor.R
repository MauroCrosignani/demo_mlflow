mlflow_uri <- Sys.getenv("MLFLOW_URI", unset = "http://localhost:5000")

devtools::load_all()

resultado <- monitor_and_retrain(
  data_path = "data-raw/Combined_Flights_2022.parquet",
  mlflow_uri = mlflow_uri,
  drift_threshold = 0.01,
  retrain_sample_size = 5000,
  modo_depuracion = TRUE
)

print(resultado)
