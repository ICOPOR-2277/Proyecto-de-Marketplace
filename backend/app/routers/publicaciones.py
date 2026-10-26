"""Endpoints para publicar, editar y eliminar servicios."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from typing_extensions import Annotated

from app.database import get_db
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion
from app.models.usuario import Usuario
from app.routers.usuarios import get_current_user
from app.schemas import PublicacionCreate

router = APIRouter()


@router.post("/", status_code=status.HTTP_201_CREATED)
def crear_publicacion(
    payload: PublicacionCreate,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """RF-02: Publicar servicio."""
    categoria = db.query(Categoria).filter(Categoria.nombre.ilike(payload.categoria)).first()
    if not categoria:
        categoria = Categoria(nombre=payload.categoria.strip())
        db.add(categoria)
        db.commit()
        db.refresh(categoria)

    publicacion = Publicacion(
        titulo=payload.titulo,
        descripcion=payload.descripcion,
        precio=payload.precio,
        usuario_id=usuario_actual.id,
        categoria_id=categoria.id,
    )
    db.add(publicacion)
    db.commit()
    db.refresh(publicacion)

    return {
        "id": publicacion.id,
        "titulo": publicacion.titulo,
        "descripcion": publicacion.descripcion,
        "precio": publicacion.precio,
        "estado": publicacion.estado,
        "categoria": categoria.nombre,
        "usuario_id": publicacion.usuario_id,
    }


@router.get("/mis-publicaciones")
def listar_mis_publicaciones(
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """Lista todas las publicaciones creadas por el usuario autenticado."""
    publicaciones = (
        db.query(Publicacion)
        .filter(Publicacion.usuario_id == usuario_actual.id, Publicacion.estado != "eliminada")
        .order_by(Publicacion.id.desc())
        .all()
    )

    resultados = []
    for pub in publicaciones:
        cat = db.query(Categoria).filter(Categoria.id == pub.categoria_id).first()
        cat_nombre = cat.nombre if cat else "General"
        precio_str = f"${int(pub.precio):,}".replace(",", ".") if pub.precio is not None else "$0"
        resultados.append({
            "id": str(pub.id),
            "titulo": pub.titulo,
            "title": pub.titulo,
            "descripcion": pub.descripcion,
            "precio": pub.precio,
            "price": precio_str,
            "categoria": cat_nombre,
            "category": cat_nombre,
            "estado": pub.estado or "activa",
            "imageUrl": pub.imagen_url,
            "imagen_url": pub.imagen_url,
            "usuario_id": pub.usuario_id,
            "vendedor_nombre": usuario_actual.nombre,
        })
    return resultados


@router.put("/{publicacion_id}")
def editar_publicacion(
    publicacion_id: int,
    payload: PublicacionCreate,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """RF-03: Editar publicación propia."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub or pub.estado == "eliminada":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Publicación no encontrada.")

    # Validar que el usuario sea el autor o moderador/administrador
    if pub.usuario_id != usuario_actual.id and not usuario_actual.es_administrador:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para editar esta publicación.",
        )

    # Actualizar o crear categoría si cambió
    categoria = db.query(Categoria).filter(Categoria.nombre.ilike(payload.categoria)).first()
    if not categoria:
        categoria = Categoria(nombre=payload.categoria.strip())
        db.add(categoria)
        db.commit()
        db.refresh(categoria)

    pub.titulo = payload.titulo.strip()
    pub.descripcion = payload.descripcion.strip()
    pub.precio = payload.precio
    pub.categoria_id = categoria.id
    db.commit()
    db.refresh(pub)

    return {
        "id": pub.id,
        "titulo": pub.titulo,
        "descripcion": pub.descripcion,
        "precio": pub.precio,
        "estado": pub.estado,
        "categoria": categoria.nombre,
        "usuario_id": pub.usuario_id,
    }


@router.patch("/{publicacion_id}/estado")
def cambiar_estado_publicacion(
    publicacion_id: int,
    nuevo_estado: str,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """Permite al vendedor marcar su producto como 'vendida', 'pausada' o 'activa'."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub or pub.estado == "eliminada":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Publicación no encontrada.")

    if pub.usuario_id != usuario_actual.id and not usuario_actual.es_administrador:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para modificar el estado de esta publicación.",
        )

    estados_permitidos = ["activa", "pausada", "vendida"]
    if nuevo_estado.lower() not in estados_permitidos:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Estado inválido. Opciones permitidas: {', '.join(estados_permitidos)}",
        )

    pub.estado = nuevo_estado.lower()
    db.commit()
    db.refresh(pub)

    return {
        "id": pub.id,
        "titulo": pub.titulo,
        "estado": pub.estado,
        "mensaje": f"Publicación actualizada a estado '{pub.estado}'.",
    }


@router.delete("/{publicacion_id}")
def eliminar_publicacion(
    publicacion_id: int,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """Elimina la publicación del usuario (marcado como eliminada)."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub or pub.estado == "eliminada":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Publicación no encontrada.")

    if pub.usuario_id != usuario_actual.id and not usuario_actual.es_administrador:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para eliminar esta publicación.",
        )

    pub.estado = "eliminada"
    db.commit()

    return {"mensaje": f"Publicación #{publicacion_id} eliminada correctamente."}
