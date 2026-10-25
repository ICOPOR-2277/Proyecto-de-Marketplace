"""Endpoints de búsqueda flexible y difusa (fuzzy search) de publicaciones."""
import unicodedata
from difflib import SequenceMatcher
from typing import List, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing_extensions import Annotated

from app.database import get_db
from app.models.categoria import Categoria
from app.models.publicacion import Publicacion

router = APIRouter()


def normalizar(texto: str) -> str:
    """Elimina tildes, signos de puntuación y pasa a minúsculas."""
    if not texto:
        return ""
    # Descomponer caracteres con acentos
    nfkd = unicodedata.normalize("NFKD", texto)
    sin_tildes = "".join([c for c in nfkd if not unicodedata.combining(c)])
    return sin_tildes.lower().strip()


def similitud_difusa(palabra1: str, palabra2: str) -> float:
    """Calcula el ratio de similitud entre dos cadenas (0.0 a 1.0)."""
    return SequenceMatcher(None, palabra1, palabra2).ratio()


def coincide_flexible(query_norm: str, texto_norm: str) -> tuple[bool, float]:
    """Evalúa coincidencia exacta, parcial, por token o difusa (fuzzy).

    Retorna (coincide, score).
    """
    if not query_norm or not texto_norm:
        return False, 0.0

    # 1. Coincidencia directa como subcadena
    if query_norm in texto_norm:
        return True, 1.0

    palabras_query = [p for p in query_norm.split() if p]
    palabras_texto = [p for p in texto_norm.split() if p]

    # 2. Si alguna palabra de la consulta está en el texto
    tokens_coincidentes = 0
    max_similitud_token = 0.0

    for pq in palabras_query:
        coincide_token = False
        for pt in palabras_texto:
            sim = similitud_difusa(pq, pt)
            if sim > max_similitud_token:
                max_similitud_token = sim

            # Considerar token similar si la similitud > 0.68 o si es prefijo
            if sim >= 0.68 or pt.startswith(pq) or pq.startswith(pt):
                coincide_token = True
                break
        if coincide_token:
            tokens_coincidentes += 1

    if palabras_query and (tokens_coincidentes / len(palabras_query)) >= 0.5:
        score = (tokens_coincidentes / len(palabras_query)) * 0.9
        return True, score

    # 3. Similitud global de frase completa
    ratio_global = similitud_difusa(query_norm, texto_norm)
    if ratio_global >= 0.60:
        return True, ratio_global

    return False, 0.0


@router.get("/")
def buscar_publicaciones(
    db: Annotated[Session, Depends(get_db)],
    query: str = "",
    categoria: str = "",
):
    """RF-04: Buscar y filtrar servicios con búsqueda difusa/tolerante a errores."""
    consulta = db.query(Publicacion).filter(Publicacion.estado != "eliminada")

    if categoria and categoria.strip():
        cat_norm = normalizar(categoria)
        # Filtrar o unir por categoría
        consulta = consulta.join(Categoria, Publicacion.categoria_id == Categoria.id).filter(
            Categoria.nombre.ilike(f"%{categoria.strip()}%")
        )

    publicaciones = consulta.all()

    if not query or not query.strip():
        resultado = []
        for pub in publicaciones:
            categoria_obj = db.query(Categoria).filter(Categoria.id == pub.categoria_id).first()
            resultado.append(
                {
                    "id": pub.id,
                    "titulo": pub.titulo,
                    "descripcion": pub.descripcion,
                    "precio": pub.precio,
                    "estado": pub.estado,
                    "categoria": categoria_obj.nombre if categoria_obj else "General",
                    "imagen_url": pub.imagen_url,
                }
            )
        return resultado

    query_normalizada = normalizar(query)
    candidatos_con_score = []

    for pub in publicaciones:
        categoria_obj = db.query(Categoria).filter(Categoria.id == pub.categoria_id).first()
        cat_nombre = categoria_obj.nombre if categoria_obj else ""

        # Evaluar título, descripción y categoría
        coincide_t, score_t = coincide_flexible(query_normalizada, normalizar(pub.titulo))
        coincide_d, score_d = coincide_flexible(query_normalizada, normalizar(pub.descripcion or ""))
        coincide_c, score_c = coincide_flexible(query_normalizada, normalizar(cat_nombre))

        if coincide_t or coincide_d or coincide_c:
            best_score = max(score_t * 1.2, score_d * 0.8, score_c * 1.0)
            candidatos_con_score.append(
                (
                    best_score,
                    {
                        "id": pub.id,
                        "titulo": pub.titulo,
                        "descripcion": pub.descripcion,
                        "precio": pub.precio,
                        "estado": pub.estado,
                        "categoria": cat_nombre,
                        "imagen_url": pub.imagen_url,
                    },
                )
            )

    # Ordenar resultados por relevancia (score descendente)
    candidatos_con_score.sort(key=lambda x: x[0], reverse=True)
    return [item for _, item in candidatos_con_score]
