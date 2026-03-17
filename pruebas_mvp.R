# Cargar el paquete
devtools::load_all()

# Ejecutar el entrenamiento
modelo <- train_and_log_model(
  data_path = "data-raw/Combined_Flights_2022.parquet",
  mlflow_uri = "http://localhost:5000",
  sample_size = 5000, # Pequeño para validar rápido
  modo_depuracion = TRUE
)

# Si esto funciona, verás mensajes de éxito y aparecerá un nuevo experimento en http://localhost:5000
