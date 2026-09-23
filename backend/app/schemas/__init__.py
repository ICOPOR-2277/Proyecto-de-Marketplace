"""Schemas Pydantic para validación de requests y responses de la API."""

from pydantic import BaseModel, Field


class UsuarioCreate(BaseModel):
    nombre: str = Field(..., min_length=2, max_length=120)
    correo: str
    password: str = Field(..., min_length=8, max_length=128)


class UsuarioLogin(BaseModel):
    correo: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class PublicacionCreate(BaseModel):
    titulo: str = Field(..., min_length=3, max_length=200)
    descripcion: str = Field(..., min_length=10, max_length=2000)
    precio: float = Field(..., ge=0)
    categoria: str = Field(..., min_length=2, max_length=100)


class ResenaCreate(BaseModel):
    puntuacion: int = Field(..., ge=1, le=5)
    comentario: str = Field(..., min_length=5, max_length=500)
    calificado_id: int


class PublicacionOut(BaseModel):
    id: int
    titulo: str
    descripcion: str | None = None
    precio: float | None = None
    estado: str
    categoria: str
    usuario_id: int
