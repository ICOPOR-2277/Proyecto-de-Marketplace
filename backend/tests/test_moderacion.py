"""Pruebas para el router de moderación y control de contenido."""
import pytest
from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion
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


def _token_moderador() -> str:
    login_res = client.post(
        "/usuarios/login",
        json={"correo": "moderador_test@utb.edu.co", "password": "moderador123"},
    )
    assert login_res.status_code == 200
    return login_res.json()["access_token"]


def _crear_publicacion_moderacion(titulo: str, estado: str = "activa") -> int:
    db = SessionLocal()
    try:
        mod = db.query(Usuario).filter(Usuario.correo == "moderador_test@utb.edu.co").first()
        cat = db.query(Categoria).filter(Categoria.nombre == "ModCat").first()
        if not cat:
            cat = Categoria(nombre="ModCat")
            db.add(cat)
            db.commit()
            db.refresh(cat)
        pub = Publicacion(
            titulo=titulo,
            descripcion=f"Descripción de {titulo}",
            precio=10000.0,
            estado=estado,
            usuario_id=mod.id,
            categoria_id=cat.id,
        )
        db.add(pub)
        db.commit()
        db.refresh(pub)
        return pub.id
    finally:
        db.close()


def test_publicacion_eliminada_por_moderador_no_aparece_en_listings():
    """Al eliminar una publicación desde moderación desaparece de /listings/."""
    token = _token_moderador()
    headers = {"Authorization": f"Bearer {token}"}
    pub_id = _crear_publicacion_moderacion("Articulo a eliminar por moderador")

    antes = client.get("/listings/")
    assert antes.status_code == 200
    assert str(pub_id) in {item["id"] for item in antes.json()}

    res = client.delete(f"/moderacion/publicaciones/{pub_id}", headers=headers)
    assert res.status_code == 200

    despues = client.get("/listings/")
    assert despues.status_code == 200
    assert str(pub_id) not in {item["id"] for item in despues.json()}

    lista_mod = client.get("/moderacion/publicaciones", headers=headers).json()
    assert pub_id not in {item["id"] for item in lista_mod}


def test_publicacion_con_estado_eliminada_no_se_lista_por_defecto():
    """Las publicaciones 'eliminada' solo aparecen si se filtra explícitamente ese estado."""
    token = _token_moderador()
    headers = {"Authorization": f"Bearer {token}"}
    pub_id = _crear_publicacion_moderacion("Articulo borrado logico", estado="activa")

    res = client.patch(
        f"/moderacion/publicaciones/{pub_id}/estado",
        headers=headers,
        json={"estado": "eliminada"},
    )
    assert res.status_code == 200

    assert str(pub_id) not in {item["id"] for item in client.get("/listings/").json()}

    por_defecto = client.get("/moderacion/publicaciones", headers=headers).json()
    assert pub_id not in {item["id"] for item in por_defecto}
    assert all(item["estado"] != "eliminada" for item in por_defecto)

    filtradas = client.get(
        "/moderacion/publicaciones", headers=headers, params={"filtro_estado": "eliminada"}
    ).json()
    assert pub_id in {item["id"] for item in filtradas}
