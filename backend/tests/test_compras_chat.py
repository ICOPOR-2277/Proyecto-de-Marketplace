"""Pruebas para los requerimientos de compras (bloqueo por moderador, login obligatorio) y chat interactivo."""
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
def setup_test_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    # Usuario Comprador
    comprador = db.query(Usuario).filter(Usuario.correo == "comprador_test@utb.edu.co").first()
    if not comprador:
        comprador = Usuario(
            nombre="Comprador Test",
            correo="comprador_test@utb.edu.co",
            password_hash=hash_password("clave12345"),
            es_administrador=False,
        )
        db.add(comprador)

    # Usuario Vendedor
    vendedor = db.query(Usuario).filter(Usuario.correo == "vendedor_test@utb.edu.co").first()
    if not vendedor:
        vendedor = Usuario(
            nombre="Vendedor Test",
            correo="vendedor_test@utb.edu.co",
            password_hash=hash_password("clave12345"),
            es_administrador=False,
        )
        db.add(vendedor)

    # Moderador
    moderador = db.query(Usuario).filter(Usuario.correo == "mod_test2@utb.edu.co").first()
    if not moderador:
        moderador = Usuario(
            nombre="Mod Test 2",
            correo="mod_test2@utb.edu.co",
            password_hash=hash_password("clave12345"),
            es_administrador=True,
        )
        db.add(moderador)

    db.commit()
    db.refresh(comprador)
    db.refresh(vendedor)

    # Categoría
    cat = db.query(Categoria).filter(Categoria.nombre == "TestCat").first()
    if not cat:
        cat = Categoria(nombre="TestCat")
        db.add(cat)
        db.commit()
        db.refresh(cat)

    # Publicación Activa
    pub_activa = db.query(Publicacion).filter(Publicacion.titulo == "Libro Activo Test").first()
    if not pub_activa:
        pub_activa = Publicacion(
            titulo="Libro Activo Test",
            descripcion="Descripción libro activo",
            precio=45000.0,
            estado="activa",
            usuario_id=vendedor.id,
            categoria_id=cat.id,
        )
        db.add(pub_activa)
    else:
        pub_activa.estado = "activa"

    # Publicación Bloqueada por Moderador
    pub_bloqueada = db.query(Publicacion).filter(Publicacion.titulo == "Articulo Bloqueado Test").first()
    if not pub_bloqueada:
        pub_bloqueada = Publicacion(
            titulo="Articulo Bloqueado Test",
            descripcion="Articulo no permitido",
            precio=12000.0,
            estado="bloqueada",
            usuario_id=vendedor.id,
            categoria_id=cat.id,
        )
        db.add(pub_bloqueada)

    db.commit()
    db.close()
    yield


def test_requerimiento_2_no_deja_comprar_sin_login():
    """Requerimiento 2: no te deje comprar los artículos cuando no estés logueado."""
    db = SessionLocal()
    pub = db.query(Publicacion).filter(Publicacion.titulo == "Libro Activo Test").first()
    pub_id = pub.id
    db.close()

    # Intentar comprar sin token de autenticación
    res = client.post(
        "/compras/",
        json={"items": [{"publicacion_id": pub_id, "cantidad": 1}]},
    )
    # Debe ser rechazado como no autorizado (401)
    assert res.status_code == 401


def test_requerimiento_1_no_deja_comprar_publicacion_bloqueada():
    """Requerimiento 1: cuando vayas a comprar si el moderador bloqueó una publicación no se debe comprar ese producto."""
    # Iniciar sesión como comprador legítimo
    login_res = client.post(
        "/usuarios/login",
        json={"correo": "comprador_test@utb.edu.co", "password": "clave12345"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]

    db = SessionLocal()
    pub_bloq = db.query(Publicacion).filter(Publicacion.titulo == "Articulo Bloqueado Test").first()
    pub_id = pub_bloq.id
    db.close()

    # Intentar comprar el producto bloqueado por el moderador
    res = client.post(
        "/compras/",
        headers={"Authorization": f"Bearer {token}"},
        json={"items": [{"publicacion_id": pub_id, "cantidad": 1}]},
    )

    # Debe rechazar con 400 Bad Request e indicar bloqueo por moderador
    assert res.status_code == 400
    assert "bloqueada por un moderador" in res.json()["detail"].lower()


def test_compra_exitosa_producto_activo():
    """Verifica que un usuario autenticado pueda comprar una publicación activa."""
    login_res = client.post(
        "/usuarios/login",
        json={"correo": "comprador_test@utb.edu.co", "password": "clave12345"},
    )
    token = login_res.json()["access_token"]

    db = SessionLocal()
    pub = db.query(Publicacion).filter(Publicacion.titulo == "Libro Activo Test").first()
    pub_id = pub.id
    db.close()

    res = client.post(
        "/compras/",
        headers={"Authorization": f"Bearer {token}"},
        json={"items": [{"publicacion_id": pub_id, "cantidad": 2}]},
    )

    assert res.status_code == 201
    compras = res.json()
    assert len(compras) == 1
    assert compras[0]["publicacion_id"] == pub_id
    assert compras[0]["cantidad"] == 2
    assert compras[0]["total"] == 90000.0


def test_requerimiento_3_chat_interactivo():
    """Requerimiento 3: Chat interactivo para poder contactarse con el vendedor y viceversa."""
    # 1. Login Comprador
    res_comp = client.post(
        "/usuarios/login",
        json={"correo": "comprador_test@utb.edu.co", "password": "clave12345"},
    )
    token_comp = res_comp.json()["access_token"]

    # 2. Login Vendedor
    res_vend = client.post(
        "/usuarios/login",
        json={"correo": "vendedor_test@utb.edu.co", "password": "clave12345"},
    )
    token_vend = res_vend.json()["access_token"]
    vendedor_id = res_vend.json()["usuario"]["id"]
    comprador_id = res_comp.json()["usuario"]["id"]

    # 3. Comprador envía mensaje al vendedor sobre un artículo
    envio = client.post(
        "/chat/mensajes",
        headers={"Authorization": f"Bearer {token_comp}"},
        json={
            "destinatario_id": vendedor_id,
            "contenido": "¿Hola, aún tienes disponible el libro para entrega en la biblioteca?",
        },
    )
    assert envio.status_code == 201
    assert envio.json()["es_mio"] is True

    # 4. Vendedor consulta sus conversaciones y ve el mensaje del comprador
    convs = client.get(
        "/chat/conversaciones",
        headers={"Authorization": f"Bearer {token_vend}"},
    )
    assert convs.status_code == 200
    lista_conv = convs.json()
    assert any(c["otro_usuario_id"] == comprador_id for c in lista_conv)

    # 5. Vendedor responde al comprador
    respuesta = client.post(
        "/chat/mensajes",
        headers={"Authorization": f"Bearer {token_vend}"},
        json={
            "destinatario_id": comprador_id,
            "contenido": "¡Hola! Sí, nos vemos a las 2pm en la entrada del edificio A.",
        },
    )
    assert respuesta.status_code == 201

    # 6. Comprador lee el hilo completo de la conversación
    hilo = client.get(
        f"/chat/mensajes/{vendedor_id}",
        headers={"Authorization": f"Bearer {token_comp}"},
    )
    assert hilo.status_code == 200
    mensajes = hilo.json()
    assert len(mensajes) >= 2
    # El último mensaje fue enviado por el vendedor
    assert mensajes[-1]["remitente_id"] == vendedor_id
    assert mensajes[-1]["es_mio"] is False
