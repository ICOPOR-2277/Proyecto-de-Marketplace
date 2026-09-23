"""Endpoints para calificar a un oferente."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from typing_extensions import Annotated

from app.database import get_db
from app.models.resena import Resena
from app.models.usuario import Usuario
from app.routers.usuarios import get_current_user
from app.schemas import ResenaCreate

router = APIRouter()


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"description": "No se puede calificar a uno mismo."},
    },
)
def crear_resena(
    payload: ResenaCreate,
    db: Annotated[Session, Depends(get_db)],
    usuario_actual: Annotated[Usuario, Depends(get_current_user)],
):
    """RF-06: Calificar oferente."""
    if payload.calificado_id == usuario_actual.id:
        raise HTTPException(status_code=400, detail="No puedes calificarte a ti mismo.")

    resena = Resena(
        puntuacion=payload.puntuacion,
        comentario=payload.comentario,
        autor_id=usuario_actual.id,
        calificado_id=payload.calificado_id,
    )
    db.add(resena)
    db.commit()
    db.refresh(resena)

    return {
        "id": resena.id,
        "puntuacion": resena.puntuacion,
        "comentario": resena.comentario,
        "autor_id": resena.autor_id,
        "calificado_id": resena.calificado_id,
    }
