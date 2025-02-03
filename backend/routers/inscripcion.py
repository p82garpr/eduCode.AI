from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from database import get_db
from models.inscripcion import Inscripcion
from models.asignatura import Asignatura
from models.usuario import Usuario, TipoUsuario
from schemas.inscripcion import InscripcionCreate, InscripcionResponse
from security import get_current_user

router = APIRouter()

@router.post("/", response_model=InscripcionResponse)
async def crear_inscripcion(
    inscripcion: InscripcionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es alumno
    if current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los alumnos pueden inscribirse en asignaturas"
        )
    
    # Verificar que la asignatura existe
    query = select(Asignatura).where(Asignatura.id == inscripcion.asignatura_id)
    result = await db.execute(query)
    asignatura = result.scalar_one_or_none()
    
    if not asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    
    # Verificar que el alumno no está ya inscrito
    query = select(Inscripcion).where(
        Inscripcion.alumno_id == current_user.id,
        Inscripcion.asignatura_id == inscripcion.asignatura_id
    )
    result = await db.execute(query)
    existing_inscripcion = result.scalar_one_or_none()
    
    if existing_inscripcion:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya estás inscrito en esta asignatura"
        )
    
    # Crear inscripción
    db_inscripcion = Inscripcion(
        alumno_id=current_user.id,
        asignatura_id=inscripcion.asignatura_id
    )
    
    db.add(db_inscripcion)
    await db.commit()
    await db.refresh(db_inscripcion)
    
    # Cargar las relaciones después de crear la inscripción
    query = (
        select(Inscripcion)
        .where(Inscripcion.id == db_inscripcion.id)
        .options(
            selectinload(Inscripcion.alumno),
            selectinload(Inscripcion.asignatura).selectinload(Asignatura.profesor)
        )
    )
    result = await db.execute(query)
    db_inscripcion = result.scalar_one()
    
    return db_inscripcion

@router.get("/mis-asignaturas", response_model=List[InscripcionResponse])
async def obtener_mis_inscripciones(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es alumno
    if current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los alumnos pueden ver sus inscripciones"
        )
    
    # Usar selectinload para cargar las relaciones de manera explícita
    query = (
        select(Inscripcion)
        .where(Inscripcion.alumno_id == current_user.id)
        .options(
            selectinload(Inscripcion.alumno),
            selectinload(Inscripcion.asignatura).selectinload(Asignatura.profesor)
        )
    )
    result = await db.execute(query)
    
    
    inscripciones = result.scalars().all()
    return inscripciones

@router.delete("/{asignatura_id}")
async def eliminar_inscripcion(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es alumno
    if current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los alumnos pueden cancelar inscripciones"
        )
    
    # Buscar la inscripción
    query = select(Inscripcion).where(
        Inscripcion.alumno_id == current_user.id,
        Inscripcion.asignatura_id == asignatura_id
    )
    result = await db.execute(query)
    inscripcion = result.scalar_one_or_none()
    
    if not inscripcion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No estás inscrito en esta asignatura"
        )
    
    await db.delete(inscripcion)
    await db.commit()
    
    return {"message": "Inscripción cancelada exitosamente"} 