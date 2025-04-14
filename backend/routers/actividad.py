from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from database import get_db
from models.actividad import Actividad
from models.asignatura import Asignatura
from models.usuario import Usuario, TipoUsuario
from models.inscripcion import Inscripcion
from models.entrega import Entrega
from schemas.actividad import ActividadCreate, ActividadResponse, ActividadUpdate
from security import get_current_user
from datetime import datetime

router = APIRouter()

@router.post("/", response_model=ActividadResponse)
async def crear_actividad(
    actividad: ActividadCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Crea una nueva actividad en una asignatura.
    Solo el profesor de la asignatura puede crear actividades.

    Parameters:
    - actividad (ActividadCreate): Datos de la actividad
        - titulo: Título de la actividad
        - descripcion: Descripción de la actividad
        - fecha_entrega: Fecha límite de entrega
        - asignatura_id: ID de la asignatura
        - solucion: Solución de la actividad (opcional)

    Returns:
    - ActividadResponse: Datos de la actividad creada

    Raises:
    - HTTPException(403): Si el usuario no es profesor
    - HTTPException(404): Si la asignatura no existe
    """
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden crear actividades"
        )
    
    # Verificar que la asignatura existe y pertenece al profesor
    query = select(Asignatura).where(
        Asignatura.id == actividad.asignatura_id,
        Asignatura.profesor_id == current_user.id
    )
    result = await db.execute(query)
    asignatura = result.scalar_one_or_none()
    
    if not asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada o no tienes permiso para crear actividades en ella"
        )
    
    # Crear actividad
    db_actividad = Actividad(**actividad.model_dump())
    db.add(db_actividad)
    await db.commit()
    await db.refresh(db_actividad)
    
    # Cargar la relación con la asignatura
    query = (
        select(Actividad)
        .where(Actividad.id == db_actividad.id)
        .options(selectinload(Actividad.asignatura))
    )
    result = await db.execute(query)
    db_actividad = result.scalar_one()
    
    return db_actividad


@router.get("/asignatura/{asignatura_id}", response_model=List[ActividadResponse])
async def obtener_actividades_asignatura(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene todas las actividades de una asignatura.
    Accesible para el profesor de la asignatura y alumnos inscritos.

    Parameters:
    - asignatura_id (int): ID de la asignatura

    Returns:
    - List[ActividadResponse]: Lista de actividades de la asignatura

    Raises:
    - HTTPException(404): Si la asignatura no existe
    - HTTPException(403): Si el usuario no tiene acceso a la asignatura
    """
    # Verificar que la asignatura existe
    query = (
        select(Asignatura)
        .where(Asignatura.id == asignatura_id)
        .options(selectinload(Asignatura.profesor))
    )
    result = await db.execute(query)
    asignatura = result.scalar_one_or_none()
    
    if not asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    
    # Si es profesor, verificar que es su asignatura
    if current_user.tipo_usuario == TipoUsuario.PROFESOR and asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver las actividades de esta asignatura"
        )
    
    # Si es alumno, verificar que está inscrito
    if current_user.tipo_usuario == TipoUsuario.ALUMNO:
        query = (
            select(Asignatura)
            .join(Asignatura.inscripciones)
            .where(
                Asignatura.id == asignatura_id,
                Inscripcion.alumno_id == current_user.id
            )
        )
        result = await db.execute(query)
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No estás inscrito en esta asignatura"
            )
    
    # Obtener actividades con todas las relaciones necesarias
    query = (
        select(Actividad)
        .where(Actividad.asignatura_id == asignatura_id)
        .options(
            selectinload(Actividad.asignatura).selectinload(Asignatura.profesor)
        )
    )
    result = await db.execute(query)
    actividades = result.scalars().all()
    
    return actividades

@router.delete("/{actividad_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_actividad(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Elimina una actividad.
    Solo el profesor de la asignatura puede eliminar actividades.

    Parameters:
    - actividad_id (int): ID de la actividad a eliminar

    Returns:
    - None

    Raises:
    - HTTPException(404): Si la actividad no existe
    - HTTPException(403): Si el usuario no es el profesor de la asignatura
    """
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden eliminar actividades"
        )
    
    # Obtener la actividad y su asignatura
    query = (
        select(Actividad)
        .join(Actividad.asignatura)
        .options(selectinload(Actividad.asignatura))
        .where(Actividad.id == actividad_id)
    )
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    if not actividad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Actividad no encontrada"
        )
    
    # Verificar que el profesor es el de la asignatura
    if actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para eliminar esta actividad"
        )
    
    # Eliminar la actividad
    await db.delete(actividad)
    await db.commit()
    
    return None

@router.put("/{actividad_id}", response_model=ActividadResponse)
async def actualizar_actividad(
    actividad_id: int,
    actividad_actualizada: ActividadUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Actualiza los datos de una actividad.
    Solo el profesor de la asignatura puede actualizar actividades.

    Parameters:
    - actividad_id (int): ID de la actividad
    - actividad_actualizada (ActividadUpdate): Nuevos datos de la actividad
        - titulo: Nuevo título (opcional)
        - descripcion: Nueva descripción (opcional)
        - fecha_entrega: Nueva fecha de entrega (opcional)
        - solucion: Nueva solución (opcional)

    Returns:
    - ActividadResponse: Datos actualizados de la actividad

    Raises:
    - HTTPException(404): Si la actividad no existe
    - HTTPException(403): Si el usuario no es el profesor de la asignatura
    """
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden editar actividades"
        )
    
    # Obtener la actividad y su asignatura
    query = (
        select(Actividad)
        .join(Actividad.asignatura)
        .options(
            selectinload(Actividad.asignatura)
        )
        .where(Actividad.id == actividad_id)
    )
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    if not actividad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Actividad no encontrada"
        )
    
    # Verificar que el profesor es el de la asignatura
    if actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para editar esta actividad"
        )
    
    # Actualizar los campos de la actividad
    for field, value in actividad_actualizada.model_dump(exclude_unset=True).items():
        setattr(actividad, field, value)
    
    await db.commit()
    await db.refresh(actividad)
    
    return actividad 

#Endpoint para obtener la actividad con el id
@router.get("/{actividad_id}", response_model=ActividadResponse)
async def obtener_actividad(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene los detalles de una actividad específica.
    Accesible para el profesor de la asignatura y alumnos inscritos.

    Parameters:
    - actividad_id (int): ID de la actividad

    Returns:
    - ActividadResponse: Detalles de la actividad

    Raises:
    - HTTPException(404): Si la actividad no existe
    - HTTPException(403): Si el usuario no tiene acceso a la actividad
    """
    # Verificar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver esta actividad"
        )
    # Obtener la actividad con sus relaciones
    query = (
        select(Actividad)
        .options(
            selectinload(Actividad.asignatura)
            .selectinload(Asignatura.profesor)
        )
        .where(Actividad.id == actividad_id)
    )
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    # Si no existe la actividad, lanzar error 404
    if not actividad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Actividad no encontrada"
        )
        
    # Si es alumno, verificar que está inscrito en la asignatura
    if current_user.tipo_usuario == TipoUsuario.ALUMNO:
        query = (
            select(Inscripcion)
            .where(
                Inscripcion.alumno_id == current_user.id,
                Inscripcion.asignatura_id == actividad.asignatura_id
            )
        )
        result = await db.execute(query)
        inscripcion = result.scalar_one_or_none()
        if not inscripcion:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No estás inscrito en la asignatura de esta actividad"
            )
    # Si es profesor, verificar que es el profesor de la asignatura
    elif current_user.tipo_usuario == TipoUsuario.PROFESOR:
        if actividad.asignatura.profesor_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No eres el profesor de esta actividad"
            )
            
    return actividad
  

