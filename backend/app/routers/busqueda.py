"""Endpoints de búsqueda y filtrado de publicaciones."""
from fastapi import APIRouter, Depends
from sqlalchemy import or_
from sqlalchemy.orm import Session

from typing_extensions import Annotated

from app.database import get_db
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion

router = APIRouter()


@router.get("/")
def buscar_publicaciones(
    db: Annotated[Session, Depends(get_db)],
    query: str = "",
    categoria: str = "",
):
    """RF-04: Buscar y filtrar servicios."""
    consulta = db.query(Publicacion)
    if query:
        consulta = consulta.filter(
            or_(
                Publicacion.titulo.ilike(f"%{query}%"),
                Publicacion.descripcion.ilike(f"%{query}%"),
            )
        )

    if categoria:
        consulta = consulta.join(Categoria, Publicacion.categoria_id == Categoria.id).filter(
            Categoria.nombre.ilike(f"%{categoria}%")
        )

    resultado = []
    for publicacion in consulta.all():
        categoria_obj = db.query(Categoria).filter(Categoria.id == publicacion.categoria_id).first()
        resultado.append(
            {
                "id": publicacion.id,
                "titulo": publicacion.titulo,
                "descripcion": publicacion.descripcion,
                "precio": publicacion.precio,
                "estado": publicacion.estado,
                "categoria": categoria_obj.nombre if categoria_obj else None,
            }
        )
    return resultado
