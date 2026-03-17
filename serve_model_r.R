suppressPackageStartupMessages({
  devtools::load_all(".")
  library(plumber)
})

puerto <- as.integer(Sys.getenv("MODEL_R_PORT", unset = "8001"))
host <- Sys.getenv("MODEL_R_HOST", unset = "0.0.0.0")

pr <- plumber::plumb("plumber-r.R")
pr$run(host = host, port = puerto, swagger = TRUE)
