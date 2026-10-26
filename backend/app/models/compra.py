"""Modelo ORM de Compra / Transacción entre estudiantes."""
from datetime import datetime
from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from app.database import Base


class Compra(Base):
    __tablename__ = "compras"

    id = Column(Integer, primary_key=True, index=True)
    comprador_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    publicacion_id = Column(Integer, ForeignKey("publicaciones.id"), nullable=False)
    cantidad = Column(Integer, default=1)
    precio_unitario = Column(Float, nullable=False)
    total = Column(Float, nullable=False)
    fecha_compra = Column(DateTime, default=datetime.utcnow)
    estado = Column(String, default="completada")
