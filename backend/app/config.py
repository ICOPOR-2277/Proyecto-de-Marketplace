"""Configuración general de la aplicación (variables de entorno)."""
import os

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB_PATH = os.path.join(BASE_DIR, "marketplace.db").replace("\\", "/")

DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DEFAULT_DB_PATH}")
SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "marketplace-dev-secret-key-change-in-production-2026",
)
