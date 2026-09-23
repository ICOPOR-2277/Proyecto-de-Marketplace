"""Configuración general de la aplicación (variables de entorno)."""
import os

from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./marketplace.db")
SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "marketplace-dev-secret-key-change-in-production-2026",
)
