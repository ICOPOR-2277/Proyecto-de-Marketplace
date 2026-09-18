"""Modelo ORM de Usuario (y su rol Administrador)."""
from sqlalchemy import Column, Integer, String, Boolean
from app.database import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, nullable=False)
    correo = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    es_administrador = Column(Boolean, default=False)
