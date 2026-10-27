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


def _crear_publicacion(titulo: str, vendedor_correo: str = "vendedor_test@utb.edu.co") -> int:
    """Crea (o reutiliza) una publicación activa del vendedor de pruebas y retorna su id."""
    db = SessionLocal()
    try:
        vendedor = db.query(Usuario).filter(Usuario.correo == vendedor_correo).first()
        cat = db.query(Categoria).filter(Categoria.nombre == "TestCat").first()
        pub = db.query(Publicacion).filter(Publicacion.titulo == titulo).first()
        if not pub:
            pub = Publicacion(
                titulo=titulo,
                descripcion=f"Descripción de {titulo}",
                precio=30000.0,
                estado="activa",
                usuario_id=vendedor.id,
                categoria_id=cat.id,
            )
            db.add(pub)
            db.commit()
            db.refresh(pub)
        return pub.id
    finally:
        db.close()


def _login(correo: str) -> tuple[str, int]:
    res = client.post("/usuarios/login", json={"correo": correo, "password": "clave12345"})
    assert res.status_code == 200
    return res.json()["access_token"], res.json()["usuario"]["id"]


def test_chat_independiente_por_publicacion_mismo_vendedor():
    """Dos publicaciones del mismo vendedor generan hilos e historiales independientes."""
    token_comp, comprador_id = _login("comprador_test@utb.edu.co")
    token_vend, vendedor_id = _login("vendedor_test@utb.edu.co")
    h_comp = {"Authorization": f"Bearer {token_comp}"}
    h_vend = {"Authorization": f"Bearer {token_vend}"}

    pub_a = _crear_publicacion("Calculadora Hilo A")
    pub_b = _crear_publicacion("Mesa Hilo B")
    pub_nueva = _crear_publicacion("Lampara Sin Chat C")

    # Comprador escribe sobre la publicación A y luego sobre la B
    r1 = client.post(
        "/chat/mensajes",
        headers=h_comp,
        json={"destinatario_id": vendedor_id, "contenido": "Pregunta sobre A", "publicacion_id": pub_a},
    )
    assert r1.status_code == 201
    r2 = client.post(
        "/chat/mensajes",
        headers=h_comp,
        json={"destinatario_id": vendedor_id, "contenido": "Pregunta sobre B", "publicacion_id": pub_b},
    )
    assert r2.status_code == 201

    # Historial del hilo A contiene solo mensajes de A
    hilo_a = client.get(f"/chat/mensajes/{vendedor_id}", headers=h_comp, params={"publicacion_id": pub_a})
    assert hilo_a.status_code == 200
    msgs_a = hilo_a.json()
    assert len(msgs_a) >= 1
    assert all(m["publicacion_id"] == pub_a for m in msgs_a)
    assert any(m["contenido"] == "Pregunta sobre A" for m in msgs_a)
    assert not any(m["contenido"] == "Pregunta sobre B" for m in msgs_a)

    # Historial del hilo B contiene solo mensajes de B
    hilo_b = client.get(f"/chat/mensajes/{vendedor_id}", headers=h_comp, params={"publicacion_id": pub_b})
    msgs_b = hilo_b.json()
    assert all(m["publicacion_id"] == pub_b for m in msgs_b)
    assert any(m["contenido"] == "Pregunta sobre B" for m in msgs_b)
    assert not any(m["contenido"] == "Pregunta sobre A" for m in msgs_b)

    # Una publicación nueva del mismo vendedor sin mensajes inicia vacía
    hilo_nuevo = client.get(
        f"/chat/mensajes/{vendedor_id}", headers=h_comp, params={"publicacion_id": pub_nueva}
    )
    assert hilo_nuevo.status_code == 200
    assert hilo_nuevo.json() == []

    # La bandeja del comprador muestra dos hilos separados con el mismo vendedor
    convs = client.get("/chat/conversaciones", headers=h_comp).json()
    hilos_vendedor = [c for c in convs if c["otro_usuario_id"] == vendedor_id]
    pubs_en_bandeja = {c["publicacion_id"] for c in hilos_vendedor}
    assert pub_a in pubs_en_bandeja
    assert pub_b in pubs_en_bandeja
    conv_a = next(c for c in hilos_vendedor if c["publicacion_id"] == pub_a)
    conv_b = next(c for c in hilos_vendedor if c["publicacion_id"] == pub_b)
    assert conv_a["publicacion_titulo"] == "Calculadora Hilo A"
    assert conv_b["publicacion_titulo"] == "Mesa Hilo B"
    assert conv_a["ultimo_mensaje"] == "Pregunta sobre A"
    assert conv_b["ultimo_mensaje"] == "Pregunta sobre B"
    assert conv_a["precio"] == 30000.0
    assert conv_a["estado"] == "activa"
    assert pub_nueva not in pubs_en_bandeja

    # Para el vendedor cada hilo cuenta sus no leídos por separado
    convs_vend = client.get("/chat/conversaciones", headers=h_vend).json()
    v_a = next(c for c in convs_vend if c["otro_usuario_id"] == comprador_id and c["publicacion_id"] == pub_a)
    v_b = next(c for c in convs_vend if c["otro_usuario_id"] == comprador_id and c["publicacion_id"] == pub_b)
    assert v_a["mensajes_no_leidos"] >= 1
    assert v_b["mensajes_no_leidos"] >= 1

    # Leer solo el hilo A no marca como leído el hilo B
    client.get(f"/chat/mensajes/{comprador_id}", headers=h_vend, params={"publicacion_id": pub_a})
    convs_vend = client.get("/chat/conversaciones", headers=h_vend).json()
    v_a = next(c for c in convs_vend if c["otro_usuario_id"] == comprador_id and c["publicacion_id"] == pub_a)
    v_b = next(c for c in convs_vend if c["otro_usuario_id"] == comprador_id and c["publicacion_id"] == pub_b)
    assert v_a["mensajes_no_leidos"] == 0
    assert v_b["mensajes_no_leidos"] >= 1

    # Retrocompatibilidad: sin publicacion_id devuelve el historial completo
    completo = client.get(f"/chat/mensajes/{vendedor_id}", headers=h_comp).json()
    contenidos = {m["contenido"] for m in completo}
    assert {"Pregunta sobre A", "Pregunta sobre B"} <= contenidos


def test_chat_hilo_general_excluye_mensajes_de_publicaciones():
    """hilo_general=true devuelve solo mensajes sin publicación asociada."""
    token_comp, _ = _login("comprador_test@utb.edu.co")
    _, vendedor_id = _login("vendedor_test@utb.edu.co")
    h_comp = {"Authorization": f"Bearer {token_comp}"}
    pub_a = _crear_publicacion("Calculadora Hilo A")

    client.post(
        "/chat/mensajes",
        headers=h_comp,
        json={"destinatario_id": vendedor_id, "contenido": "Mensaje general sin pub"},
    )
    client.post(
        "/chat/mensajes",
        headers=h_comp,
        json={"destinatario_id": vendedor_id, "contenido": "Mensaje de A", "publicacion_id": pub_a},
    )

    general = client.get(
        f"/chat/mensajes/{vendedor_id}", headers=h_comp, params={"hilo_general": "true"}
    ).json()
    assert any(m["contenido"] == "Mensaje general sin pub" for m in general)
    assert all(m["publicacion_id"] is None for m in general)
