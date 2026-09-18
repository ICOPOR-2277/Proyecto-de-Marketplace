"""Modelo ORM de Resena (calificación de un oferente)."""
from sqlalchemy import Column, Integer, String, ForeignKey
from app.database import Base


class Resena(Base):
    __tablename__ = "resenas"

    id = Column(Integer, primary_key=True, index=True)
    puntuacion = Column(Integer, nullable=False)
    comentario = Column(String)
    autor_id = Column(Integer, ForeignKey("usuarios.id"))
    calificado_id = Column(Integer, ForeignKey("usuarios.id"))
