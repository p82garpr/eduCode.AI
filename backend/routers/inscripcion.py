from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from schemas.asignatura import AsignaturaResponse
from database import get_db
from models.inscripcion import Inscripcion
from models.asignatura import Asignatura
from models.usuario import Usuario, TipoUsuario
from schemas.inscripcion import InscripcionCreate, InscripcionResponse
from security import get_current_user
from passlib.context import CryptContext
from sqlalchemy.sql import text

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

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
        
        
    # Verificar que el código de acceso es correcto
    if not pwd_context.verify(inscripcion.codigo_acceso, asignatura.codigo_acceso):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Código de acceso incorrecto"
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

@router.get("/mis-asignaturas", response_model=List[AsignaturaResponse])
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
    
    # Obtener las asignaturas en las que está inscrito el alumno
    query = (
        select(Asignatura)
        .join(Inscripcion, Inscripcion.asignatura_id == Asignatura.id)
        .where(Inscripcion.alumno_id == current_user.id)
        .options(
            selectinload(Asignatura.profesor)
        )
    )
    result = await db.execute(query)
    asignaturas = result.scalars().all()
    
    return asignaturas

@router.get("/mis-asignaturas-impartidas/", response_model=List[AsignaturaResponse])
async def obtener_mis_inscripciones_impartidas(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    try:
        # Limpiar la caché de consultas preparadas
        await db.execute(text("DEALLOCATE ALL"))
        
        # Realizar la consulta incluyendo el nuevo campo codigo_acceso
        query = select(Asignatura).where(Asignatura.profesor_id == current_user.id)
        result = await db.execute(query)
        asignaturas = result.scalars().all()
        
        return asignaturas
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al obtener las asignaturas impartidas: {str(e)}"
        )
        
    


@router.delete("/{asignatura_id}")
async def eliminar_inscripcion(
    asignatura_id: int,
    alumno_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que el usuario es profesor o alumno
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los alumnos pueden cancelar inscripciones"
        )
        
    
    
    # Buscar la inscripción
    query = select(Inscripcion).where(
        Inscripcion.alumno_id == alumno_id,
        Inscripcion.asignatura_id == asignatura_id
    )
    
    # En caso de que el usuario sea alumno, se debe verificar que el alumno sea el que está intentando cancelar la inscripción
    if current_user.tipo_usuario == TipoUsuario.ALUMNO:
        if alumno_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No puedes cancelar la inscripción de otro alumno"
            )
    # Obtener la asignatura
    query_asignatura = select(Asignatura).where(
        Asignatura.id == asignatura_id
    )
    result_asignatura = await db.execute(query_asignatura)
    asignatura = result_asignatura.scalar_one_or_none()
    
    # En caso de que el usuario sea profesor, se debe verificar que el profesor sea el que está intentando cancelar la inscripción
    if current_user.tipo_usuario == TipoUsuario.PROFESOR:
        if asignatura.profesor_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No puedes cancelar la inscripción de otra asignatura"
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