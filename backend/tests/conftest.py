import os
import pytest

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
