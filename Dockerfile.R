FROM rocker/r-ver:4.2.1

RUN apt-get update && apt-get install -y \
    curl \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY DESCRIPTION NAMESPACE ./
COPY R ./R
COPY plumber-r.R serve_model_r.R ./

RUN R -e "install.packages(c('DBI','cli','devtools','dplyr','duckdb','glue','httr','jsonlite','mlflow','parsnip','plumber','recipes','testthat','tidyr','vetiver','workflows','yardstick'), repos='https://cloud.r-project.org')"

EXPOSE 8001

CMD ["Rscript", "serve_model_r.R"]
