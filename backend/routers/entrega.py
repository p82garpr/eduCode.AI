from fastapi import APIRouter, Depends, HTTPException, Path, requests, status
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

@router.get("/actividad/{actividad_id}/entregas", response_model=List[EntregaResponse])
async def obtener_entregas_actividad(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Verificar que la actividad existe y cargar las entregas
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
    
    # Verificar que el usuario es el profesor de la asignatura
    if current_user.tipo_usuario != TipoUsuario.PROFESOR or actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver las entregas de esta actividad"
        )
    
    # Obtener solo las entregas sin cargar relaciones adicionales
    query = select(Entrega).where(Entrega.actividad_id == actividad_id)
    result = await db.execute(query)
    entregas = result.scalars().all()
    
    return entregas

#Endpoint para evaluar entregas
@router.put("/evaluar/{entrega_id}", response_model=EntregaResponse)
async def evaluar_entrega(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    
    #TODO: REVISAR TODO PORQUE NO FUNCIONA
    
    # comprobar que el usuario esta logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para evaluar entregas"
        )
    
    #obtener la actividad
    query = select(Actividad).where(Actividad.id == actividad_id)
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    #obtener la entrega
    query = select(Entrega).where(Entrega.actividad_id == actividad_id and Entrega.alumno_id == current_user.id)
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if entrega.archivo_entrega is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No has subido ningún archivo"
        )
    
    #conectar con la API y mandarle la entrega
    try:
        # Enviar el texto al LM para evaluación
        lm_response = requests.post(
            "http://localhost:1234/v1/chat/completions",  # Ajusta la URL según tu configuración de LMStudio
            json={
                "messages": [
                    {"role": "system", "content": f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo en base al enunciado siguiente: {actividad.descripcion}"},
                    {"role": "user", "content": f"{entrega.archivo_entrega}"}
                ],
                "temperature": 0.7
            }
        )

        entrega.comentarios = lm_response.json()["choices"][0]["message"]["content"]
        # Actualizar la entrega en la base de datos
        await db.commit()
        await db.refresh(entrega)
        return entrega
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en el proceso de evaluación: {str(e)}")


