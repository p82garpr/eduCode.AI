from fastapi import HTTPException, UploadFile, status
from abc import ABC, abstractmethod
from typing import Optional
import requests
import asyncio
import base64
import os
import io
from models.usuario import Usuario, TipoUsuario

class OCRService(ABC):
    @abstractmethod
    async def process_image(self, image: UploadFile, current_user: Usuario) -> str:
        """Procesa una imagen y retorna el texto extraído"""
        pass

# Implementación del OCR de la UCO
class AzureOCRService(OCRService):
    async def process_image(self, image: UploadFile, current_user: Usuario) -> str:
        # Comprobar que el usuario está logueado
        if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para procesar imágenes OCR"
            )
        
        # Configurar los headers de Azure
        headers = {
            'Content-Type': 'application/octet-stream',
            'Ocp-Apim-Subscription-Key': os.getenv("AZURE_API_KEY", "9TnsLp0OUYoyH25UP7V5n3mb2tSnm54J4WySPu0IKZwEJNY4RnJ7JQQJ99ALAC5RqLJXJ3w3AAAFACOGHcqc")
        }
        
        try:
            # Enviar la imagen como datos binarios
            response = requests.post(
                os.getenv("AZURE_VISION_ENDPOINT", "https://pruebarafagvision.cognitiveservices.azure.com/vision/v3.2/read/analyze"),
                headers=headers,
                data=await image.read()  # Enviar los bytes directamente
            )
            
            response.raise_for_status()  # Lanzar excepción si hay error
            
            # Obtener la URL de operación del header
            operation_url = response.headers["Operation-Location"]
            
            # Esperar a que el análisis termine
            analysis_result = None
            while True:
                result_response = requests.get(
                    operation_url,
                    headers={'Ocp-Apim-Subscription-Key': os.getenv("AZURE_API_KEY", "9TnsLp0OUYoyH25UP7V5n3mb2tSnm54J4WySPu0IKZwEJNY4RnJ7JQQJ99ALAC5RqLJXJ3w3AAAFACOGHcqc")}
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
        
# Implementación del OCR de Ollama
class OllamaGemma3OCRService(OCRService):
    async def process_image(self, image: UploadFile, current_user: Usuario) -> str:
        try:
            # Comprobar que el usuario está logueado
            if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="No tienes permiso para procesar imágenes OCR"
                )
                
            # Configurar la URL de la API OCR
            api_url = os.getenv("OCR_API_URL", "http://localhost:8000")
            
            # Preparar el archivo para enviarlo
            files = {"image": (image.filename, await image.read(), image.content_type)}
            
            # Hacer la petición a la API OCR
            response = requests.post(
                f"{api_url}/predict/gemma3:4b",
                files=files
            )
            
            if response.status_code == 404:
                raise HTTPException(
                    status_code=404,
                    detail="Servicio OCR no encontrado. Verifica que la API OCR esté funcionando correctamente."
                )
            
            response.raise_for_status()
            
            # Extraer la respuesta
            response_data = response.json()
            return response_data.get("prediction", "")
            
        except requests.exceptions.ConnectionError:
            error_msg = f"No se pudo conectar al servicio OCR en {api_url}. Verifica que el servicio esté activo."
           
            raise HTTPException(status_code=503, detail=error_msg)
        except Exception as e:
            error_msg = f"Error en Ollama OCR API: {str(e)}"
           
            raise HTTPException(status_code=500, detail=error_msg)

class QWEN3BOCRService(OCRService):
    async def process_image(self, image: UploadFile, current_user: Usuario) -> str:
        try:
            # Comprobar que el usuario está logueado
            if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="No tienes permiso para procesar imágenes OCR"
                )
                
            # Configurar la URL de la API OCR
            api_url = os.getenv("OCR_API_URL", "http://localhost:8000")
            
            # Preparar el archivo para enviarlo
            files = {"image": (image.filename, await image.read(), image.content_type)}
            
            # Hacer la petición a la API OCR
            response = requests.post(
                f"{api_url}/predict/qwen3b",
                files=files
            )
            
            if response.status_code == 404:
                raise HTTPException(
                    status_code=404,
                    detail="Servicio OCR no encontrado. Verifica que la API OCR esté funcionando correctamente."
                )
            
            response.raise_for_status()
            
            # Extraer la respuesta
            response_data = response.json()
            return response_data.get("prediction", "")
            
        except requests.exceptions.ConnectionError:
            error_msg = f"No se pudo conectar al servicio OCR en {api_url}. Verifica que el servicio esté activo."
            
            raise HTTPException(status_code=503, detail=error_msg)
        except Exception as e:
            error_msg = f"Error en QWEN3B OCR API: {str(e)}"
            
            raise HTTPException(status_code=500, detail=error_msg)

class QWEN7BOCRService(OCRService):
    async def process_image(self, image: UploadFile, current_user: Usuario) -> str:
        try:
            # Comprobar que el usuario está logueado
            if current_user.tipo_usuario != TipoUsuario.PROFESOR and current_user.tipo_usuario != TipoUsuario.ALUMNO:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="No tienes permiso para procesar imágenes OCR"
                )
                
            # Configurar la URL de la API OCR
            api_url = os.getenv("OCR_API_URL", "http://localhost:8000")
            
            # Preparar el archivo para enviarlo
            files = {"image": (image.filename, await image.read(), image.content_type)}
            
            # Hacer la petición a la API OCR
            response = requests.post(
                f"{api_url}/predict/qwen7b",
                files=files
            )
            
            if response.status_code == 404:
                raise HTTPException(
                    status_code=404,
                    detail="Servicio OCR no encontrado. Verifica que la API OCR esté funcionando correctamente."
                )
            
            response.raise_for_status()
            
            # Extraer la respuesta
            response_data = response.json()
            return response_data.get("prediction", "")
            
        except requests.exceptions.ConnectionError:
            error_msg = f"No se pudo conectar al servicio OCR en {api_url}. Verifica que el servicio esté activo."
            
            raise HTTPException(status_code=503, detail=error_msg)
        except Exception as e:
            error_msg = f"Error en QWEN7B OCR API: {str(e)}"
            
            raise HTTPException(status_code=500, detail=error_msg)

# Factory para crear servicios OCR
class OCRServiceFactory:
    _services = {
        "azure": AzureOCRService,
        "qwen3b": QWEN3BOCRService,
        "qwen7b": QWEN7BOCRService,
        "gemma3": OllamaGemma3OCRService,
        
    }
    
    @classmethod
    def get_ocr_service(cls) -> OCRService:
        # Obtener el servicio OCR configurado en las variables de entorno
        # Por defecto, usar el servicio de la UCO
        ocr_service = os.getenv("OCR_SERVICE", "qwen7b").lower()
        
        # Obtener la clase de servicio
        service_class = cls._services.get(ocr_service)
        if not service_class:
            # Si no se encuentra el servicio, usar el servicio de la UCO por defecto
            print(f"Servicio OCR '{ocr_service}' no encontrado, usando QWEN7B por defecto")
            service_class = QWEN7BOCRService
            
        # Instanciar y retornar el servicio
        return service_class()
    
def limpiar_texto(texto: str) -> str:
    """
    Elimina caracteres nulos y otros caracteres problemáticos del texto extraído por OCR
    para evitar problemas al guardar en la base de datos.
    
    Args:
        texto: El texto a limpiar
        
    Returns:
        El texto limpio
    """
    if not texto:
        return ""
    
    # Eliminar caracteres nulos
    texto_limpio = texto.replace('\x00', '')
    
    # Aquí se pueden agregar más reglas de limpieza si es necesario
    
    return texto_limpio 