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
            ("Apartaestudio Amoblado cerca al Campus Ternera", "Apartaestudio individual con servicios incluidos (agua, luz, gas e internet), aire acondicionado, cama semidoble y closet a 3 cuadras de la UTB.", 550000.0, "Alojamiento", "http://127.0.0.1:8000/uploads/apartaestudio.jpg"),
            ("Habitación en Apartamento Compartido para Estudiante", "Habitación amoblada en conjunto cerrado con piscina y vigilancia 24/7. Baño compartido con otro estudiante UTB, derecho a cocina y zona de labores.", 380000.0, "Alojamiento", "http://127.0.0.1:8000/uploads/apartamento_doble.jpg"),
            ("Jugos Naturales y Frappés 100% Fruta", "Bebidas naturales refrescantes de mango, maracuyá, fresa y guanábana. Endulzados con miel o stevia. Entregas en plazoleta de comidas o biblioteca.", 6000.0, "Comida y Snacks", "http://127.0.0.1:8000/uploads/jugos_naturales.jpg"),
            ("Sándwich Artesanal de Pollo y Jamón con Queso", "Pan artesanal horneado del día, pechuga desmechada sazonada, queso mozzarella fundido, lechuga fresca y salsas caseras.", 12000.0, "Comida y Snacks", "http://127.0.0.1:8000/uploads/sandwich.jpg"),
            ("Set de Mancuernas Ajustables 20kg con Discos", "Par de mancuernas con barras cromadas antideslizantes, tuercas de seguridad y discos intercambiables para entrenamiento en casa.", 95000.0, "Deportes", "http://127.0.0.1:8000/uploads/pesas_para_hacer_ejercicio.jpg"),
            ("Vestido Formal Negro Elegante Corte Clásico", "Vestido formal color negro, talla M, corte ajustado a la cintura. Perfecto para grados, ponencias académicas, ferias empresariales o eventos formales.", 65000.0, "Ropa y Accesorios", "http://127.0.0.1:8000/uploads/vestido_negro.jpg"),
            ("Traje de Baño Dos Piezas Estilo Playero", "Bikini nuevo con etiqueta protectora, tela de secado rápido con protección UV50+. Color vibrante para salidas a la playa o piscina.", 45000.0, "Ropa y Accesorios", "http://127.0.0.1:8000/uploads/traje_de_bano.jpg"),
            ("Kit Completo de Útiles Escolares y Papelería", "Kit completo para el semestre: 2 libretas argolladas, estuche de resaltadores pastel, lapiceros de gel, regla metálica y notas adhesivas.", 28000.0, "Útiles Escolares", "http://127.0.0.1:8000/uploads/utiles_escolares.jpg"),
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
