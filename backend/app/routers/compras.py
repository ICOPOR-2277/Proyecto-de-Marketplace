"""Endpoints para compras y validaciones de publicaciones activas/bloqueadas."""
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing_extensions import Annotated

from app.database import get_db
from app.models.compra import Compra
from app.models.mensaje import Mensaje
from app.models.publicacion import Publicacion
from app.models.usuario import Usuario
from app.routers.usuarios import get_current_user
from app.schemas import CompraOut, CompraRequest

router = APIRouter()


@router.get("/validar/{publicacion_id}")
def validar_publicacion_para_compra(
    publicacion_id: int,
    db: Annotated[Session, Depends(get_db)],
):
    """Verifica si una publicación específica es elegible para compra."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada.")

    if pub.estado == "bloqueada":
        return {
            "se_puede_comprar": False,
            "motivo": f"El producto '{pub.titulo}' fue bloqueado por un moderador y no puede ser comprado.",
            "estado": "bloqueada",
        }

    if pub.estado == "vendida":
        return {
            "se_puede_comprar": False,
            "motivo": f"El producto '{pub.titulo}' ya fue adquirido por otro estudiante y no está disponible.",
            "estado": "vendida",
        }

    if pub.estado != "activa":
        return {
            "se_puede_comprar": False,
            "motivo": f"El producto '{pub.titulo}' se encuentra en estado '{pub.estado}' y no está disponible para compra.",
            "estado": pub.estado,
        }

    return {
        "se_puede_comprar": True,
        "motivo": "Publicación activa y disponible.",
        "estado": pub.estado,
    }


@router.post("/", response_model=List[CompraOut], status_code=status.HTTP_201_CREATED)
def realizar_compra(
    payload: CompraRequest,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """RF: Realizar compra validando autenticación y restricción de publicaciones bloqueadas."""
    if not payload.items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El carrito no contiene artículos para comprar.",
        )

    # 1. Validación estricta previa de todos los artículos
    publicaciones_map = {}
    for item in payload.items:
        pub = db.query(Publicacion).filter(Publicacion.id == item.publicacion_id).first()
        if not pub:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"La publicación #{item.publicacion_id} no existe en el sistema.",
            )

        # Regla 1: Si el moderador bloqueó la publicación, no se debe comprar ese producto
        if pub.estado == "bloqueada":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No se puede comprar '{pub.titulo}' porque ha sido bloqueada por un moderador.",
            )

        if pub.estado == "vendida":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No se puede comprar '{pub.titulo}' porque ya fue adquirido por otro estudiante.",
            )

        if pub.estado != "activa":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No se puede comprar '{pub.titulo}' porque no está activa (estado actual: {pub.estado}).",
            )

        publicaciones_map[item.publicacion_id] = pub

    # 2. Registrar compras
    compras_creadas = []
    for item in payload.items:
        pub = publicaciones_map[item.publicacion_id]
        precio_unitario = float(pub.precio or 0.0)
        total = precio_unitario * item.cantidad

        compra = Compra(
            comprador_id=usuario_actual.id,
            publicacion_id=pub.id,
            cantidad=item.cantidad,
            precio_unitario=precio_unitario,
            total=total,
            fecha_compra=datetime.utcnow(),
            estado="completada",
        )
        db.add(compra)
        # Marcar la publicación como vendida para evitar compras duplicadas
        pub.estado = "vendida"
        db.commit()
        db.refresh(compra)

        # Buscar vendedor para enlazar nombre y generar mensaje en chat interactivo
        vendedor = db.query(Usuario).filter(Usuario.id == pub.usuario_id).first() if pub.usuario_id else None
        vendedor_nombre = vendedor.nombre if vendedor else "Vendedor UTB"

        # Si el vendedor es otro usuario, generar mensaje automático en el chat para iniciar contacto
        if vendedor and vendedor.id != usuario_actual.id:
            mensaje_chat = Mensaje(
                remitente_id=usuario_actual.id,
                destinatario_id=vendedor.id,
                publicacion_id=pub.id,
                contenido=(
                    f"¡Hola {vendedor.nombre}! Acabo de solicitar la compra de tu artículo '{pub.titulo}' "
                    f"por un total de ${int(total):,} COP (Cantidad: {item.cantidad}). "
                    f"¿En qué parte del campus Ternera podemos encontrarnos para la entrega?"
                ),
                fecha_envio=datetime.utcnow(),
                leido=False,
            )
            db.add(mensaje_chat)
            db.commit()

        compras_creadas.append(
            CompraOut(
                id=compra.id,
                publicacion_id=pub.id,
                titulo=pub.titulo,
                cantidad=compra.cantidad,
                precio_unitario=compra.precio_unitario,
                total=compra.total,
                fecha_compra=compra.fecha_compra.isoformat(),
                estado=compra.estado,
                vendedor_nombre=vendedor_nombre,
            )
        )

    return compras_creadas


@router.get("/mis-compras", response_model=List[CompraOut])
def obtener_mis_compras(
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """Obtiene el historial de compras del usuario autenticado."""
    compras = (
        db.query(Compra)
        .filter(Compra.comprador_id == usuario_actual.id)
        .order_by(Compra.id.desc())
        .all()
    )

    resultados = []
    for c in compras:
        pub = db.query(Publicacion).filter(Publicacion.id == c.publicacion_id).first()
        vendedor = (
            db.query(Usuario).filter(Usuario.id == pub.usuario_id).first()
            if (pub and pub.usuario_id)
            else None
        )
        resultados.append(
            CompraOut(
                id=c.id,
                publicacion_id=c.publicacion_id,
                titulo=pub.titulo if pub else "Artículo no disponible",
                cantidad=c.cantidad,
                precio_unitario=c.precio_unitario,
                total=c.total,
                fecha_compra=c.fecha_compra.isoformat() if c.fecha_compra else "",
                estado=c.estado,
                vendedor_nombre=vendedor.nombre if vendedor else "Compañero UTB",
            )
        )
    return resultados
