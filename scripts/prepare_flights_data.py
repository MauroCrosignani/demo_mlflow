from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

import pandas as pd

DATASET_SLUG = "robikscube/flight-delay-dataset-20182022"


def candidate_kaggle_json_paths() -> list[Path]:
    candidates: list[Path] = []

    kaggle_config_dir = os.getenv("KAGGLE_CONFIG_DIR")
    if kaggle_config_dir:
        candidates.append(Path(kaggle_config_dir) / "kaggle.json")

    candidates.append(Path.cwd() / "kaggle.json")
    candidates.append(Path.home() / ".kaggle" / "kaggle.json")

    return candidates


def find_kaggle_json() -> Path | None:
    for candidate in candidate_kaggle_json_paths():
        if candidate.exists():
            return candidate
    return None


def load_kaggle_credentials(kaggle_json_path: Path) -> dict[str, str]:
    with kaggle_json_path.open("r", encoding="utf-8") as file_in:
        data = json.load(file_in)

    if "username" not in data or "key" not in data:
        raise SystemExit("El archivo kaggle.json no contiene `username` y `key`.")

    return {"KAGGLE_USERNAME": data["username"], "KAGGLE_KEY": data["key"]}


def ensure_kaggle_cli() -> str:
    kaggle_bin = shutil.which("kaggle")
    if kaggle_bin:
        return kaggle_bin

    raise SystemExit(
        "No se encontró el comando `kaggle`. Instálalo con `py -m pip install kaggle`."
    )


def download_dataset_zip(
    kaggle_bin: str,
    dataset_slug: str,
    download_dir: Path,
    env: dict[str, str],
) -> Path:
    download_dir.mkdir(parents=True, exist_ok=True)

    command = [
        kaggle_bin,
        "datasets",
        "download",
        "-d",
        dataset_slug,
        "-p",
        str(download_dir),
        "-o",
    ]

    subprocess.run(command, check=True, env=env)

    zip_candidates = sorted(download_dir.glob("*.zip"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not zip_candidates:
        raise SystemExit("La descarga de Kaggle no produjo ningún archivo .zip.")

    return zip_candidates[0]


def extract_zip(zip_path: Path, extract_dir: Path) -> None:
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as zip_file:
        zip_file.extractall(extract_dir)


def find_2022_csv_files(extract_dir: Path) -> list[Path]:
    csv_files = sorted(extract_dir.rglob("Flights_2022*.csv"))
    if csv_files:
        return csv_files

    fallback = sorted(extract_dir.rglob("*.csv"))
    if fallback:
        return fallback

    raise SystemExit("No se encontraron archivos CSV luego de descomprimir el dataset.")


def materialize_primary_csv(csv_files: list[Path], target_csv_path: Path) -> None:
    target_csv_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(csv_files[0], target_csv_path)


def build_parquet(csv_files: list[Path], parquet_path: Path) -> None:
    parquet_path.parent.mkdir(parents=True, exist_ok=True)
    df = pd.concat((pd.read_csv(csv_file) for csv_file in csv_files), ignore_index=True)
    df.to_parquet(parquet_path, index=False)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Descarga el dataset de Kaggle, descomprime los CSV y construye "
            "Combined_Flights_2022.parquet."
        )
    )
    parser.add_argument(
        "--dataset",
        default=DATASET_SLUG,
        help="Slug del dataset de Kaggle en formato owner/dataset.",
    )
    parser.add_argument(
        "--download-dir",
        default="data-raw/kaggle_download",
        help="Directorio temporal para zip y extracción.",
    )
    parser.add_argument(
        "--csv-path",
        default="data-raw/Flights_2022_1.csv",
        help="Ruta local del CSV de referencia que se deja disponible en el proyecto.",
    )
    parser.add_argument(
        "--parquet-path",
        default="data-raw/Combined_Flights_2022.parquet",
        help="Ruta local del parquet de salida.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Reconstruye el parquet aunque ya exista.",
    )
    args = parser.parse_args()

    parquet_path = Path(args.parquet_path)
    if parquet_path.exists() and not args.force:
        print(f"Parquet ya disponible en: {parquet_path}")
        return

    kaggle_json_path = find_kaggle_json()
    if kaggle_json_path is None:
        searched = "\n".join(str(path) for path in candidate_kaggle_json_paths())
        raise SystemExit(
            "No se encontró `kaggle.json`.\n"
            "Ubicaciones buscadas:\n"
            f"{searched}\n"
            "Descarga el token desde https://www.kaggle.com/settings."
        )

    credentials = load_kaggle_credentials(kaggle_json_path)
    env = os.environ.copy()
    env.update(credentials)

    kaggle_bin = ensure_kaggle_cli()
    download_dir = Path(args.download_dir)

    print(f"Usando credenciales de: {kaggle_json_path}")
    print(f"Descargando dataset de Kaggle: {args.dataset}")
    zip_path = download_dataset_zip(kaggle_bin, args.dataset, download_dir, env)
    print(f"Zip descargado en: {zip_path}")

    extract_dir = download_dir / "extracted"
    print(f"Descomprimiendo en: {extract_dir}")
    extract_zip(zip_path, extract_dir)

    csv_files = find_2022_csv_files(extract_dir)
    print(f"CSV detectados para 2022: {len(csv_files)}")

    csv_path = Path(args.csv_path)
    materialize_primary_csv(csv_files, csv_path)
    print(f"CSV de referencia copiado en: {csv_path}")

    print(f"Construyendo parquet combinado en: {parquet_path}")
    build_parquet(csv_files, parquet_path)
    print("Parquet generado correctamente.")


if __name__ == "__main__":
    main()
