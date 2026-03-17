from __future__ import annotations

import argparse
import os
from pathlib import Path

import pandas as pd
import requests


def download_file(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        with destination.open("wb") as file_out:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file_out.write(chunk)


def build_parquet(csv_path: Path, parquet_path: Path) -> None:
    parquet_path.parent.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(csv_path)
    df.to_parquet(parquet_path, index=False)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Descarga el CSV de vuelos y construye el parquet usado por la demo."
    )
    parser.add_argument(
        "--csv-url",
        default=os.getenv("FLIGHTS_CSV_URL", ""),
        help="URL directa del CSV fuente. También puede proveerse con FLIGHTS_CSV_URL.",
    )
    parser.add_argument(
        "--csv-path",
        default="data-raw/Flights_2022_1.csv",
        help="Ruta local del CSV fuente.",
    )
    parser.add_argument(
        "--parquet-path",
        default="data-raw/Combined_Flights_2022.parquet",
        help="Ruta local del parquet de salida.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Reconstruye el parquet incluso si ya existe.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv_path)
    parquet_path = Path(args.parquet_path)

    if parquet_path.exists() and not args.force:
        print(f"Parquet ya disponible en: {parquet_path}")
        return

    if not csv_path.exists():
        if not args.csv_url:
            raise SystemExit(
                "No existe el CSV fuente y no se proporcionó FLIGHTS_CSV_URL o --csv-url."
            )
        print(f"Descargando CSV desde: {args.csv_url}")
        download_file(args.csv_url, csv_path)
        print(f"CSV descargado en: {csv_path}")

    print(f"Construyendo parquet en: {parquet_path}")
    build_parquet(csv_path, parquet_path)
    print("Parquet generado correctamente.")


if __name__ == "__main__":
    main()
