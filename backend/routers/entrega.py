from fastapi import APIRouter, Depends, HTTPException, Path, requests, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
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
from datetime import datetime, UTC
import requests
import imghdr  # Para verificar el tipo de imagen
import asyncio
from fastapi.responses import Response, StreamingResponse
from pydantic import BaseModel
import io
import csv
import google.generativeai as genai
import os
import mimetypes
from enum import Enum
from typing import Optional
from abc import ABC, abstractmethod

router = APIRouter()


# Crear un modelo para la entrega
class EntregaCreate(BaseModel):
    textoOcr: str


class ModeloIA(str, Enum):
    GEMINI = "gemini"
    LLAMA = "llama"
    GPT = "gpt"


@router.get("/actividad/{actividad_id}", response_model=List[EntregaResponse])
async def obtener_entregas_actividad(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene todas las entregas de una actividad específica.
    Los profesores pueden ver todas las entregas, los alumnos solo las suyas.

    Parameters:
    - actividad_id (int): ID de la actividad

    Returns:
    - List[EntregaResponse]: Lista de entregas de la actividad

    Raises:
    - HTTPException(404): Si la actividad no existe
    - HTTPException(403): Si el usuario no tiene permisos
    """
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
    """
    Califica una entrega.
    Solo el profesor de la asignatura puede calificar entregas.

    Parameters:
    - entrega_id (int): ID de la entrega
    - calificacion (EntregaUpdate): Datos de la calificación
        - calificacion: Nota numérica
        - comentarios: Comentarios sobre la entrega

    Returns:
    - EntregaResponse: Datos actualizados de la entrega

    Raises:
    - HTTPException(403): Si el usuario no es profesor
    - HTTPException(404): Si la entrega no existe
    """
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


@router.post("/{actividad_id}/entrega", response_model=EntregaResponse)
async def crear_entrega(
    actividad_id: int,
    textoOcr: str = Form(...),
    imagen: UploadFile = File(None),  # Hacemos la imagen opcional
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Crea una nueva entrega para una actividad.
    Solo los alumnos pueden crear entregas.
    La imagen es opcional, pero el texto OCR es obligatorio.

    Parameters:
    - actividad_id (int): ID de la actividad
    - textoOcr (str): Texto de la solución
    - imagen (UploadFile, opcional): Archivo de imagen con la solución

    Returns:
    - EntregaResponse: Datos de la entrega creada

    Raises:
    - HTTPException(403): Si el usuario no es alumno
    - HTTPException(404): Si la actividad no existe
    - HTTPException(400): Si ya existe una entrega
    """
    try:
        # Verificar que el usuario es un alumno
        if current_user.tipo_usuario != TipoUsuario.ALUMNO:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Solo los alumnos pueden crear entregas"
            )
        
        # Verificar que la actividad existe
        query = select(Actividad).where(Actividad.id == actividad_id)
        result = await db.execute(query)
        actividad = result.scalar_one_or_none()
        
        if not actividad:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Actividad no encontrada"
            )

        # Verificar si ya existe una entrega
        query = select(Entrega).where(
            Entrega.actividad_id == actividad_id,
            Entrega.alumno_id == current_user.id
        )
        result = await db.execute(query)
        existing_entrega = result.scalar_one_or_none()
        
        if existing_entrega:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ya existe una entrega para esta actividad"
            )
        
        # Variables para la imagen
        contenido = None
        tipo_imagen = None
        nombre_archivo = None
        
        # Procesar la imagen si se proporciona
        if imagen:
            contenido = await imagen.read()
            if not verificar_tipo_imagen(contenido):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="El archivo debe ser una imagen (JPEG, PNG, GIF o JPG)"
                )
            tipo_imagen = mimetypes.guess_type(imagen.filename)[0]
            nombre_archivo = imagen.filename
        
        # Crear la fecha de entrega sin zona horaria
        fecha_entrega = datetime.now(UTC).replace(tzinfo=None)
        
        # Crear la entrega
        entrega = Entrega(
            texto_ocr=textoOcr,
            actividad_id=actividad_id,
            alumno_id=current_user.id,
            fecha_entrega=fecha_entrega,
            calificacion=None,
            comentarios=None,
            imagen=contenido,
            tipo_imagen=tipo_imagen,
            nombre_archivo=nombre_archivo
        )

        # Guardar en la base de datos
        db.add(entrega)
        await db.commit()
        await db.refresh(entrega)
        
        return entrega
        
    except Exception as e:
        print(f"Error detallado en crear_entrega: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear la entrega: {str(e)}"
        )

@router.get("/imagen/{entrega_id}")
async def obtener_imagen_entrega(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Obtener la entrega
    query = select(Entrega).where(Entrega.id == entrega_id)
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    if not entrega.imagen:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="La entrega no tiene imagen"
        )
    
    # Determinar el tipo de contenido basado en el tipo_imagen
    content_type = f"image/{entrega.tipo_imagen}" if entrega.tipo_imagen else "image/jpeg"
    
    return Response(
        content=entrega.imagen,
        media_type=content_type
    )


# Endpoint para procesar la imagen con OCR usando Gradio
@router.post("/ocr/process-uco", response_model=str)
async def process_image_ocr_uco(
    image: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Procesa una imagen usando el servicio OCR de la UCO.
    Envía la imagen al servidor OCR de la UCO y devuelve el texto extraído.

    Parameters:
    - image (UploadFile): Imagen a procesar (JPEG, PNG, GIF o JPG)

    Returns:
    - str: Texto extraído de la imagen

    Raises:
    - HTTPException(403): Si el usuario no es profesor ni alumno
    - HTTPException(500): Si hay un error al procesar la imagen en el servidor OCR
    """
    # Comprobar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para procesar imágenes OCR"
        )
        
        
    files = {"image": (image.filename, image.file, image.content_type)}
    # TODO Pasar la ip al .env
    ip_ocr = os.getenv("IP_OCR")
    response = requests.post(f"http://{ip_ocr}:8000/predict/", files=files)
    
    # devolver el string de la respuesta que está dentro de prediction en el json
    if response.status_code == 200:
        return response.json()["prediction"]
    else:
        raise HTTPException(status_code=500, detail=f"Error al procesar la imagen: {response.text}")


   

@router.post("/ocr/process-azure", response_model=str)
async def process_image_ocr_azure(
    image: UploadFile = File(...),  
    current_user: Usuario = Depends(get_current_user)
):
    """
    Procesa una imagen usando el servicio OCR de Azure Computer Vision.
    Envía la imagen al servicio de Azure y espera el resultado del análisis.

    Parameters:
    - image (UploadFile): Imagen a procesar (JPEG, PNG, GIF o JPG)

    Returns:
    - str: Texto extraído de la imagen

    Raises:
    - HTTPException(403): Si el usuario no es profesor ni alumno
    - HTTPException(500): Si hay un error en el procesamiento con Azure
    """
    # Comprobar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para procesar imágenes OCR"
        )
    
    headers = {
        'Content-Type': 'application/octet-stream',
        'Ocp-Apim-Subscription-Key': '9TnsLp0OUYoyH25UP7V5n3mb2tSnm54J4WySPu0IKZwEJNY4RnJ7JQQJ99ALAC5RqLJXJ3w3AAAFACOGHcqc'
    }
    
    try:
        # Enviar la imagen como datos binarios
        response = requests.post(
            "https://pruebarafagvision.cognitiveservices.azure.com/vision/v3.2/read/analyze",
            headers=headers,
            data=image.file  # Enviar los bytes directamente
        )
        
        response.raise_for_status()  # Lanzar excepción si hay error
        
        # Obtener la URL de operación del header
        operation_url = response.headers["Operation-Location"]
        
        # Esperar a que el análisis termine
        analysis_result = None
        while True:
            result_response = requests.get(
                operation_url,
                headers={'Ocp-Apim-Subscription-Key': '9TnsLp0OUYoyH25UP7V5n3mb2tSnm54J4WySPu0IKZwEJNY4RnJ7JQQJ99ALAC5RqLJXJ3w3AAAFACOGHcqc'}
            )
            result = result_response.json()
            
            if result.get("status") not in ['notStarted', 'running']:
                analysis_result = result
                break
                
            await asyncio.sleep(1)
            
        texto = analysis_result.get("analyzeResult", {}).get("readResults", [{}])[0].get("lines", [])
        texto = "\n".join([line.get("text", "") for line in texto])
        
        return texto
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al procesar la imagen: {str(e)}")




@router.get("/actividad/{actividad_id}/export-csv")
async def export_submissions_csv(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    if current_user.tipo_usuario != TipoUsuario.PROFESOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los profesores pueden exportar entregas"
        )

    # Obtener la actividad y sus entregas
    query = (
        select(Actividad)
        .options(
            selectinload(Actividad.asignatura)
            .selectinload(Asignatura.inscripciones)
            .selectinload(Inscripcion.alumno),
            selectinload(Actividad.entregas)
            .selectinload(Entrega.alumno)
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

    # Verificar que el profesor tiene acceso a esta actividad
    if actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para exportar estas entregas"
        )

    # Crear el CSV en memoria
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Nombre', 'Apellidos', 'Email', 'Calificación', 'Estado', 'Fecha Entrega'])

    # Para cada alumno inscrito en la asignatura
    for inscripcion in actividad.asignatura.inscripciones:
        alumno = inscripcion.alumno
        # Buscar su entrega
        entrega = next(
            (e for e in actividad.entregas if e.alumno_id == alumno.id),
            None
        )

        writer.writerow([
            alumno.nombre,
            alumno.apellidos,
            alumno.email,
            entrega.calificacion if entrega else "No entregado",
            "Entregado" if entrega else "No entregado",
            entrega.fecha_entrega.strftime("%Y-%m-%d %H:%M:%S") if entrega and entrega.fecha_entrega else "-"
        ])

    # Rebobinar el buffer
    output.seek(0)
    
    # Generar nombre del archivo
    filename = f"entregas_{actividad.titulo}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
    )

    
#Endpoint para obtener las entregas de un alumno en una actividad, es solamente una, no es una lista
@router.get("/alumno/{alumno_id}/actividad/{actividad_id}", response_model=EntregaResponse)
async def obtener_entregas_alumno_actividad(
    alumno_id: int,
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener entregas"
        )
    
    # Obtener las entregas del alumno en la actividad
    query = (
        select(Entrega)
        .join(Entrega.actividad)
        .where(
            and_(
                Entrega.alumno_id == alumno_id,
                Entrega.actividad_id == actividad_id
            )
        )
    )
    
    result = await db.execute(query)
    entregas = result.scalar_one_or_none()
    # Si no lo encuentra, lanzar un error
    if not entregas:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontraron entregas para este alumno en esta actividad"
        )
    # Comprobar que el alumno que llama es el alumno de la entrega
    if current_user.tipo_usuario == TipoUsuario.ALUMNO and alumno_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener las entregas de este alumno"
        )
    
    return entregas

"""  
@router.put("/evaluar-texto-gemini/{entrega_id}", response_model=EntregaResponse)
async def evaluar_texto_gemini(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    
    #comprobar que el usuario esta logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para evaluar entregas"
        )
    
    
    # Obtener la entrega
    query = select(Entrega).where(Entrega.id == entrega_id)
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    # Obtener la actividad
    query = select(Actividad).where(Actividad.id == entrega.actividad_id)
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    if not actividad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Actividad no encontrada"
        )
        
    # Obtener el texto de la entrega
    solucion = entrega.texto_ocr
    
    # Obtener el lenguaje de la actividad
    lenguaje = actividad.lenguaje_programacion
    # Obtener los parametros de evaluacion
    parametros = actividad.parametros_evaluacion
    
    if lenguaje != None and parametros != None:
        try:
            # Configurar la API de Gemini
            genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
            
            # Crear el modelo
            model = genai.GenerativeModel("gemini-1.5-flash")
            
            # Generar la respuesta
            prompt = f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo,pero muy breve y quiero que también me des la nota de la entrega en formato: Nota: n/10. La actividad es {actividad.titulo} el enunciado es el siguiente: {actividad.descripcion}. La solución es: {solucion}. Al final, quiero que me des la nota de la entrega en formato: Nota: n/10. Si no tiene nada que ver con la actividad, escribe que no tiene nada que ver con la actividad y pon de nota 0. La solución debe estar en {lenguaje} y los criterios que tendras en cuenta para evaluar la solución son: {parametros}"
            
            response = model.generate_content(prompt)
            
            entrega.comentarios = response.text
            
            # Extraer la nota del texto y convertirla a float
            try:
                nota_texto = response.text.split("Nota: ")[1].split("/")[0]
                entrega.calificacion = float(nota_texto)  # Convertir a float
            except (IndexError, ValueError):
                # Si no se puede extraer la nota, establecer un valor por defecto
                entrega.calificacion = 0.0
            
            await db.commit()
            await db.refresh(entrega)
            return entrega
        except Exception as e:
            print(f"Error detallado: {str(e)}")  # Para debugging
            raise HTTPException(status_code=500, detail=f"Error al llamar al LLM: {str(e)}")
    elif lenguaje != None and parametros == None:
        try:
            # Configurar la API de Gemini
            genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
            
            # Crear el modelo
            model = genai.GenerativeModel("gemini-1.5-flash")
            
            # Generar la respuesta
            prompt = f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo,pero muy breve y quiero que también me des la nota de la entrega en formato: Nota: n/10. La actividad es {actividad.titulo} el enunciado es el siguiente: {actividad.descripcion}. La solución es: {solucion}. Al final, quiero que me des la nota de la entrega en formato: Nota: n/10. Si no tiene nada que ver con la actividad, escribe que no tiene nada que ver con la actividad y pon de nota 0. La solución debe estar en {lenguaje}."
            
            response = model.generate_content(prompt)
            
            entrega.comentarios = response.text
            
            # Extraer la nota del texto y convertirla a float
            try:
                nota_texto = response.text.split("Nota: ")[1].split("/")[0]
                entrega.calificacion = float(nota_texto)  # Convertir a float
            except (IndexError, ValueError):
                # Si no se puede extraer la nota, establecer un valor por defecto
                entrega.calificacion = 0.0
            
            await db.commit()
            await db.refresh(entrega)
            return entrega
        except Exception as e:
            print(f"Error detallado: {str(e)}")  # Para debugging
            raise HTTPException(status_code=500, detail=f"Error al llamar al LLM: {str(e)}")
    elif lenguaje == None and parametros != None:
        try:
            # Configurar la API de Gemini
            genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
            
            # Crear el modelo
            model = genai.GenerativeModel("gemini-1.5-flash")
            
            # Generar la respuesta
            prompt = f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo,pero muy breve y quiero que también me des la nota de la entrega en formato: Nota: n/10. La actividad es {actividad.titulo} el enunciado es el siguiente: {actividad.descripcion}. La solución es: {solucion}. Al final, quiero que me des la nota de la entrega en formato: Nota: n/10. Si no tiene nada que ver con la actividad, escribe que no tiene nada que ver con la actividad y pon de nota 0. Los criterios que tendras en cuenta para evaluar la solución son: {parametros}"
            
            response = model.generate_content(prompt)
            
            entrega.comentarios = response.text
            
            # Extraer la nota del texto y convertirla a float
            try:
                nota_texto = response.text.split("Nota: ")[1].split("/")[0]
                entrega.calificacion = float(nota_texto)  # Convertir a float
            except (IndexError, ValueError):
                # Si no se puede extraer la nota, establecer un valor por defecto
                entrega.calificacion = 0.0
            
            await db.commit()
            await db.refresh(entrega)
            return entrega
        except Exception as e:
            print(f"Error detallado: {str(e)}")  # Para debugging
            raise HTTPException(status_code=500, detail=f"Error al llamar al LLM: {str(e)}")
    else:
        try:
            # Configurar la API de Gemini
            genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
            
            # Crear el modelo
            model = genai.GenerativeModel("gemini-1.5-flash")
            
            # Generar la respuesta
            prompt = f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo,pero muy breve y quiero que también me des la nota de la entrega en formato: Nota: n/10. La actividad es {actividad.titulo} el enunciado es el siguiente: {actividad.descripcion}. La solución es: {solucion}. Al final, quiero que me des la nota de la entrega en formato: Nota: n/10. Si no tiene nada que ver con la actividad, escribe que no tiene nada que ver con la actividad y pon de nota 0."
            
            response = model.generate_content(prompt)
            
            entrega.comentarios = response.text
            
            # Extraer la nota del texto y convertirla a float
            try:
                nota_texto = response.text.split("Nota: ")[1].split("/")[0]
                entrega.calificacion = float(nota_texto)  # Convertir a float
            except (IndexError, ValueError):
                # Si no se puede extraer la nota, establecer un valor por defecto
                entrega.calificacion = 0.0
            
            await db.commit()
            await db.refresh(entrega)
            return entrega
        except Exception as e:
            print(f"Error detallado: {str(e)}")  # Para debugging
            raise HTTPException(status_code=500, detail=f"Error al llamar al LLM: {str(e)}")

"""
    
#Endpoint para obtener la entrega dado un id de la entrega
@router.get("/{entrega_id}", response_model=EntregaResponse)
async def obtener_entrega(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Comprobar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener entregas"
        )
    
    # Obtener la entrega con todas sus relaciones
    query = (
        select(Entrega)
        .options(
            selectinload(Entrega.actividad)
            .selectinload(Actividad.asignatura)
            .selectinload(Asignatura.profesor),
            selectinload(Entrega.alumno)
        )
        .where(Entrega.id == entrega_id)
    )
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    # Verificar permisos
    if current_user.tipo_usuario == TipoUsuario.ALUMNO and entrega.alumno_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener esta entrega"
        )
    elif current_user.tipo_usuario == TipoUsuario.PROFESOR and entrega.actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener esta entrega"
        )
    
    return entrega
    
    
    
    
@router.post("/pruebaGemini", response_model=str)
async def pruebaGemini(
    prompt: str
):
    client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
    response = client.models.generate_content(
        model = "gemini-1.5-flash",
        contents = [prompt])
    return response.text



@router.get("/ocr-azure/{entrega_id}")
async def obtener_ocr_entrega(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
     # Obtener la entrega
    query = select(Entrega).where(Entrega.id == entrega_id)
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    # Verificar permisos
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.id != entrega.alumno_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver esta entrega"
        )
    
    # Configurar los headers para la API de Azure
    headers = {
        'Content-Type': 'application/octet-stream',
        'Ocp-Apim-Subscription-Key': '9TnsLp0OUYoyH25UP7V5n3mb2tSnm54J4WySPu0IKZwEJNY4RnJ7JQQJ99ALAC5RqLJXJ3w3AAAFACOGHcqc'
    }
    
    try:
        # Enviar la imagen como datos binarios
        response = requests.post(
            "https://pruebarafagvision.cognitiveservices.azure.com/vision/v3.2/read/analyze",
            headers=headers,
            data=entrega.imagen  # Enviar los bytes directamente
        )
        
        response.raise_for_status()  # Lanzar excepción si hay error
        
        # Obtener la URL de operación del header
        operation_url = response.headers["Operation-Location"]
        
        # Esperar a que el análisis termine
        analysis_result = None
        while True:
            result_response = requests.get(
                operation_url,
                headers={'Ocp-Apim-Subscription-Key': '9TnsLp0OUYoyH25UP7V5n3mb2tSnm54J4WySPu0IKZwEJNY4RnJ7JQQJ99ALAC5RqLJXJ3w3AAAFACOGHcqc'}
            )
            result = result_response.json()
            
            if result.get("status") not in ['notStarted', 'running']:
                analysis_result = result
                break
                
            await asyncio.sleep(1)
            
        texto = analysis_result.get("analyzeResult", {}).get("readResults", [{}])[0].get("lines", [])
        texto = "\n".join([line.get("text", "") for line in texto])
        
        entrega.texto_ocr = texto
        await db.commit()
        await db.refresh(entrega)

        return texto
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al procesar la imagen: {str(e)}"
        )
        
        
        
@router.put("/evaluar-ocr/{entrega_id}", response_model=EntregaResponse)
async def evaluar_entrega(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    # comprobar que el usuario esta logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para evaluar entregas"
        )
    
    #obtener la entrega
    query = select(Entrega).where(Entrega.id == entrega_id and Entrega.alumno_id == current_user.id)
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    #obtener la actividad
    query = select(Actividad).where(Actividad.id == entrega.actividad_id)
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
   
    
    if entrega.imagen is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No has subido ningún archivo"
        )

    #obtener el texto de la imagen
    texto = await obtener_ocr_entrega(entrega_id, db, current_user)

    
    #conectar con la API y mandarle la entrega
    try:

        # Enviar el texto al LM para evaluación
        #TODO: Cambiar la URL por la del server de la uco y el puerto que no se cual es 
        lm_response = requests.post(
            "http://192.168.117.196:5000/v1/chat/completions",  # Ajusta la URL según tu configuración de LMStudio
            json={

                "messages": [
                {"role": "system", "content": f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo en base al enunciado siguiente: {actividad.descripcion}"},
                {"role": "user", "content": f"{texto}"}
                ],
                "temperature": 0.7,
            }
        )
        
        # Verificar si la respuesta fue exitosa
        lm_response.raise_for_status()  # Lanza una excepción si la respuesta no es exitosa

        entrega.comentarios = lm_response.json()["choices"][0]["message"]["content"]
        # Actualizar la entrega en la base de datos
        await db.commit()
        await db.refresh(entrega)
        return entrega
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en el proceso de evaluación: {str(e)}")

from abc import ABC, abstractmethod

class EvaluadorIA(ABC):
    @abstractmethod
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        pass

    def extraer_nota(self, texto: str) -> float:
        try:
            nota_texto = texto.split("Nota: ")[1].split("/")[0]
            return float(nota_texto)
        except (IndexError, ValueError):
            return 0.0

class GeminiEvaluador(EvaluadorIA):
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        nota = self.extraer_nota(response.text)
        return response.text, nota

class LlamaEvaluador(EvaluadorIA):
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        response = requests.post(
            f"{os.getenv('LLAMA_API_URL', 'http://192.168.117.196:5000')}/v1/chat/completions",
            json={
                "messages": [
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": solucion}
                ],
                "temperature": 0.7,
            }
        )
        response_text = response.json()["choices"][0]["message"]["content"]
        nota = self.extraer_nota(response_text)
        return response_text, nota

class GPTEvaluador(EvaluadorIA):
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        # Configura tu API key de OpenAI
        openai_api_key = os.getenv("OPENAI_API_KEY")
        
        try:
            response = requests.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {openai_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-3.5-turbo",  # o el modelo que prefieras
                    "messages": [
                        {"role": "system", "content": prompt},
                        {"role": "user", "content": solucion}
                    ],
                    "temperature": 0.7
                }
            )
            
            response_text = response.json()["choices"][0]["message"]["content"]
            nota = self.extraer_nota(response_text)
            return response_text, nota
            
        except Exception as e:
            print(f"Error en GPT: {str(e)}")
            raise

class OllamaEvaluador(EvaluadorIA):
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        try:
            # Configurar la URL de tu API Multi-LLM
            api_url = os.getenv("OLLAMA_API_URL", "http://localhost:8001")
            
            # Hacer la petición a tu API
            response = requests.post(
                f"{api_url}/chat/gemma3",
                json={
                    "model": "gemma3",  # Usar el modelo gemma3
                    "prompt": prompt,    # Enviar el prompt construido
                    "max_tokens": 1024,  # Parámetros predeterminados
                    "temperature": 0.7,
                    "top_p": 0.6, # top_p es la probabilidad acumulada de tokens seleccionados para la respuesta, 0.9 es el 90% de probabilidad
                    "top_k": 30 # top_k es el número de tokens considerados para la respuesta, 40 es el 40% de probabilidad
                }
            )
            
   
            
            response.raise_for_status()  # Lanzar excepción si hay error
            
            # Extraer la respuesta del formato de tu API
            response_data = response.json()
            response_text = response_data.get("response", "")
            
            # Extraer la nota
            nota = self.extraer_nota(response_text)
            return response_text, nota
            
        except Exception as e:
            print(f"Error en Ollama API: {str(e)}")
            raise



"""
            valores son adecuados para un evaluador:
            top_p = 0.9: Bueno para evaluación porque permite cierta creatividad en las explicaciones mientras mantiene un enfoque en las respuestas más probables.
            top_k = 40: Adecuado para asegurar respuestas coherentes y variadas.
            Para una herramienta de evaluación académica, estos valores proporcionan un buen equilibrio entre:
            Consistencia (necesaria para evaluaciones justas)
            Creatividad (útil para proporcionar feedback constructivo)
            Precisión (importante para la valoración del trabajo)
            Si quisieras ajustarlos:
            Para respuestas más consistentes y directas: reduce a top_p=0.7, top_k=20
            Para feedback más detallado y diverso: mantén los actuales o aumenta ligeramente
"""


class EvaluadorFactory:
    _evaluadores = {
        "gemini": GeminiEvaluador,
        "llama": LlamaEvaluador,
        "gpt": GPTEvaluador,
        "ollama": OllamaEvaluador
    }

    @classmethod
    def crear_evaluador(cls) -> EvaluadorIA:
        modelo = os.getenv("MODEL_IA", "gemini").lower()
        print(f"Usando modelo: {modelo}")
        evaluador_class = cls._evaluadores.get(modelo, GPTEvaluador)
        return evaluador_class()



@router.put("/evaluar-texto/{entrega_id}", response_model=EntregaResponse)
async def evaluar_texto(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    # Verificaciones de permisos
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para evaluar entregas"
        )
    
    # Obtener la entrega y la actividad
    query = select(Entrega).where(Entrega.id == entrega_id)
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    query = select(Actividad).where(Actividad.id == entrega.actividad_id)
    result = await db.execute(query)
    actividad = result.scalar_one_or_none()
    
    if not actividad:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Actividad no encontrada"
        )
    
    try:
        # Crear el evaluador según la configuración
        evaluador = EvaluadorFactory.crear_evaluador()
        
        # Preparar el prompt
        prompt = construir_prompt(actividad, entrega.texto_ocr)
        
        # Evaluar la entrega
        comentarios, nota = await evaluador.evaluar(prompt, actividad, entrega.texto_ocr)
        
        # Actualizar la entrega
        entrega.comentarios = comentarios
        entrega.calificacion = nota
        
        await db.commit()
        await db.refresh(entrega)
        return entrega
        
    except Exception as e:
        print(f"Error detallado: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error al evaluar la entrega: {str(e)}")

def construir_prompt(actividad: Actividad, solucion: str) -> str:
    prompt = (
        f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback "
        f"constructivo, pero muy breve y quiero que también me des la nota de la entrega en formato: "
        f"Nota: n/10. La actividad es {actividad.titulo} el enunciado es el siguiente: "
        f"{actividad.descripcion}. La solución que se proporciona es: {solucion}. "
        f"Recuerda, sé estrictamente con la nota, no seas tan generoso, si hace algo que no se pide, indicalo y disminuye la nota."
    )
    
    if actividad.lenguaje_programacion:
        prompt += f" La solución debe estar en {actividad.lenguaje_programacion}."
    if actividad.parametros_evaluacion:
        prompt += f" Los criterios que tendrás en cuenta para evaluar la solución son: {actividad.parametros_evaluacion}"
    
    return prompt

@router.get("/alumno/{alumno_id}/asignatura/{asignatura_id}", response_model=List[EntregaResponse])
async def obtener_entregas_alumno_asignatura(
    alumno_id: int,
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene todas las entregas de un alumno en una asignatura específica.
    Los profesores pueden ver las entregas de cualquier alumno en sus asignaturas.
    Los alumnos solo pueden ver sus propias entregas.
    """
    # Verificar permisos
    if current_user.tipo_usuario == TipoUsuario.ALUMNO and current_user.id != alumno_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver las entregas de otro alumno"
        )

    # Obtener las entregas con sus relaciones
    query = (
        select(Entrega)
        .join(Entrega.actividad)
        .join(Actividad.asignatura)
        .where(
            and_(
                Entrega.alumno_id == alumno_id,
                Asignatura.id == asignatura_id
            )
        )
        .options(
            selectinload(Entrega.actividad),
            selectinload(Entrega.alumno)
        )
    )

    # Si es profesor, verificar que la asignatura le pertenece
    if current_user.tipo_usuario == TipoUsuario.PROFESOR:
        query = query.where(Asignatura.profesor_id == current_user.id)

    result = await db.execute(query)
    entregas = result.scalars().all()

    return entregas

def verificar_tipo_imagen(contenido: bytes) -> bool:
    # Verificar los primeros bytes del archivo para determinar si es una imagen
    signatures = {
        b'\xFF\xD8\xFF': 'image/jpeg',  # JPEG
        b'\x89PNG\r\n': 'image/png',    # PNG
        b'GIF87a': 'image/gif',         # GIF
        b'GIF89a': 'image/gif',         # GIF
    }
    
    for signature, mime_type in signatures.items():
        if contenido.startswith(signature):
            return True
    return False

@router.get("/download/{entrega_id}")
async def descargar_imagen_entrega(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Descarga la imagen de una entrega específica.
    Solo el profesor de la asignatura o el alumno que hizo la entrega pueden descargar la imagen.

    Parameters:
    - entrega_id (int): ID de la entrega

    Returns:
    - Response: Imagen con headers para descarga

    Raises:
    - HTTPException(404): Si la entrega no existe o no tiene imagen
    - HTTPException(403): Si el usuario no tiene permisos
    """
    # Obtener la entrega con sus relaciones
    query = (
        select(Entrega)
        .options(
            selectinload(Entrega.actividad)
            .selectinload(Actividad.asignatura)
        )
        .where(Entrega.id == entrega_id)
    )
    result = await db.execute(query)
    entrega = result.scalar_one_or_none()
    
    if not entrega:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrega no encontrada"
        )
    
    if not entrega.imagen:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="La entrega no tiene imagen"
        )
    
    # Verificar permisos
    if current_user.tipo_usuario == TipoUsuario.ALUMNO and entrega.alumno_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para descargar esta imagen"
        )
    elif current_user.tipo_usuario == TipoUsuario.PROFESOR and entrega.actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para descargar esta imagen"
        )
    
    # Determinar el tipo de contenido
    content_type = entrega.tipo_imagen if entrega.tipo_imagen else "application/octet-stream"
    
    return Response(
        content=entrega.imagen,
        media_type=content_type,
        headers={
            "Content-Disposition": f'attachment; filename="{entrega.nombre_archivo or "imagen"}"'
        }
    )
