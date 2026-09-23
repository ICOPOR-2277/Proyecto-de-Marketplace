"""Pruebas del router de búsqueda."""

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.publicacion import Publicacion
from app.models.usuario import Usuario

client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    db.query(Publicacion).delete()
    db.query(Usuario).delete()
    db.commit()
    db.close()


def test_busqueda_filtra_por_query_y_categoria():
    registro = client.post(
        "/usuarios/registro",
        json={"nombre": "Patricia", "correo": "patricia@utb.edu.co", "password": "Clave123"},
    )
    assert registro.status_code == 201

    token = client.post(
        "/usuarios/login",
        json={"correo": "patricia@utb.edu.co", "password": "Clave123"},
    ).json()["access_token"]

    response = client.post(
        "/publicaciones/",
        json={
            "titulo": "Tutoría de cálculo avanzado",
            "descripcion": "Acompañamiento para exámenes y tareas de cálculo.",
            "precio": 60000,
            "categoria": "Matemáticas",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 201

    busqueda = client.get("/busqueda/?query=cálculo&categoria=Matemáticas")
    assert busqueda.status_code == 200
    resultados = busqueda.json()
    assert len(resultados) >= 1
    assert resultados[0]["titulo"].lower().startswith("tutoría")
