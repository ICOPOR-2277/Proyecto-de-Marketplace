"""Endpoints de registro, autenticación y perfil de usuario."""
from fastapi import APIRouter

router = APIRouter()


@router.post("/registro")
def registrar_usuario():
    """RF-01: Registro con correo institucional."""
    pass


@router.post("/login")
def iniciar_sesion():
    pass
