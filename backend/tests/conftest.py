import os
import sys
import pytest

# Asegurar que el directorio backend esté en sys.path para imports como 'from app...'
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# Forzar base de datos aislada para pruebas automáticas, protegiendo marketplace.db
os.environ["DATABASE_URL"] = "sqlite:///./test_marketplace.db"


@pytest.fixture(scope="session", autouse=True)
def cleanup_test_db():
    yield
    for db_path in ["test_marketplace.db", "backend/test_marketplace.db"]:
        if os.path.exists(db_path):
            try:
                os.remove(db_path)
            except Exception:
                pass
