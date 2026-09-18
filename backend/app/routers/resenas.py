"""Endpoints para calificar a un oferente."""
from fastapi import APIRouter

router = APIRouter()


@router.post("/")
def crear_resena():
    """RF-06: Calificar oferente."""
    pass
