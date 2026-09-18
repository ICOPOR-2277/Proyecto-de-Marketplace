"""Modelo ORM de Publicacion (servicio ofrecido por un usuario)."""
from sqlalchemy import Column, Integer, String, Float, ForeignKey
from app.database import Base


class Publicacion(Base):
    __tablename__ = "publicaciones"

    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String, nullable=False)
    descripcion = Column(String)
    precio = Column(Float)
    estado = Column(String, default="activa")
    usuario_id = Column(Integer, ForeignKey("usuarios.id"))
    categoria_id = Column(Integer, ForeignKey("categorias.id"))
