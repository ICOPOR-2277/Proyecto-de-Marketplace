"""Endpoints para moderación y administración del marketplace."""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing_extensions import Annotated

from app.database import get_db
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion
from app.models.usuario import Usuario
from app.routers.usuarios import get_current_user

router = APIRouter()


class ModeracionEstadoUpdate(BaseModel):
    estado: str  # "activa", "pausada", "eliminada", "bloqueada"


class ModeracionItem(BaseModel):
    id: int
    titulo: str
    descripcion: Optional[str] = None
    precio: Optional[float] = None
    estado: str
    categoria: str
    imagen_url: Optional[str] = None
    usuario_id: Optional[int] = None
    usuario_nombre: Optional[str] = None
    usuario_correo: Optional[str] = None


class StatsModeracion(BaseModel):
    total_publicaciones: int
    publicaciones_activas: int
    publicaciones_bloqueadas: int
    total_usuarios: int
    total_moderadores: int


def verificar_moderador(
    current_user: Annotated[Usuario, Depends(get_current_user)],
) -> Usuario:
    if not current_user.es_administrador:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido únicamente para moderadores / administradores.",
        )
    return current_user


@router.get("/stats", response_model=StatsModeracion)
def obtener_estadisticas_moderacion(
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[Usuario, Depends(verificar_moderador)],
):
    """Estadísticas globales para el Dashboard de moderación."""
    total_publicaciones = db.query(Publicacion).count()
    publicaciones_activas = db.query(Publicacion).filter(Publicacion.estado == "activa").count()
    publicaciones_bloqueadas = (
        db.query(Publicacion)
        .filter(Publicacion.estado.in_(["bloqueada", "pausada", "eliminada"]))
        .count()
    )
    total_usuarios = db.query(Usuario).count()
    total_moderadores = db.query(Usuario).filter(Usuario.es_administrador.is_(True)).count()

    return StatsModeracion(
        total_publicaciones=total_publicaciones,
        publicaciones_activas=publicaciones_activas,
        publicaciones_bloqueadas=publicaciones_bloqueadas,
        total_usuarios=total_usuarios,
        total_moderadores=total_moderadores,
    )


@router.get("/publicaciones", response_model=List[ModeracionItem])
def listar_publicaciones_moderador(
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[Usuario, Depends(verificar_moderador)],
    filtro_estado: Optional[str] = None,
):
    """Listar todas las publicaciones para revisión de moderación."""
    query = db.query(Publicacion)
    if filtro_estado:
        query = query.filter(Publicacion.estado == filtro_estado)

    items = query.order_by(Publicacion.id.desc()).all()
    resultado = []
    for p in items:
        cat = db.query(Categoria).filter(Categoria.id == p.categoria_id).first()
        usr = db.query(Usuario).filter(Usuario.id == p.usuario_id).first() if p.usuario_id else None
        resultado.append(
            ModeracionItem(
                id=p.id,
                titulo=p.titulo,
                descripcion=p.descripcion,
                precio=p.precio,
                estado=p.estado or "activa",
                categoria=cat.nombre if cat else "General",
                imagen_url=p.imagen_url,
                usuario_id=p.usuario_id,
                usuario_nombre=usr.nombre if usr else "Estudiante UTB",
                usuario_correo=usr.correo if usr else "utb@utb.edu.co",
            )
        )
    return resultado


@router.patch("/publicaciones/{publicacion_id}/estado")
def cambiar_estado_publicacion(
    publicacion_id: int,
    payload: ModeracionEstadoUpdate,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[Usuario, Depends(verificar_moderador)],
):
    """Cambiar estado de una publicación (activa, pausada, bloqueada, eliminada)."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada.")

    pub.estado = payload.estado
    db.commit()
    db.refresh(pub)
    return {"mensaje": f"Publicación {publicacion_id} actualizada a estado: {pub.estado}"}


@router.delete("/publicaciones/{publicacion_id}")
def eliminar_publicacion(
    publicacion_id: int,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[Usuario, Depends(verificar_moderador)],
):
    """Eliminar definitivamente una publicación no permitida."""
    pub = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada.")

    db.delete(pub)
    db.commit()
    return {"mensaje": f"Publicación {publicacion_id} eliminada correctamente."}
