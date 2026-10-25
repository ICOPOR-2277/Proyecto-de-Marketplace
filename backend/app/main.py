"""Punto de entrada de la API del marketplace de servicios."""
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.database import Base, engine
from app.routers import busqueda, listings, moderacion, publicaciones, resenas, usuarios

app = FastAPI(title="Marketplace de Servicios UTB")

# Servir archivos estáticos subidos
uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")
os.makedirs(uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)


app.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
app.include_router(publicaciones.router, prefix="/publicaciones", tags=["Publicaciones"])
app.include_router(listings.router, prefix="/listings", tags=["Listings"])
app.include_router(busqueda.router, prefix="/busqueda", tags=["Búsqueda"])
app.include_router(resenas.router, prefix="/resenas", tags=["Reseñas"])
app.include_router(moderacion.router, prefix="/moderacion", tags=["Moderación"])


@app.get("/")
def root():
    return {"mensaje": "API del marketplace de servicios entre estudiantes"}
