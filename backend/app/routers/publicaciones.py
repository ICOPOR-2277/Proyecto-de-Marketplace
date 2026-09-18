"""Endpoints para publicar, editar y eliminar servicios."""
from fastapi import APIRouter

router = APIRouter()


@router.post("/")
def crear_publicacion():
    """RF-02: Publicar servicio."""
    pass


@router.put("/{publicacion_id}")
def editar_publicacion(publicacion_id: int):
    """RF-03: Editar publicación."""
    pass


@router.delete("/{publicacion_id}")
def eliminar_publicacion(publicacion_id: int):
    pass
