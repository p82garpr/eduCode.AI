from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select
from typing import List
from database import get_db
from models.usuario import Usuario, TipoUsuario
from schemas.usuario import UsuarioCreate, UsuarioResponse
from security import get_current_user, get_password_hash

router = APIRouter()

@router.post("/registro", response_model=UsuarioResponse)
async def registro_usuario(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    # Verificar si el email ya existe
    query = select(Usuario).where(Usuario.email == usuario.email)
    result = await db.execute(query)
    db_usuario = result.scalar_one_or_none()
    
    if db_usuario:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El email ya está registrado"
        )
    
    # Crear nuevo usuario
    hashed_password = get_password_hash(usuario.password)
    db_usuario = Usuario(
        email=usuario.email,
        contrasena=hashed_password,
        nombre=usuario.nombre,
        apellidos=usuario.apellidos,
        tipo_usuario=usuario.tipo_usuario
    )
    
    db.add(db_usuario)
    await db.commit()
    await db.refresh(db_usuario)
    return db_usuario

@router.get("/profesores", response_model=List[UsuarioResponse])
async def obtener_profesores(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    query = select(Usuario).where(Usuario.tipo_usuario == TipoUsuario.PROFESOR)
    result = await db.execute(query)
    profesores = result.scalars().all()
    return profesores

@router.get("/alumnos", response_model=List[UsuarioResponse])
async def obtener_alumnos(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar si el usuario actual es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden ver la lista de alumnos"
        )
    
    query = select(Usuario).where(Usuario.tipo_usuario == TipoUsuario.ALUMNO)
    result = await db.execute(query)
    alumnos = result.scalars().all()
    return alumnos

@router.get("/me", response_model=UsuarioResponse)
async def read_users_me(current_user: Usuario = Depends(get_current_user)):
    return current_user

@router.delete("/{usuario_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_usuario(
    usuario_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Obtener el usuario
    query = select(Usuario).where(Usuario.id == usuario_id)
    result = await db.execute(query)
    usuario = result.scalar_one_or_none()
    
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    # Eliminar el usuario
    await db.delete(usuario)
    await db.commit()
    
    return None


# Endpoint para obtener los detalles del usuario dado un id de usuario
@router.get("/{usuario_id}", response_model=UsuarioResponse)
async def obtener_usuario(
    usuario_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Comprobar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener los detalles de este usuario"
        )

    # Obtener el usuario
    query = select(Usuario).where(Usuario.id == usuario_id)
    result = await db.execute(query)
    usuario = result.scalar_one_or_none()

    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )   

    return usuario
