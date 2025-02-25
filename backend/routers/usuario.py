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
    """
    Registra un nuevo usuario en el sistema.

    Parameters:
    - usuario (UsuarioCreate): Datos del usuario a registrar
        - email: Email del usuario
        - password: Contraseña del usuario
        - nombre: Nombre del usuario
        - apellidos: Apellidos del usuario
        - tipo_usuario: Tipo de usuario (PROFESOR o ALUMNO)

    Returns:
    - UsuarioResponse: Datos del usuario creado

    Raises:
    - HTTPException(400): Si el email ya está registrado
    """
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
    """
    Obtiene la lista de todos los profesores registrados.

    Returns:
    - List[UsuarioResponse]: Lista de profesores

    Raises:
    - HTTPException(401): Si el usuario no está autenticado
    """
    query = select(Usuario).where(Usuario.tipo_usuario == TipoUsuario.PROFESOR)
    result = await db.execute(query)
    profesores = result.scalars().all()
    return profesores

@router.get("/alumnos", response_model=List[UsuarioResponse])
async def obtener_alumnos(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene la lista de todos los alumnos registrados.
    Solo accesible para profesores.

    Returns:
    - List[UsuarioResponse]: Lista de alumnos

    Raises:
    - HTTPException(403): Si el usuario no es profesor
    - HTTPException(401): Si el usuario no está autenticado
    """
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
    """
    Obtiene los datos del usuario autenticado actual.

    Returns:
    - UsuarioResponse: Datos del usuario actual

    Raises:
    - HTTPException(401): Si el usuario no está autenticado
    """
    return current_user

@router.delete("/{usuario_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_usuario(
    usuario_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Elimina un usuario del sistema.
    Solo los profesores pueden eliminar usuarios.

    Parameters:
    - usuario_id (int): ID del usuario a eliminar

    Returns:
    - None

    Raises:
    - HTTPException(404): Si el usuario no existe
    - HTTPException(403): Si el usuario no tiene permisos para eliminar
    - HTTPException(401): Si el usuario no está autenticado
    """
    # Verificar que el usuario actual es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden eliminar usuarios"
        )
    
    # Obtener el usuario a eliminar
    query = select(Usuario).where(Usuario.id == usuario_id)
    result = await db.execute(query)
    usuario = result.scalar_one_or_none()
    
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    # No permitir que un profesor se elimine a sí mismo
    if usuario.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes eliminarte a ti mismo"
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
    """
    Obtiene el perfil completo de un usuario, incluyendo sus asignaturas.

    Parameters:
    - user_id (int): ID del usuario

    Returns:
    - ProfileResponse: Perfil completo del usuario incluyendo:
        - Datos básicos del usuario
        - Asignaturas impartidas (si es profesor)
        - Asignaturas inscritas (si es alumno)

    Raises:
    - HTTPException(404): Si el usuario no existe
    - HTTPException(403): Si no tiene permisos para ver el perfil
    - HTTPException(401): Si el usuario no está autenticado
    """
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
                "profesor": profesor_info,
                "codigo_acceso": asig.codigo_acceso
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
                "codigo_acceso": insc.asignatura.codigo_acceso,
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
    """
    Actualiza los datos del usuario actual.

    Parameters:
    - user_data (UpdateUserRequest): Nuevos datos del usuario
        - nombre: Nuevo nombre
        - apellidos: Nuevos apellidos
        - email: Nuevo email
        - password: Nueva contraseña (opcional)

    Returns:
    - UsuarioResponse: Datos actualizados del usuario

    Raises:
    - HTTPException(400): Si el email ya está en uso por otro usuario
    - HTTPException(401): Si el usuario no está autenticado
    """
    try:
        # Verificar si el email ya existe para otro usuario (solo si está cambiando el email)
        if user_data.email != current_user.email:
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
                    detail="El email ya está en uso por otro usuario"
                )
        
        # Actualizar los datos del usuario manteniendo el tipo_usuario
        update_data = {
            "nombre": user_data.nombre,
            "apellidos": user_data.apellidos,
            "email": user_data.email,
            "tipo_usuario": current_user.tipo_usuario  # Mantener el tipo de usuario actual para evitar cambios
        }
        
        if user_data.password:
            update_data["contrasena"] = pwd_context.hash(user_data.password)
        
        # Obtener el usuario actualizado con todos los campos
        query = (
            update(Usuario)
            .where(Usuario.id == current_user.id)
            .values(**update_data)
            .returning(Usuario)
        )
        
        result = await db.execute(query)
        await db.commit()
        
        # Luego obtener el usuario actualizado
        query = select(Usuario).where(Usuario.id == current_user.id)
        result = await db.execute(query)
        updated_user = result.scalar_one()
        return updated_user
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al actualizar el usuario: {str(e)}"
        )
