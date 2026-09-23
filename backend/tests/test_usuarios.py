"""Pruebas del router de usuarios."""

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.usuario import Usuario

client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    db.query(Usuario).delete()
    db.commit()
    db.close()


def test_root_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["mensaje"] == "API del marketplace de servicios entre estudiantes"


def test_registro_y_login_exitosos():
    payload = {
        "nombre": "Ana García",
        "correo": "ana@utb.edu.co",
        "password": "Secreto123",
    }

    response = client.post("/usuarios/registro", json=payload)
    assert response.status_code == 201
    body = response.json()
    assert body["correo"] == payload["correo"]
    assert body["nombre"] == payload["nombre"]
    assert "password" not in body

    login_response = client.post(
        "/usuarios/login",
        json={"correo": payload["correo"], "password": payload["password"]},
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()
