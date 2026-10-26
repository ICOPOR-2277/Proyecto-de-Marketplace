"""Endpoints para chat interactivo bidireccional entre comprador y vendedor."""
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
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
    """Lista todas las conversaciones activas del usuario autenticado."""
    # Obtener todos los mensajes donde participa el usuario actual
    mensajes = (
        db.query(Mensaje)
        .filter(
            or_(
                Mensaje.remitente_id == usuario_actual.id,
                Mensaje.destinatario_id == usuario_actual.id,
            )
        )
        .order_by(Mensaje.fecha_envio.asc())
        .all()
    )

    # Agrupar por el otro usuario
    conversaciones_map = {}
    for m in mensajes:
        otro_id = m.destinatario_id if m.remitente_id == usuario_actual.id else m.remitente_id
        if otro_id not in conversaciones_map:
            conversaciones_map[otro_id] = {
                "ultimo_mensaje": m.contenido,
                "fecha_ultimo_mensaje": m.fecha_envio,
                "no_leidos": 0,
                "publicacion_id": m.publicacion_id,
            }
        else:
            conversaciones_map[otro_id]["ultimo_mensaje"] = m.contenido
            conversaciones_map[otro_id]["fecha_ultimo_mensaje"] = m.fecha_envio
            if m.publicacion_id:
                conversaciones_map[otro_id]["publicacion_id"] = m.publicacion_id

        if m.destinatario_id == usuario_actual.id and not m.leido:
            conversaciones_map[otro_id]["no_leidos"] += 1

    resultados = []
    for otro_id, info in conversaciones_map.items():
        otro_usr = db.query(Usuario).filter(Usuario.id == otro_id).first()
        if not otro_usr:
            continue

        pub_titulo = None
        if info["publicacion_id"]:
            pub = db.query(Publicacion).filter(Publicacion.id == info["publicacion_id"]).first()
            if pub:
                pub_titulo = pub.titulo

        resultados.append(
            ConversacionOut(
                otro_usuario_id=otro_usr.id,
                otro_usuario_nombre=otro_usr.nombre,
                otro_usuario_correo=otro_usr.correo,
                ultimo_mensaje=info["ultimo_mensaje"],
                fecha_ultimo_mensaje=info["fecha_ultimo_mensaje"].isoformat(),
                mensajes_no_leidos=info["no_leidos"],
                publicacion_id=info["publicacion_id"],
                publicacion_titulo=pub_titulo,
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
):
    """Obtiene el historial completo de mensajes entre el usuario actual y el otro usuario."""
    otro_usr = db.query(Usuario).filter(Usuario.id == otro_usuario_id).first()
    if not otro_usr:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")

    mensajes = (
        db.query(Mensaje)
        .filter(
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
        .order_by(Mensaje.fecha_envio.asc())
        .all()
    )

    # Marcar como leídos los que recibió el usuario actual
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


