"""Endpoints de registro, autenticación y perfil de usuario."""
from datetime import UTC, datetime, timedelta

import bcrypt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from typing_extensions import Annotated

from app.config import SECRET_KEY
from app.database import get_db
from app.models.usuario import Usuario
from app.schemas import Token, UsuarioCreate, UsuarioLogin

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/usuarios/login")


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), hashed_password.encode("utf-8"))


def create_access_token(email: str) -> str:
    expires = datetime.now(UTC) + timedelta(hours=2)
    payload = {"sub": email, "exp": expires}
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> Usuario:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        email = payload.get("sub")
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido") from exc

    user = db.query(Usuario).filter(Usuario.correo == email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario no encontrado")
    return user


@router.post("/registro", status_code=status.HTTP_201_CREATED)
def registrar_usuario(
    payload: UsuarioCreate,
    db: Annotated[Session, Depends(get_db)],
):
    """RF-01: Registro con correo institucional."""
    correo = payload.correo.lower()
    if "@utb.edu.co" not in correo:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo debe pertenecer al dominio institucional de la UTB.",
        )

    usuario_existente = db.query(Usuario).filter(Usuario.correo == correo).first()
    if usuario_existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe un usuario registrado con ese correo.",
        )

    usuario = Usuario(
        nombre=payload.nombre,
        correo=correo,
        password_hash=hash_password(payload.password),
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    return {
        "id": usuario.id,
        "nombre": usuario.nombre,
        "correo": usuario.correo,
        "es_administrador": usuario.es_administrador,
    }


@router.post("/login", response_model=Token)
def iniciar_sesion(
    payload: UsuarioLogin,
    db: Annotated[Session, Depends(get_db)],
):
    correo = payload.correo.lower()
    usuario = db.query(Usuario).filter(Usuario.correo == correo).first()
    if not usuario or not verify_password(payload.password, usuario.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas.",
        )

    token = create_access_token(correo)
    return {"access_token": token, "token_type": "bearer"}
