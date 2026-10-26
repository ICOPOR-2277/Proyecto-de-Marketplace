"""Pruebas del router de listings para el frontend."""
import io
from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion

client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)


def test_upload_image():
    file_bytes = b"fake-image-bytes-content"
    response = client.post(
        "/listings/upload-image",
        files={"file": ("test.png", io.BytesIO(file_bytes), "image/png")},
    )
    assert response.status_code == 201
    data = response.json()
    assert "url" in data
    assert "/uploads/" in data["url"]

    # Verificar que el archivo estático se puede obtener
    path_url = data["url"].split("http://testserver")[-1]
    static_resp = client.get(path_url)
    assert static_resp.status_code == 200
    assert static_resp.content == file_bytes

    # Limpieza del archivo estático generado en la prueba
    import os
    from app.routers.listings import UPLOADS_DIR
    filename = data["url"].split("/uploads/")[-1]
    test_file_path = os.path.join(UPLOADS_DIR, filename)
    if os.path.exists(test_file_path):
        os.remove(test_file_path)


def test_crear_y_obtener_listings():
    # 1. Crear listing
    payload = {
        "category": "Libros y Apuntes",
        "title": "Cálculo James Stewart 8va Edición",
        "price": "$ 45.000",
        "imageUrl": "http://testserver/uploads/libro.jpg",
    }
    create_resp = client.post("/listings/", json=payload)
    assert create_resp.status_code == 201
    created_data = create_resp.json()
    assert created_data["title"] == payload["title"]
    assert created_data["category"] == payload["category"]
    assert created_data["imageUrl"] == payload["imageUrl"]

    # 2. Consultar listings
    get_resp = client.get("/listings/")
    assert get_resp.status_code == 200
    listings = get_resp.json()
    assert any(item["title"] == payload["title"] for item in listings)

    # 3. Filtrar por categoría
    cat_resp = client.get("/listings/?category=Libros")
    assert cat_resp.status_code == 200
    assert any(item["title"] == payload["title"] for item in cat_resp.json())

    # 4. Filtrar por otra categoría que no tiene items
    empty_resp = client.get("/listings/?category=Transporte")
    assert empty_resp.status_code == 200
    assert len(empty_resp.json()) == 0
