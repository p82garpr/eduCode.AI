from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from models.inscripcion import Inscripcion
from database import get_db
from models.entrega import Entrega
from models.actividad import Actividad
from models.asignatura import Asignatura
from models.usuario import Usuario, TipoUsuario
from schemas.entrega import EntregaCreate, EntregaUpdate, EntregaResponse
from security import get_current_user
from datetime import datetime

router = APIRouter()

@router.post("/", response_model=EntregaResponse)
async def crear_entrega(
    entrega: EntregaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es alumno
    if current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los alumnos pueden crear entregas"
        )
    
    # Verificar que la actividad existe y cargar todas las relaciones necesarias
    query = (
        select(Actividad)
        .join(Actividad.asignatura)
        .options(
            selectinload(Actividad.asignatura).selectinload(Asignatura.profesor)
        )
        .where(Actividad.id == entrega.actividad_id)
    )
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    if not actividad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Actividad no encontrada"
        )
    
    # Verificar que el alumno está inscrito en la asignatura
    query = (
        select(Asignatura)
        .join(Asignatura.inscripciones)
        .where(
            Asignatura.id == actividad.asignatura_id,
            Inscripcion.alumno_id == current_user.id
        )
    )
    result = await db.execute(query)
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No estás inscrito en esta asignatura"
        )
    
    # Verificar que no ha pasado la fecha de entrega
    if datetime.now() > actividad.fecha_entrega:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La fecha de entrega ya ha pasado"
        )
    
    # Verificar si ya existe una entrega
    query = select(Entrega).where(
        Entrega.actividad_id == entrega.actividad_id,
        Entrega.alumno_id == current_user.id
    )
    result = await db.execute(query)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya has realizado una entrega para esta actividad"
        )
    
    # Crear entrega
    db_entrega = Entrega(
        archivo_entrega=entrega.archivo_entrega,
        actividad_id=entrega.actividad_id,
        alumno_id=current_user.id
    )
    db.add(db_entrega)
    await db.commit()
    await db.refresh(db_entrega)
    
    # Cargar todas las relaciones necesarias
    query = (
        select(Entrega)
        .where(Entrega.id == db_entrega.id)
        .options(
            selectinload(Entrega.actividad).selectinload(Actividad.asignatura).selectinload(Asignatura.profesor),
            selectinload(Entrega.alumno)
        )
    )
    result = await db.execute(query)
    db_entrega = result.scalar_one()
    
    return db_entrega

@router.get("/actividad/{actividad_id}", response_model=List[EntregaResponse])
async def obtener_entregas_actividad(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que la actividad existe
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
    
    # Verificar permisos
    if current_user.tipo_usuario == TipoUsuario.PROFESOR:
        if actividad.asignatura.profesor_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para ver estas entregas"
            )
    else:
        # Si es alumno, solo puede ver su propia entrega
        query = (
            select(Entrega)
            .where(
                Entrega.actividad_id == actividad_id,
                Entrega.alumno_id == current_user.id
            )
            .options(
                selectinload(Entrega.actividad).selectinload(Actividad.asignatura),
                selectinload(Entrega.alumno)
            )
        )
        result = await db.execute(query)
        entregas = result.scalars().all()
        return entregas
    
    # Para profesores, obtener todas las entregas
    query = (
        select(Entrega)
        .where(Entrega.actividad_id == actividad_id)
        .options(
            selectinload(Entrega.actividad).selectinload(Actividad.asignatura),
            selectinload(Entrega.alumno)
        )
    )
    result = await db.execute(query)
    entregas = result.scalars().all()
    
    return entregas

@router.patch("/{entrega_id}", response_model=EntregaResponse)
async def calificar_entrega(
    entrega_id: int,
    calificacion: EntregaUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden calificar entregas"
        )
    
    # Obtener la entrega con sus relaciones
    query = (
        select(Entrega)
        .where(Entrega.id == entrega_id)
        .options(
            selectinload(Entrega.actividad).selectinload(Actividad.asignatura),
            selectinload(Entrega.alumno)
        )
    )
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    # Verificar que la entrega pertenece a una actividad de una asignatura del profesor
    if entrega.actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para calificar esta entrega"
        )
    
    # Actualizar calificación y comentarios
    entrega.calificacion = calificacion.calificacion
    entrega.comentarios = calificacion.comentarios
    await db.commit()
    await db.refresh(entrega)
    
    return entrega 