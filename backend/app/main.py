"""Punto de entrada de la API del marketplace de servicios."""
from fastapi import FastAPI

from app.database import Base, engine
from app.routers import busqueda, publicaciones, resenas, usuarios

app = FastAPI(title="Marketplace de Servicios UTB")


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)


app.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
app.include_router(publicaciones.router, prefix="/publicaciones", tags=["Publicaciones"])
app.include_router(busqueda.router, prefix="/busqueda", tags=["Búsqueda"])
app.include_router(resenas.router, prefix="/resenas", tags=["Reseñas"])


@app.get("/")
def root():
    return {"mensaje": "API del marketplace de servicios entre estudiantes"}
