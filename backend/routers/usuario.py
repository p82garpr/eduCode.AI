from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, update, and_
from typing import List
from database import get_db
from models.usuario import Usuario, TipoUsuario
from schemas.usuario import UsuarioCreate, UsuarioResponse
from security import get_current_user, get_password_hash
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from models.asignatura import Asignatura
from models.inscripcion import Inscripcion
from schemas.profile import ProfileResponse
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr

router = APIRouter()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class UpdateUserRequest(BaseModel):
    nombre: str
    apellidos: str
    email: EmailStr
    password: str | None = None

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "nombre": "Juan",
                "apellidos": "Pérez",
                "email": "juan@example.com",
                "password": "nuevacontraseña"
            }
        }

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

@router.get("/usuarios/{user_id}/profile", response_model=ProfileResponse)
async def get_user_profile(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Comprobar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener el perfil de este usuario"
        )

    # Obtener el usuario con sus relaciones
    query = (
        select(Usuario)
        .where(Usuario.id == user_id)
        .options(
            selectinload(Usuario.asignaturas),
            selectinload(Usuario.inscripciones).selectinload(Inscripcion.asignatura).selectinload(Asignatura.profesor)
        )
    )
    result = await db.execute(query)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )

    if user.tipo_usuario == TipoUsuario.PROFESOR:
        profesor_info = {
            "id": user.id,
            "nombre": user.nombre,
            "apellidos": user.apellidos,
            "email": user.email,
            "tipo_usuario": user.tipo_usuario
        }
        asignaturas_impartidas = [
            {
                "id": asig.id,
                "nombre": asig.nombre,
                "descripcion": asig.descripcion,
                "profesor_id": user.id,
                "profesor": profesor_info
            } 
            for asig in user.asignaturas
        ]
        return {
            "id": user.id,
            "nombre": user.nombre,
            "apellidos": user.apellidos,
            "email": user.email,
            "tipo_usuario": user.tipo_usuario,
            "asignaturas_impartidas": asignaturas_impartidas,
            "asignaturas_inscritas": []
        }
    else:
        asignaturas_inscritas = [
            {
                "id": insc.asignatura.id,
                "nombre": insc.asignatura.nombre,
                "descripcion": insc.asignatura.descripcion,
                "profesor_id": insc.asignatura.profesor_id,
                "profesor": {
                    "id": insc.asignatura.profesor.id,
                    "nombre": insc.asignatura.profesor.nombre,
                    "apellidos": insc.asignatura.profesor.apellidos,
                    "email": insc.asignatura.profesor.email,
                    "tipo_usuario": insc.asignatura.profesor.tipo_usuario
                }
            } 
            for insc in user.inscripciones
        ]
        return {
            "id": user.id,
            "nombre": user.nombre,
            "apellidos": user.apellidos,
            "email": user.email,
            "tipo_usuario": user.tipo_usuario,
            "asignaturas_impartidas": [],
            "asignaturas_inscritas": asignaturas_inscritas
        }

@router.put("/usuarios/update", response_model=UsuarioResponse)
async def update_user(
    user_data: UpdateUserRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    try:
        # Verificar si el email ya existe para otro usuario
        query = select(Usuario).where(
            and_(
                Usuario.email == user_data.email,
                Usuario.id != current_user.id
            )
        )
        result = await db.execute(query)
        existing_user = result.scalar_one_or_none()
        
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El email ya está en uso"
            )
        
        # Actualizar los datos del usuario
        update_data = {
            "nombre": user_data.nombre,
            "apellidos": user_data.apellidos,
            "email": user_data.email,
        }
        
        if user_data.password:
            update_data["contrasena"] = pwd_context.hash(user_data.password)
        
        query = (
            update(Usuario)
            .where(Usuario.id == current_user.id)
            .values(**update_data)
            .returning(Usuario)
        )
        
        result = await db.execute(query)
        await db.commit()
        
        updated_user = result.scalar_one()
        return updated_user
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al actualizar el usuario: {str(e)}"
        )
