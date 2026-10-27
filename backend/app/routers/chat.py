"""Endpoints para chat interactivo bidireccional entre comprador y vendedor."""
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, and_
from sqlalchemy.orm import Session
from typing_extensions import Annotated

from app.database import get_db
from app.models.mensaje import Mensaje
from app.models.publicacion import Publicacion
from app.models.usuario import Usuario
from app.routers.usuarios import get_current_user
from app.schemas import ConversacionOut, MensajeCreate, MensajeOut

router = APIRouter()


@router.get("/vendedor-publicacion/{publicacion_id}")
def obtener_vendedor_publicacion(
    publicacion_id: int,
    db: Annotated[Session, Depends(get_db)],
):
    """Retorna información del vendedor de una publicación para iniciar un chat."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada.")

    vendedor = None
    if pub.usuario_id:
        vendedor = db.query(Usuario).filter(Usuario.id == pub.usuario_id).first()

    # Si no tiene vendedor asignado, asignar al moderador o primer usuario real institucional
    if not vendedor:
        vendedor = (
            db.query(Usuario).filter(Usuario.correo == "moderador@utb.edu.co").first()
            or db.query(Usuario).first()
        )
        if vendedor:
            pub.usuario_id = vendedor.id
            db.commit()

    if not vendedor:
        raise HTTPException(status_code=404, detail="Vendedor no disponible.")

    return {
        "vendedor_id": vendedor.id,
        "vendedor_nombre": vendedor.nombre,
        "vendedor_correo": vendedor.correo,
        "publicacion_id": pub.id,
        "publicacion_titulo": pub.titulo,
        "precio": pub.precio,
        "imagen_url": pub.imagen_url,
        "estado": pub.estado or "activa",
    }


@router.post("/mensajes", response_model=MensajeOut, status_code=status.HTTP_201_CREATED)
def enviar_mensaje(
    payload: MensajeCreate,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """Envía un mensaje a otro usuario (vendedor o comprador)."""
    destinatario = db.query(Usuario).filter(Usuario.id == payload.destinatario_id).first()
    if not destinatario:
        raise HTTPException(status_code=404, detail="El usuario destinatario no existe.")

    texto = payload.contenido.strip()
    if not texto:
        raise HTTPException(status_code=400, detail="El mensaje no puede estar vacío.")

    nuevo_mensaje = Mensaje(
        remitente_id=usuario_actual.id,
        destinatario_id=payload.destinatario_id,
        publicacion_id=payload.publicacion_id,
        contenido=texto,
        fecha_envio=datetime.utcnow(),
        leido=False,
    )
    db.add(nuevo_mensaje)
    db.commit()
    db.refresh(nuevo_mensaje)

    return MensajeOut(
        id=nuevo_mensaje.id,
        remitente_id=nuevo_mensaje.remitente_id,
        remitente_nombre=usuario_actual.nombre,
        destinatario_id=nuevo_mensaje.destinatario_id,
        contenido=nuevo_mensaje.contenido,
        fecha_envio=nuevo_mensaje.fecha_envio.isoformat(),
        leido=nuevo_mensaje.leido,
        publicacion_id=nuevo_mensaje.publicacion_id,
        es_mio=True,
    )


@router.get("/conversaciones", response_model=List[ConversacionOut])
def listar_conversaciones(
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """Lista las conversaciones del usuario autenticado.

    Cada conversación es un hilo independiente identificado por la clave
    compuesta ``(otro_usuario_id, publicacion_id)``: hablar con el mismo
    vendedor sobre dos publicaciones distintas produce dos hilos separados.
    """
    # Obtener todos los mensajes donde participa el usuario actual
    mensajes = (
        db.query(Mensaje)
        .filter(
            or_(
                Mensaje.remitente_id == usuario_actual.id,
                Mensaje.destinatario_id == usuario_actual.id,
            )
        )
        .order_by(Mensaje.fecha_envio.asc(), Mensaje.id.asc())
        .all()
    )

    # Agrupar por (otro usuario, publicación)
    conversaciones_map: dict = {}
    for m in mensajes:
        otro_id = m.destinatario_id if m.remitente_id == usuario_actual.id else m.remitente_id
        clave = (otro_id, m.publicacion_id)
        info = conversaciones_map.get(clave)
        if info is None:
            info = {
                "otro_id": otro_id,
                "publicacion_id": m.publicacion_id,
                "no_leidos": 0,
            }
            conversaciones_map[clave] = info

        # Los mensajes vienen ordenados ascendentemente: el último gana
        info["ultimo_mensaje"] = m.contenido
        info["fecha_ultimo_mensaje"] = m.fecha_envio
        info["ultimo_mensaje_id"] = m.id

        if m.destinatario_id == usuario_actual.id and not m.leido:
            info["no_leidos"] += 1

    usuarios_cache: dict = {}
    publicaciones_cache: dict = {}
    resultados = []
    for info in conversaciones_map.values():
        otro_id = info["otro_id"]
        if otro_id not in usuarios_cache:
            usuarios_cache[otro_id] = db.query(Usuario).filter(Usuario.id == otro_id).first()
        otro_usr = usuarios_cache[otro_id]
        if not otro_usr:
            continue

        pub = None
        pub_id = info["publicacion_id"]
        if pub_id:
            if pub_id not in publicaciones_cache:
                publicaciones_cache[pub_id] = (
                    db.query(Publicacion).filter(Publicacion.id == pub_id).first()
                )
            pub = publicaciones_cache[pub_id]

        fecha = info["fecha_ultimo_mensaje"]
        resultados.append(
            ConversacionOut(
                otro_usuario_id=otro_usr.id,
                otro_usuario_nombre=otro_usr.nombre,
                otro_usuario_correo=otro_usr.correo,
                ultimo_mensaje=info["ultimo_mensaje"],
                fecha_ultimo_mensaje=fecha.isoformat() if fecha else "",
                mensajes_no_leidos=info["no_leidos"],
                publicacion_id=pub_id,
                publicacion_titulo=pub.titulo if pub else None,
                precio=pub.precio if pub else None,
                imagen_url=pub.imagen_url if pub else None,
                estado=(pub.estado or "activa") if pub else None,
                ultimo_mensaje_id=info["ultimo_mensaje_id"],
            )
        )

    # Ordenar por fecha del último mensaje descendente
    resultados.sort(key=lambda c: c.fecha_ultimo_mensaje, reverse=True)
    return resultados


@router.get("/mensajes/{otro_usuario_id}", response_model=List[MensajeOut])
def obtener_mensajes_conversacion(
    otro_usuario_id: int,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
    publicacion_id: Optional[int] = Query(
        None,
        description="Si se envía, devuelve solo el hilo de esa publicación.",
    ),
    hilo_general: bool = Query(
        False,
        description="Si es true (y no se envía publicacion_id), devuelve solo los "
        "mensajes que no están asociados a ninguna publicación.",
    ),
):
    """Obtiene el historial de mensajes entre el usuario actual y el otro usuario.

    - ``publicacion_id`` presente: hilo estricto de esa publicación (puede ser ``[]``).
    - ``hilo_general=true``: solo mensajes sin publicación asociada.
    - Sin parámetros: historial completo (retrocompatibilidad).
    """
    otro_usr = db.query(Usuario).filter(Usuario.id == otro_usuario_id).first()
    if not otro_usr:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")

    consulta = db.query(Mensaje).filter(
        or_(
            and_(
                Mensaje.remitente_id == usuario_actual.id,
                Mensaje.destinatario_id == otro_usuario_id,
            ),
            and_(
                Mensaje.remitente_id == otro_usuario_id,
                Mensaje.destinatario_id == usuario_actual.id,
            ),
        )
    )
    if publicacion_id is not None:
        consulta = consulta.filter(Mensaje.publicacion_id == publicacion_id)
    elif hilo_general:
        consulta = consulta.filter(Mensaje.publicacion_id.is_(None))

    mensajes = consulta.order_by(Mensaje.fecha_envio.asc(), Mensaje.id.asc()).all()

    # Marcar como leídos los que recibió el usuario actual (solo de este hilo)
    hay_cambios = False
    for m in mensajes:
        if m.destinatario_id == usuario_actual.id and not m.leido:
            m.leido = True
            hay_cambios = True

    if hay_cambios:
        db.commit()

    resultados = []
    for m in mensajes:
        nombre_remitente = (
            usuario_actual.nombre if m.remitente_id == usuario_actual.id else otro_usr.nombre
        )
        resultados.append(
            MensajeOut(
                id=m.id,
                remitente_id=m.remitente_id,
                remitente_nombre=nombre_remitente,
                destinatario_id=m.destinatario_id,
                contenido=m.contenido,
                fecha_envio=m.fecha_envio.isoformat(),
                leido=m.leido,
                publicacion_id=m.publicacion_id,
                es_mio=(m.remitente_id == usuario_actual.id),
            )
        )

    return resultados



