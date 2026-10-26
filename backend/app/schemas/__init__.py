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


class UsuarioInfo(BaseModel):
    id: int
    nombre: str
    correo: str
    es_administrador: bool


class TokenConUsuario(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioInfo


class PublicacionCreate(BaseModel):
    titulo: str = Field(..., min_length=3, max_length=200)
    descripcion: str = Field(..., min_length=10, max_length=2000)
    precio: float = Field(..., ge=0)
    categoria: str = Field(..., min_length=2, max_length=100)


class PublicacionUpdate(BaseModel):
    titulo: str | None = None
    descripcion: str | None = None
    precio: float | None = None
    categoria: str | None = None
    estado: str | None = None


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
    usuario_id: int | None = None
    imagen_url: str | None = None


class ListingCreate(BaseModel):
    category: str
    title: str
    price: str
    imageUrl: str | None = None


class ListingOut(BaseModel):
    id: str
    category: str
    title: str
    price: str
    imageUrl: str | None = None
    estado: str = "activa"
    usuario_id: int | None = None
    vendedor_nombre: str | None = None


class ItemCompraRequest(BaseModel):
    publicacion_id: int
    cantidad: int = Field(default=1, ge=1)


class CompraRequest(BaseModel):
    items: list[ItemCompraRequest]


class CompraOut(BaseModel):
    id: int
    publicacion_id: int
    titulo: str
    cantidad: int
    precio_unitario: float
    total: float
    fecha_compra: str
    estado: str
    vendedor_nombre: str | None = None


class MensajeCreate(BaseModel):
    destinatario_id: int
    contenido: str = Field(..., min_length=1, max_length=2000)
    publicacion_id: int | None = None


class MensajeOut(BaseModel):
    id: int
    remitente_id: int
    remitente_nombre: str
    destinatario_id: int
    contenido: str
    fecha_envio: str
    leido: bool
    publicacion_id: int | None = None
    es_mio: bool = False


class ConversacionOut(BaseModel):
    otro_usuario_id: int
    otro_usuario_nombre: str
    otro_usuario_correo: str
    ultimo_mensaje: str
    fecha_ultimo_mensaje: str
    mensajes_no_leidos: int
    publicacion_id: int | None = None
    publicacion_titulo: str | None = None

