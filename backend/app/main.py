"""Punto de entrada de la API del marketplace de servicios."""
from fastapi import FastAPI
from app.routers import usuarios, publicaciones, busqueda, resenas

app = FastAPI(title="Marketplace de Servicios UTB")

app.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
app.include_router(publicaciones.router, prefix="/publicaciones", tags=["Publicaciones"])
app.include_router(busqueda.router, prefix="/busqueda", tags=["Búsqueda"])
app.include_router(resenas.router, prefix="/resenas", tags=["Reseñas"])


@app.get("/")
def root():
    return {"mensaje": "API del marketplace de servicios entre estudiantes"}
