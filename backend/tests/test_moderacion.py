"""Pruebas para el router de moderación y control de contenido."""
import pytest
from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.usuario import Usuario
from app.routers.usuarios import hash_password

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    # Asegurar que el moderador existe con rol administrador
    mod = db.query(Usuario).filter(Usuario.correo == "moderador_test@utb.edu.co").first()
    if not mod:
        mod = Usuario(
            nombre="Moderador Test",
            correo="moderador_test@utb.edu.co",
            password_hash=hash_password("moderador123"),
            es_administrador=True,
        )
        db.add(mod)
        db.commit()
    db.close()
    yield


def test_moderacion_unauthorized_sin_token():
    """Verifica que endpoints de moderación rechacen peticiones anónimas."""
    response = client.get("/moderacion/stats")
    assert response.status_code == 401


def test_moderacion_stats_con_moderador():
    """Verifica que el usuario moderador obtenga las estadísticas del dashboard."""
    login_res = client.post(
        "/usuarios/login",
        json={"correo": "moderador_test@utb.edu.co", "password": "moderador123"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]

    stats_res = client.get(
        "/moderacion/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert stats_res.status_code == 200
    data = stats_res.json()
    assert "total_publicaciones" in data
    assert "publicaciones_activas" in data
    assert "publicaciones_bloqueadas" in data
    assert "total_usuarios" in data
