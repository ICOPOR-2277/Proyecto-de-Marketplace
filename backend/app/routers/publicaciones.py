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


@router.put("/{publicacion_id}")
def editar_publicacion(publicacion_id: int):
    """RF-03: Editar publicación."""
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="Edición aún no implementada")


@router.delete("/{publicacion_id}")
def eliminar_publicacion(publicacion_id: int):
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="Eliminación aún no implementada")
