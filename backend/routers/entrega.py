import os
import re
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
from datetime import datetime
import requests
import imghdr  # Para verificar el tipo de imagen
import asyncio
from fastapi.responses import Response
from pydantic import BaseModel
from google import genai
router = APIRouter()

# Crear un modelo para la entrega
class EntregaCreate(BaseModel):
    textoOcr: str

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
@router.put("/evaluarLMS/{entrega_id}", response_model=EntregaResponse)
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
        lm_response = requests.post(
            "http://localhost:1234/v1/chat/completions",  # Ajusta la URL según tu configuración de LMStudio
            json={
                "model": "deepseek-coder-v2-lite-instruct",
                "messages": [
                { "role": "system", "content": f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo en base al enunciado siguiente: {actividad.descripcion}. También proporciona la nota de la entrega en el formato: Nota: [nota]"},
                { "role": "user", "content": f"{texto}"}
                ],
                "temperature": 0.7,
                "max_tokens": -1,
                "stream": "false"

            }
        )
        
        # Verificar si la respuesta fue exitosa
        lm_response.raise_for_status()  # Lanza una excepción si la respuesta no es exitosa

        entrega.comentarios = lm_response.json()["choices"][0]["message"]["content"]
        
        #buscar donde ponga nota:
        nota = re.search(r'Nota: (\d+)', entrega.comentarios)
        if nota:
            entrega.calificacion = int(nota.group(1))
        else:
            entrega.calificacion = 0    
        # Actualizar la entrega en la base de datos
        await db.commit()
        await db.refresh(entrega)
        return entrega



    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en el proceso de evaluación: {str(e)}")

@router.post("/{actividad_id}/entrega", response_model=EntregaResponse)
async def crear_entrega(
    actividad_id: int,
    textoOcr: str = Form(...),
    imagen: UploadFile = File(...),  # Cambiado a requerido y especificado como File
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
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
        
        # Procesar la imagen
        contenido = await imagen.read()
        tipo_imagen = imghdr.what(None, contenido)
        
        if tipo_imagen not in ['jpeg', 'png', 'gif', 'jpg']:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El archivo debe ser una imagen (JPEG, PNG, GIF o JPG)"
            )
        
        # Crear la entrega con todos los campos
        entrega = Entrega(
            texto_ocr=textoOcr,
            actividad_id=actividad_id,
            alumno_id=current_user.id,
            fecha_entrega=datetime.utcnow(),
            calificacion=None,
            comentarios=None,
            imagen=contenido,
            tipo_imagen=tipo_imagen,
            nombre_archivo=imagen.filename
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

@router.get("/ocr/{entrega_id}")
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
    
    # Conectar con la API de Gemini
    try:
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        response = client.models.generate_content(
            model = "gemini-1.5-flash",
            contents = [
                f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback constructivo,pero muy breve y quiero que también me des la nota de la entrega en formato: Nota: n/10, en base al enunciado siguiente: {actividad.descripcion}. La solución es: {solucion}. Al final, quiero que me des la nota de la entrega en formato: Nota: n/10"
            ]
        )
        
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
    
@router.post("/ocr/process", response_model=str)
async def process_image_ocr(
    image: UploadFile = File(...),  
    current_user: Usuario = Depends(get_current_user)
):
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



@router.post("/pruebaGemini", response_model=str)
async def pruebaGemini(
    prompt: str
):
    client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
    response = client.models.generate_content(
        model = "gemini-1.5-flash",
        contents = [prompt])
    return response.text

# Obtener entregas de un alumno en una asignatura
@router.get("/alumno/{alumno_id}/asignatura/{asignatura_id}", response_model=List[EntregaResponse])
async def obtener_entregas_alumno_asignatura(
    alumno_id: int,
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    # Comprobar que el usuario está logueado
    if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener entregas"
        )
        
    # Comprobar que el alumno es quien esta haciendo la petición
    if current_user.tipo_usuario == TipoUsuario.ALUMNO and alumno_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para obtener las entregas de este alumno"
        )
    
    # Obtener las entregas del alumno en la asignatura
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
    )
    result = await db.execute(query)
    entregas = result.scalars().all()
    
    return entregas

    

