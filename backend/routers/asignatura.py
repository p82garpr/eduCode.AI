from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from database import get_db
from models.asignatura import Asignatura
from models.usuario import Usuario, TipoUsuario
from schemas.asignatura import AsignaturaCreate, AsignaturaResponse
from security import get_current_user

router = APIRouter()

@router.post("/", response_model=AsignaturaResponse)
async def crear_asignatura(
    asignatura: AsignaturaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden crear asignaturas"
        )
    
    # Crear nueva asignatura
    db_asignatura = Asignatura(
        **asignatura.model_dump(),
        profesor_id=current_user.id
    )
    
    db.add(db_asignatura)
    await db.commit()
    await db.refresh(db_asignatura)
    
    # Cargar la relación con el profesor
    query = (
        select(Asignatura)
        .where(Asignatura.id == db_asignatura.id)
        .options(selectinload(Asignatura.profesor))
    )
    result = await db.execute(query)
    db_asignatura = result.scalar_one()
    
    return db_asignatura

@router.get("/", response_model=List[AsignaturaResponse])
async def obtener_asignaturas(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Si es profesor, mostrar solo sus asignaturas
    if current_user.tipo_usuario == TipoUsuario.PROFESOR:
        query = (
            select(Asignatura)
            .where(Asignatura.profesor_id == current_user.id)
            .options(selectinload(Asignatura.profesor))
        )
    # Si es alumno, mostrar todas las asignaturas disponibles
    else:
        query = select(Asignatura).options(selectinload(Asignatura.profesor))
    
    result = await db.execute(query)
    asignaturas = result.scalars().all()
    return asignaturas

@router.get("/{asignatura_id}", response_model=AsignaturaResponse)
async def obtener_asignatura(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    query = select(Asignatura).where(Asignatura.id == asignatura_id)
    result = await db.execute(query)
    asignatura = result.scalar_one_or_none()
    
    if not asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    return asignatura

@router.put("/{asignatura_id}", response_model=AsignaturaResponse)
async def actualizar_asignatura(
    asignatura_id: int,
    asignatura_update: AsignaturaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden actualizar asignaturas"
        )
    
    # Obtener la asignatura
    query = select(Asignatura).where(Asignatura.id == asignatura_id)
    result = await db.execute(query)
    db_asignatura = result.scalar_one_or_none()
    
    if not db_asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    
    # Verificar que el profesor es el dueño de la asignatura
    if db_asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para modificar esta asignatura"
        )
    
    # Actualizar campos
    for key, value in asignatura_update.model_dump().items():
        setattr(db_asignatura, key, value)
    
    await db.commit()
    await db.refresh(db_asignatura)
    return db_asignatura

@router.delete("/{asignatura_id}")
async def eliminar_asignatura(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden eliminar asignaturas"
        )
    
    # Obtener la asignatura
    query = select(Asignatura).where(Asignatura.id == asignatura_id)
    result = await db.execute(query)
    db_asignatura = result.scalar_one_or_none()
    
    if not db_asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    
    # Verificar que el profesor es el dueño de la asignatura
    if db_asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para eliminar esta asignatura"
        )
    
    await db.delete(db_asignatura)
    await db.commit()
    
    return {"message": "Asignatura eliminada"} 