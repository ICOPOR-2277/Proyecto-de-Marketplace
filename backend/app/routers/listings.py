"""Endpoints para listings y subida de imágenes consumidos por el frontend."""
import os
import re
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy.orm import Session
from typing_extensions import Annotated

from app.database import get_db
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion
from app.schemas import ListingCreate, ListingOut

router = APIRouter()

# Directorio de subida de archivos
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)


def parse_price(price_str: str) -> float:
    """Extrae un valor numérico flotante a partir de un string de precio."""
    cleaned = re.sub(r"[^\d.,]", "", price_str).strip()
    if not cleaned:
        return 0.0
    # Manejar formatos comunes: "25.000", "25,000", "25000"
    if "." in cleaned and "," in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    elif "." in cleaned and len(cleaned.split(".")[-1]) == 3:
        cleaned = cleaned.replace(".", "")
    elif "," in cleaned and len(cleaned.split(",")[-1]) == 3:
        cleaned = cleaned.replace(",", "")
    else:
        cleaned = cleaned.replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return 0.0


@router.post("/upload-image", status_code=status.HTTP_201_CREATED)
async def upload_image(
    request: Request,
    file: UploadFile = File(...),
):
    """Sube una imagen y retorna su URL pública."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="Nombre de archivo inválido")

    # Extraer extensión
    _, ext = os.path.splitext(file.filename)
    if not ext:
        ext = ".jpg"

    safe_name = f"{uuid.uuid4().hex[:12]}_{os.path.basename(file.filename)}"
    file_path = os.path.join(UPLOADS_DIR, safe_name)

    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    base_url = str(request.base_url).rstrip("/")
    file_url = f"{base_url}/uploads/{safe_name}"

    return {"url": file_url}


@router.post("/", response_model=ListingOut, status_code=status.HTTP_201_CREATED)
def crear_listing(
    payload: ListingCreate,
    db: Annotated[Session, Depends(get_db)],
):
    """Crea una publicación en formato listing desde el frontend."""
    nombre_categoria = payload.category.strip()
    categoria = db.query(Categoria).filter(Categoria.nombre.ilike(nombre_categoria)).first()
    if not categoria:
        categoria = Categoria(nombre=nombre_categoria)
        db.add(categoria)
        db.commit()
        db.refresh(categoria)

    precio_num = parse_price(payload.price)

    publicacion = Publicacion(
        titulo=payload.title.strip(),
        descripcion=payload.title.strip(),
        precio=precio_num,
        categoria_id=categoria.id,
        imagen_url=payload.imageUrl,
    )
    db.add(publicacion)
    db.commit()
    db.refresh(publicacion)

    return ListingOut(
        id=str(publicacion.id),
        category=categoria.nombre,
        title=publicacion.titulo,
        price=payload.price,
        imageUrl=publicacion.imagen_url,
    )


@router.get("/", response_model=List[ListingOut])
def obtener_listings(
    db: Annotated[Session, Depends(get_db)],
    category: Optional[str] = None,
):
    """Obtiene la lista de publicaciones para el frontend."""
    consulta = db.query(Publicacion)
    if category and category.strip():
        consulta = consulta.join(Categoria, Publicacion.categoria_id == Categoria.id).filter(
            Categoria.nombre.ilike(f"%{category.strip()}%")
        )

    resultados: List[ListingOut] = []
    for pub in consulta.order_by(Publicacion.id.desc()).all():
        categoria_obj = db.query(Categoria).filter(Categoria.id == pub.categoria_id).first()
        cat_nombre = categoria_obj.nombre if categoria_obj else ""
        precio_str = f"${int(pub.precio):,}".replace(",", ".") if pub.precio is not None else "$0"
        resultados.append(
            ListingOut(
                id=str(pub.id),
                category=cat_nombre,
                title=pub.titulo,
                price=precio_str,
                imageUrl=pub.imagen_url,
            )
        )
    return resultados
