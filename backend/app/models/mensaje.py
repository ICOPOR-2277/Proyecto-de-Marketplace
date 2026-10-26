"""Modelo ORM de Mensaje de Chat entre comprador y vendedor."""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from app.database import Base


class Mensaje(Base):
    __tablename__ = "mensajes"

    id = Column(Integer, primary_key=True, index=True)
    remitente_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    destinatario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    publicacion_id = Column(Integer, ForeignKey("publicaciones.id"), nullable=True)
    contenido = Column(Text, nullable=False)
    fecha_envio = Column(DateTime, default=datetime.utcnow)
    leido = Column(Boolean, default=False)
