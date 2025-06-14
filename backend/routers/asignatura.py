from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload, joinedload
from typing import List
from models.actividad import Actividad
from models.entrega import Entrega
from schemas.usuario import UsuarioResponse, UsuarioBase
from database import get_db
from models.asignatura import Asignatura
from models.usuario import Usuario, TipoUsuario
from schemas.asignatura import AsignaturaCreate, AsignaturaResponse
from security import get_current_user
from models.inscripcion import Inscripcion
from fastapi.responses import Response
import csv
from io import StringIO
from sqlalchemy import func
from passlib.context import CryptContext

router = APIRouter()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@router.post("/", response_model=AsignaturaResponse)
async def crear_asignatura(
    asignatura: AsignaturaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Crea una nueva asignatura.
    Solo los profesores pueden crear asignaturas.

    Parameters:
    - asignatura (AsignaturaCreate): Datos de la asignatura
        - nombre: Nombre de la asignatura
        - descripcion: Descripción de la asignatura
        - codigo_acceso: Código de acceso para inscripción

    Returns:
    - AsignaturaResponse: Datos de la asignatura creada

    Raises:
    - HTTPException(403): Si el usuario no es profesor
    """
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden crear asignaturas"
        )
    
    # Hashear el código de acceso
    hashed_codigo = pwd_context.hash(asignatura.codigo_acceso)
    
    # Crear nueva asignatura
    db_asignatura = Asignatura(
        nombre=asignatura.nombre,
        descripcion=asignatura.descripcion,
        profesor_id=current_user.id,
        codigo_acceso=hashed_codigo
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
    """
    Obtiene la lista de asignaturas.
    Para profesores: muestra solo sus asignaturas.
    Para alumnos: muestra todas las asignaturas disponibles.

    Returns:
    - List[AsignaturaResponse]: Lista de asignaturas

    Raises:
    - HTTPException(401): Si el usuario no está autenticado
    """
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
    """
    Obtiene los detalles de una asignatura específica.

    Parameters:
    - asignatura_id (int): ID de la asignatura

    Returns:
    - AsignaturaResponse: Detalles de la asignatura

    Raises:
    - HTTPException(404): Si la asignatura no existe
    - HTTPException(401): Si el usuario no está autenticado
    """
    # Modificar la consulta para incluir la carga de la relación profesor
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
    return asignatura

@router.put("/{asignatura_id}", response_model=AsignaturaResponse)
async def actualizar_asignatura(
    asignatura_id: int,
    asignatura_update: AsignaturaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Actualiza los datos de una asignatura.
    Solo el profesor propietario puede actualizar la asignatura.

    Parameters:
    - asignatura_id (int): ID de la asignatura
    - asignatura_update (AsignaturaCreate): Nuevos datos de la asignatura
        - nombre: Nuevo nombre
        - descripcion: Nueva descripción
        - codigo_acceso: Nuevo código de acceso (opcional)

    Returns:
    - AsignaturaResponse: Datos actualizados de la asignatura

    Raises:
    - HTTPException(404): Si la asignatura no existe
    - HTTPException(403): Si el usuario no es el profesor de la asignatura
    """
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
    db_asignatura.nombre = asignatura_update.nombre
    db_asignatura.descripcion = asignatura_update.descripcion
    if asignatura_update.codigo_acceso:
        db_asignatura.codigo_acceso = pwd_context.hash(asignatura_update.codigo_acceso)
    
    await db.commit()
    
    # Volver a cargar la asignatura con la relación del profesor para la respuesta
    query = (
        select(Asignatura)
        .where(Asignatura.id == asignatura_id)
        .options(selectinload(Asignatura.profesor))
    )
    result = await db.execute(query)
    db_asignatura = result.scalar_one()
    
    return db_asignatura

@router.delete("/{asignatura_id}")
async def eliminar_asignatura(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Elimina una asignatura.
    Solo el profesor propietario puede eliminar la asignatura.

    Parameters:
    - asignatura_id (int): ID de la asignatura a eliminar

    Returns:
    - dict: Mensaje de confirmación

    Raises:
    - HTTPException(404): Si la asignatura no existe
    - HTTPException(403): Si el usuario no es el profesor de la asignatura
    """
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


# Endpoint para obtener la lista de alumnos inscritos en una asignatura
@router.get("/{asignatura_id}/alumnos", response_model=List[UsuarioResponse])
async def obtener_alumnos_asignatura(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene la lista de alumnos inscritos en una asignatura.
    Accesible para el profesor de la asignatura y alumnos inscritos.

    Parameters:
    - asignatura_id (int): ID de la asignatura

    Returns:
    - List[UsuarioResponse]: Lista de alumnos inscritos

    Raises:
    - HTTPException(404): Si la asignatura no existe
    - HTTPException(403): Si el usuario no tiene permisos para ver la lista
    """
    # Verificar que el usuario es profesor o alumno
    if current_user.tipo_usuario not in [TipoUsuario.PROFESOR, TipoUsuario.ALUMNO]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores y alumnos pueden obtener la lista de alumnos"
        )
    
    # Obtener la asignatura con sus inscripciones
    query_asignatura = (
        select(Asignatura)
        .where(Asignatura.id == asignatura_id)
        .options(selectinload(Asignatura.inscripciones))
    )
    result_asignatura = await db.execute(query_asignatura)
    asignatura = result_asignatura.scalar_one_or_none()
    
    if not asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    
    # Verificar que el profesor es el dueño de la asignatura o que el alumno está inscrito
    if (current_user.tipo_usuario == TipoUsuario.PROFESOR and asignatura.profesor_id != current_user.id) or \
       (current_user.tipo_usuario == TipoUsuario.ALUMNO and not any(i.alumno_id == current_user.id for i in asignatura.inscripciones)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver los alumnos de esta asignatura"
        )
    
    # Obtener los alumnos inscritos
    query = (
        select(Usuario)
        .join(Inscripcion, Inscripcion.alumno_id == Usuario.id)
        .where(
            Inscripcion.asignatura_id == asignatura_id,
            Usuario.tipo_usuario == TipoUsuario.ALUMNO
        )
    )
    
    result = await db.execute(query)
    alumnos = result.scalars().all()
    
    return alumnos
    

@router.get("/{asignatura_id}/export-csv")
async def export_subject_csv(
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Exporta las calificaciones de una asignatura en formato CSV.
    Solo accesible para el profesor de la asignatura.

    Parameters:
    - asignatura_id (int): ID de la asignatura

    Returns:
    - Response: Archivo CSV con las calificaciones
        Incluye: nombre alumno, apellidos, email, actividades y notas

    Raises:
    - HTTPException(404): Si la asignatura no existe
    - HTTPException(403): Si el usuario no es el profesor de la asignatura
    """
    # Verificar que el usuario es profesor
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden exportar las calificaciones"
        )
    
    # Obtener la asignatura y verificar que existe
    query_asignatura = select(Asignatura).where(Asignatura.id == asignatura_id)
    result_asignatura = await db.execute(query_asignatura)
    asignatura = result_asignatura.scalar_one_or_none()
    
    if not asignatura:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asignatura no encontrada"
        )
    
    # Verificar que el profesor es el dueño de la asignatura
    if asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para exportar las calificaciones de esta asignatura"
        )

    # Obtener todos los alumnos inscritos
    query_alumnos = (
        select(Usuario)
        .join(Inscripcion, Inscripcion.alumno_id == Usuario.id)
        .where(
            Inscripcion.asignatura_id == asignatura_id,
            Usuario.tipo_usuario == TipoUsuario.ALUMNO
        )
    )
    result_alumnos = await db.execute(query_alumnos)
    alumnos = result_alumnos.scalars().all()

    # Obtener todas las actividades de la asignatura
    query_actividades = select(Actividad).where(Actividad.asignatura_id == asignatura_id)
    result_actividades = await db.execute(query_actividades)
    actividades = result_actividades.scalars().all()

    # Crear el CSV
    output = StringIO()
    writer = csv.writer(output)
    
    # Escribir encabezados
    headers = ['Nombre', 'Apellidos', 'Email']
    for actividad in actividades:
        headers.extend([
            f'{actividad.titulo} - Estado',
            f'{actividad.titulo} - Nota'
        ])
    headers.append('Nota Media')
    writer.writerow(headers)

    # Para cada alumno
    for alumno in alumnos:
        row = [alumno.nombre, alumno.apellidos, alumno.email]
        total_notas = 0
        total_actividades = len(actividades)  # Todas las actividades cuentan

        # Para cada actividad
        for actividad in actividades:
            # Obtener la entrega del alumno para esta actividad
            query_entrega = (
                select(Entrega)
                .where(
                    Entrega.actividad_id == actividad.id,
                    Entrega.alumno_id == alumno.id
                )
            )
            result_entrega = await db.execute(query_entrega)
            entrega = result_entrega.scalar_one_or_none()

            if entrega and entrega.calificacion is not None:
                row.extend(['Entregado', str(entrega.calificacion)])
                total_notas += entrega.calificacion
            else:
                # Si no hay entrega o no está calificada, cuenta como 0
                row.extend(['No entregado' if not entrega else 'Sin calificar', '0'])
                # No sumamos nada a total_notas (equivalente a sumar 0)

        # Calcular la nota media usando el total de actividades
        nota_media = total_notas / total_actividades if total_actividades > 0 else 0
        row.append(f'{nota_media:.2f}')
        
        writer.writerow(row)

    # Preparar la respuesta
    output.seek(0)
    response = Response(
        content=output.getvalue(),
        media_type='text/csv',
        headers={
            'Content-Disposition': f'attachment; filename=calificaciones_{asignatura_id}.csv'
        }
    )
    
    return response
    

