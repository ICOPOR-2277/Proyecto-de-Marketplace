"""Pruebas del router de reseñas."""

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.resena import Resena
from app.models.usuario import Usuario

client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    db.query(Resena).delete()
    db.query(Usuario).delete()
    db.commit()
    db.close()


def test_crear_resena_con_autenticacion():
    primero = client.post(
        "/usuarios/registro",
        json={"nombre": "Miguel", "correo": "miguel@utb.edu.co", "password": "Clave123"},
    )
    segundo = client.post(
        "/usuarios/registro",
        json={"nombre": "Sofia", "correo": "sofia@utb.edu.co", "password": "Clave123"},
    )
    assert primero.status_code == 201
    assert segundo.status_code == 201

    db = SessionLocal()
    usuario_b = db.query(Usuario).filter(Usuario.correo == "sofia@utb.edu.co").first()
    db.close()
    assert usuario_b is not None

    token = client.post(
        "/usuarios/login",
        json={"correo": "miguel@utb.edu.co", "password": "Clave123"},
    ).json()["access_token"]

    calificacion = client.post(
        "/resenas/",
        json={
            "puntuacion": 5,
            "comentario": "Muy responsable y clara en la explicación.",
            "calificado_id": usuario_b.id,
        },
        headers={"Authorization": f"Bearer {token}"},
    )

    assert calificacion.status_code == 201
    assert calificacion.json()["puntuacion"] == 5
