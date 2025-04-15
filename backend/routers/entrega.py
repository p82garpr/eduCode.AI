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
import base64
from services.ocr_service import OCRServiceFactory, QWEN3BOCRService, AzureOCRService, OllamaGemma3OCRService
from services.evaluador_service import construir_prompt, EvaluadorFactory, EvaluadorIA

router = APIRouter()


# Crear un modelo para la entrega
class EntregaCreate(BaseModel):
    textoOcr: str

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
    """
    Obtiene la imagen de una entrega específica.
    El profesor de la asignatura y el alumno que realizó la entrega pueden acceder a la imagen.

    Parameters:
    - entrega_id (int): ID de la entrega

    Returns:
    - Response: Imagen de la entrega con el content-type apropiado

    Raises:
    - HTTPException(404): Si la entrega o la imagen no existe
    - HTTPException(403): Si el usuario no tiene permisos
    """
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
    
    # Verificar permisos
    if current_user.tipo_usuario == TipoUsuario.ALUMNO and entrega.alumno_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver esta imagen"
        )
    elif current_user.tipo_usuario == TipoUsuario.PROFESOR and entrega.actividad.asignatura.profesor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para ver esta imagen"
        )
    
    # Determinar el tipo de contenido basado en el tipo_imagen
    content_type = f"image/{entrega.tipo_imagen}" if entrega.tipo_imagen else "image/jpeg"
    
    return Response(
        content=entrega.imagen,
        media_type=content_type
    )


@router.post("/ocr/process-azure", response_model=str)
async def process_image_ocr_azure(
    image: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Procesa una imagen usando el servicio OCR de Azure Computer Vision.
    Extrae el texto de la imagen proporcionada.

    Parameters:
    - image (UploadFile): Archivo de imagen a procesar (JPEG, PNG, GIF o JPG)

    Returns:
    - str: Texto extraído de la imagen

    Raises:
    - HTTPException(403): Si el usuario no tiene permisos
    - HTTPException(400): Si el formato de imagen no es válido
    - HTTPException(500): Si hay un error en el procesamiento con Azure
    """
    # Usar el servicio OCR de Azure a través del Factory
    ocr_service = AzureOCRService()
    return await ocr_service.process_image(image, current_user)

@router.post("/ocr/process-ollama", response_model=str)
async def process_image_ocr_ollama(
    image: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Procesa una imagen usando el servicio OCR de Ollama.
    Extrae el texto de la imagen proporcionada usando el modelo Gemma3.

    Parameters:
    - image (UploadFile): Archivo de imagen a procesar (JPEG, PNG, GIF o JPG)

    Returns:
    - str: Texto extraído de la imagen

    Raises:
    - HTTPException(403): Si el usuario no tiene permisos
    - HTTPException(400): Si el formato de imagen no es válido
    - HTTPException(500): Si hay un error en el procesamiento con Ollama
    """
    # Usar el servicio OCR de Ollama a través del Factory
    ocr_service = OllamaGemma3OCRService()
    return await ocr_service.process_image(image, current_user)

@router.post("/ocr/process", response_model=str)
async def process_image_ocr(
    image: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Procesa una imagen usando el servicio OCR predeterminado configurado.
    El servicio específico se determina mediante la configuración del sistema.

    Parameters:
    - image (UploadFile): Archivo de imagen a procesar (JPEG, PNG, GIF o JPG)

    Returns:
    - str: Texto extraído de la imagen

    Raises:
    - HTTPException(403): Si el usuario no tiene permisos
    - HTTPException(400): Si el formato de imagen no es válido
    - HTTPException(500): Si hay un error en el procesamiento OCR
    """
    # Obtener el servicio OCR a través del Factory
    ocr_service = OCRServiceFactory.get_ocr_service()
    return await ocr_service.process_image(image, current_user)

@router.get("/actividad/{actividad_id}/export-csv")
async def export_submissions_csv(
    actividad_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Exporta todas las entregas de una actividad a un archivo CSV.
    Solo disponible para profesores.

    Parameters:
    - actividad_id (int): ID de la actividad

    Returns:
    - StreamingResponse: Archivo CSV con las entregas

    Raises:
    - HTTPException(403): Si el usuario no es profesor
    - HTTPException(404): Si la actividad no existe
    """
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
    """
    Obtiene la entrega de un alumno para una actividad específica.
    Los profesores pueden ver cualquier entrega, los alumnos solo las suyas.

    Parameters:
    - alumno_id (int): ID del alumno
    - actividad_id (int): ID de la actividad

    Returns:
    - EntregaResponse: Datos de la entrega

    Raises:
    - HTTPException(403): Si el usuario no tiene permisos
    - HTTPException(404): Si no existe la entrega
    """
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

@router.get("/{entrega_id}", response_model=EntregaResponse)
async def obtener_entrega(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene los detalles completos de una entrega específica.
    Los profesores pueden ver las entregas de sus asignaturas, los alumnos solo sus propias entregas.

    Parameters:
    - entrega_id (int): ID de la entrega a consultar

    Returns:
    - EntregaResponse: Datos completos de la entrega, incluyendo información de la actividad, asignatura y alumno

    Raises:
    - HTTPException(403): Si el usuario no tiene permisos para ver la entrega
    - HTTPException(404): Si la entrega no existe
    """
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
    

from abc import ABC, abstractmethod

class EvaluadorIA(ABC):
    @abstractmethod
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        pass

    def extraer_nota(self, texto: str) -> float:
        """
        Extrae la nota de un texto que contiene una evaluación.
        Busca patrones como "Nota: n/10" o simplemente "n/10".
        
        Args:
            texto: El texto de la evaluación
            
        Returns:
            La nota extraída como un float, o 0.0 si no se puede extraer
        """
        try:
            # Primero intentamos el formato "Nota: n/10"
            if "Nota:" in texto or "Nota :" in texto:
                # Manejar ambos casos: "Nota:" y "Nota :"
                if "Nota:" in texto:
                    nota_texto = texto.split("Nota:")[1].split("/")[0]
                else:
                    nota_texto = texto.split("Nota :")[1].split("/")[0]
            else:
                # Si no encontramos "Nota:", buscamos cualquier patrón "n/10"
                import re
                # Buscar patrones como "8/10", "9.5/10", etc.
                patrones = re.findall(r'(\d+\.?\d*)\s*/\s*10', texto)
                if patrones:
                    nota_texto = patrones[0]  # Tomamos la primera coincidencia
                else:
                    return 0.0  # No se encontró ningún patrón válido
            
            # Limpiamos espacios y convertimos a float
            nota_texto = nota_texto.strip()
            return float(nota_texto)
        except (IndexError, ValueError) as e:
            print(f"Error al extraer nota: {e}")
            return 0.0

class GeminiEvaluador(EvaluadorIA):
    async def evaluar(self, prompt: str, actividad: Actividad, solucion: str) -> tuple[str, float]:
        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        nota = self.extraer_nota(response.text)
        return response.text, nota


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
            model = os.getenv("OLLAMA_MODEL", "gemma3:12b")
            
            # Hacer la petición a tu API
            response = requests.post(
                f"{api_url}/chat/{model}",
                json={
                    "model": model,  # Usar el modelo gemma3
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
            Qué valores son adecuados para un evaluador:
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

@router.put("/evaluar-texto/{entrega_id}", response_model=EntregaResponse)
async def evaluar_texto(
    entrega_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Evalúa automáticamente el texto de una entrega usando IA.
    Disponible para profesores y alumnos.

    Parameters:
    - entrega_id (int): ID de la entrega

    Returns:
    - EntregaResponse: Entrega actualizada con la evaluación

    Raises:
    - HTTPException(404): Si la entrega no existe
    - HTTPException(403): Si el usuario no tiene permisos
    - HTTPException(500): Si hay un error en la evaluación
    """
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
        # Crear el evaluador según la factory del evaluador_service
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


@router.get("/alumno/{alumno_id}/asignatura/{asignatura_id}", response_model=List[EntregaResponse])
async def obtener_entregas_alumno_asignatura(
    alumno_id: int,
    asignatura_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """
    Obtiene todas las entregas de un alumno en una asignatura específica.
    Los profesores pueden ver todas las entregas, los alumnos solo las suyas.

    Parameters:
    - alumno_id (int): ID del alumno
    - asignatura_id (int): ID de la asignatura

    Returns:
    - List[EntregaResponse]: Lista de entregas del alumno en la asignatura

    Raises:
    - HTTPException(403): Si el usuario no tiene permisos
    - HTTPException(404): Si no existen entregas
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
    El profesor de la asignatura y el alumno que realizó la entrega pueden descargar la imagen.

    Parameters:
    - entrega_id (int): ID de la entrega

    Returns:
    - Response: Imagen de la entrega como archivo descargable

    Raises:
    - HTTPException(404): Si la entrega o la imagen no existe
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
