"""Punto de entrada de la API del marketplace de servicios."""
import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.database import Base, engine
from app.models import Usuario, Categoria, Publicacion, Resena, Compra, Mensaje
from app.routers import busqueda, chat, compras, listings, moderacion, publicaciones, resenas, usuarios

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
    # Asegurar usuarios demo institucionales si no existen
    from app.database import SessionLocal
    from app.routers.usuarios import hash_password

    db = SessionLocal()
    try:
        mod = db.query(Usuario).filter(Usuario.correo == "moderador@utb.edu.co").first()
        if not mod:
            mod = Usuario(
                nombre="Moderador UTB",
                correo="moderador@utb.edu.co",
                password_hash=hash_password("moderador123"),
                es_administrador=True,
            )
            db.add(mod)
            db.commit()
            db.refresh(mod)

        est = db.query(Usuario).filter(Usuario.correo == "estudiante@utb.edu.co").first()
        if not est:
            est = Usuario(
                nombre="Estudiante UTB",
                correo="estudiante@utb.edu.co",
                password_hash=hash_password("estudiante123"),
                es_administrador=False,
            )
            db.add(est)
            db.commit()
            db.refresh(est)

        # Si existe usuario ficticio Carlos Mendoza, reasignar y eliminar
        ven_fake = db.query(Usuario).filter(Usuario.correo == "vendedor@utb.edu.co").first()
        if ven_fake and mod:
            db.query(Publicacion).filter(Publicacion.usuario_id == ven_fake.id).update({"usuario_id": mod.id})
            db.query(Mensaje).filter(Mensaje.destinatario_id == ven_fake.id).update({"destinatario_id": mod.id})
            db.query(Mensaje).filter(Mensaje.remitente_id == ven_fake.id).update({"remitente_id": mod.id})
            db.delete(ven_fake)
            db.commit()

        # Sembrar catálogo inicial con imágenes de uploads si la base de datos está vacía
        items_catalogo = [
            ("Cálculo James Stewart 8va Edición", "Libro de Cálculo en excelente estado para cursos de Cálculo I, II y III.", 45000.0, "Libros y Apuntes", "http://127.0.0.1:8000/uploads/libro_stewart.jpg"),
            ("Álgebra Lineal con Aplicaciones", "Texto guía oficial para ingeniería UTB, incluye ejercicios resueltos.", 38000.0, "Libros y Apuntes", "http://127.0.0.1:8000/uploads/algebra_lineal.jpg"),
            ("Calculadora Científica Texas Instruments TI-84", "Calculadora gráfica programable con batería recargable.", 120000.0, "Electrónica", "http://127.0.0.1:8000/uploads/calculadora_texas.jpg"),
            ("Kit Arduino Mega 2560 R3 con Sensores", "Kit completo de robótica y circuitos para proyectos de ingeniería.", 85000.0, "Electrónica", "http://127.0.0.1:8000/uploads/arduino_mega.jpg"),
            ("Cupo Ride: Campus Ternera a Bocagrande", "Salida 5:30pm de campus Ternera a Bocagrande / Manga / Centro.", 5000.0, "Transporte y Rides", "http://127.0.0.1:8000/uploads/ride_bocagrande.jpg"),
            ("Tutoría de Cálculo Diferencial e Integral", "Clases personalizadas y preparación para parciales y quices.", 25000.0, "Servicios Académicos", "http://127.0.0.1:8000/uploads/tutoria_calculo.jpg"),
            ("Asesoría en Física Mecánica y Ondas", "Explicación de talleres, laboratorios y ejercicios tipo parcial.", 30000.0, "Servicios Académicos", "http://127.0.0.1:8000/uploads/tutoria_fisica.jpg"),
        ]

        for titulo, desc, precio, c_nombre, img_url in items_catalogo:
            if not db.query(Publicacion).filter(Publicacion.titulo == titulo).first():
                cat = db.query(Categoria).filter(Categoria.nombre == c_nombre).first()
                if not cat:
                    cat = Categoria(nombre=c_nombre)
                    db.add(cat)
                    db.commit()
                    db.refresh(cat)

                db.add(
                    Publicacion(
                        titulo=titulo,
                        descripcion=desc,
                        precio=precio,
                        categoria_id=cat.id,
                        imagen_url=img_url,
                        usuario_id=mod.id,
                        estado="activa",
                    )
                )

        # Asignar a publicaciones huérfanas el usuario moderador
        if mod:
            db.query(Publicacion).filter(Publicacion.usuario_id.is_(None)).update({"usuario_id": mod.id})
        db.commit()

    except Exception:
        db.rollback()
    finally:
        db.close()


app.include_router(usuarios.router, prefix="/usuarios", tags=["Usuarios"])
app.include_router(publicaciones.router, prefix="/publicaciones", tags=["Publicaciones"])
app.include_router(listings.router, prefix="/listings", tags=["Listings"])
app.include_router(busqueda.router, prefix="/busqueda", tags=["Búsqueda"])
app.include_router(resenas.router, prefix="/resenas", tags=["Reseñas"])
app.include_router(moderacion.router, prefix="/moderacion", tags=["Moderación"])
app.include_router(compras.router, prefix="/compras", tags=["Compras"])
app.include_router(chat.router, prefix="/chat", tags=["Chat"])


@app.middleware("http")
async def no_cache_static_middleware(request: Request, call_next):
    response = await call_next(request)
    path = request.url.path
    if path == "/" or path.endswith((".html", ".js")):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


# Directorio de la interfaz web de Flutter compilada
static_frontend_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
static_index_html = os.path.join(static_frontend_dir, "index.html")


@app.get("/")
def root(request: Request):
    accept = request.headers.get("accept", "")
    if "text/html" in accept and os.path.isfile(static_index_html):
        return FileResponse(
            static_index_html,
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0",
            },
        )
    return {"mensaje": "API del marketplace de servicios entre estudiantes"}


if os.path.isdir(static_frontend_dir) and os.path.isfile(static_index_html):
    app.mount("/", StaticFiles(directory=static_frontend_dir, html=True), name="frontend")
