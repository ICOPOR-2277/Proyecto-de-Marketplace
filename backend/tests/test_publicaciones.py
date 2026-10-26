"""Pruebas del router de publicaciones."""

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.publicacion import Publicacion
from app.models.usuario import Usuario

client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)


def test_crear_publicacion_requiere_autenticacion():
    login = client.post(
        "/usuarios/login",
        json={"correo": "luis@utb.edu.co", "password": "Clave123"},
    )
    if login.status_code != 200:
        registro = client.post(
            "/usuarios/registro",
            json={"nombre": "Luis", "correo": "luis@utb.edu.co", "password": "Clave123"},
        )
        assert registro.status_code == 201
        login = client.post(
            "/usuarios/login",
            json={"correo": "luis@utb.edu.co", "password": "Clave123"},
        )
    assert login.status_code == 200
    token = login.json()["access_token"]

    response = client.post(
        "/publicaciones/",
        json={
            "titulo": "Tutoría de cálculo",
            "descripcion": "Repaso de integrales y derivadas.",
            "precio": 50000,
            "categoria": "Matemáticas",
        },
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 201
    assert response.json()["titulo"] == "Tutoría de cálculo"
    assert response.json()["precio"] == 50000


def test_gestion_mis_publicaciones_editar_cambiar_estado_y_eliminar():
    # 1. Registrar y loguear usuario
    login = client.post(
        "/usuarios/login",
        json={"correo": "camila@utb.edu.co", "password": "Password123"},
    )
    if login.status_code != 200:
        client.post(
            "/usuarios/registro",
            json={"nombre": "Camila", "correo": "camila@utb.edu.co", "password": "Password123"},
        )
        login = client.post(
            "/usuarios/login",
            json={"correo": "camila@utb.edu.co", "password": "Password123"},
        )
    assert login.status_code == 200
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Crear publicación
    crear = client.post(
        "/publicaciones/",
        json={
            "titulo": "Calculadora TI-Nspire CX",
            "descripcion": "Calculadora gráfica en perfecto estado con cargador.",
            "precio": 320000,
            "categoria": "Electrónica",
        },
        headers=headers,
    )
    assert crear.status_code == 201
    pub_id = crear.json()["id"]

    # 3. Listar mis publicaciones
    mis_pubs = client.get("/publicaciones/mis-publicaciones", headers=headers)
    assert mis_pubs.status_code == 200
    lista = mis_pubs.json()
    assert any(p["id"] == str(pub_id) for p in lista)

    # 4. Editar publicación
    edicion = client.put(
        f"/publicaciones/{pub_id}",
        json={
            "titulo": "Calculadora TI-Nspire CX II",
            "descripcion": "Calculadora gráfica versión II con estuche.",
            "precio": 350000,
            "categoria": "Electrónica",
        },
        headers=headers,
    )
    assert edicion.status_code == 200
    assert edicion.json()["titulo"] == "Calculadora TI-Nspire CX II"
    assert edicion.json()["precio"] == 350000

    # 5. Cambiar estado a 'vendida'
    estado_res = client.patch(
        f"/publicaciones/{pub_id}/estado?nuevo_estado=vendida",
        headers=headers,
    )
    assert estado_res.status_code == 200
    assert estado_res.json()["estado"] == "vendida"

    # 6. Cambiar estado a 'pausada'
    estado_pausada = client.patch(
        f"/publicaciones/{pub_id}/estado?nuevo_estado=pausada",
        headers=headers,
    )
    assert estado_pausada.status_code == 200
    assert estado_pausada.json()["estado"] == "pausada"

    # 7. Eliminar publicación
    eliminar = client.delete(f"/publicaciones/{pub_id}", headers=headers)
    assert eliminar.status_code == 200

    # 8. Verificar que ya no aparece en mis publicaciones
    mis_pubs_post = client.get("/publicaciones/mis-publicaciones", headers=headers)
    assert not any(p["id"] == str(pub_id) for p in mis_pubs_post.json())
