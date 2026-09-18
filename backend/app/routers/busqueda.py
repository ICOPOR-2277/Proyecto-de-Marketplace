"""Endpoints de búsqueda y filtrado de publicaciones."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/")
def buscar_publicaciones(query: str = "", categoria: str = ""):
    """RF-04: Buscar y filtrar servicios."""
    pass
