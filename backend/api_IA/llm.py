"""
conda activate venvOCR
export PYTHONPATH=/opt/data/p82garpr/venv_packages:$PYTHONPATH
python -m uvicorn apiLLM:app --host 0.0.0.0 --port 8001
"""

from typing import Union, Dict, Any, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import json
import requests
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="Multi-LLM API", description="API para interactuar con múltiples modelos LLM", debug=True)

# Modelos Pydantic para las solicitudes
class Item(BaseModel):
    model: str
    prompt: str
    max_tokens: int = 1024
    temperature: float = 0.7
    top_p: float = 0.9
    top_k: int = 40
    images: List[str] = []  # Lista de imágenes en base64

# Configuración de los diferentes modelos LLM
LLM_CONFIG = {
    "gemma3:4b": {
        "url": "http://localhost:11434/api/generate",
        "model_suffix": ":4b",
        "headers": {"Content-Type": "application/json"},
        "processor": "process_ollama_response"
    },
    "gemma3:12b": {
        "url": "http://localhost:11434/api/generate",
        "model_suffix": ":12b",
        "headers": {"Content-Type": "application/json"},
        "processor": "process_ollama_response"
    },
    "llama3": {
        "url": "http://localhost:11434/api/generate",
        "model_suffix": "",
        "headers": {"Content-Type": "application/json"},
        "processor": "process_ollama_response"
    },
    "deepseek-coder-v2:latest": {
        "url": "http://localhost:11434/api/generate",  # Cambiado a Ollama
        "model_suffix": "",
        "headers": {"Content-Type": "application/json"},
        "processor": "process_ollama_response"  # Cambiado al procesador de Ollama
    }
}

# Funciones para procesar las respuestas de diferentes tipos de LLM
def process_ollama_response(response: requests.Response) -> Dict[str, Any]:
    """Procesa la respuesta de los modelos de Ollama"""
    try:
        response_data = json.loads(response.text)
        return {"response": response_data.get("response", "No se encontró respuesta")}
    except json.JSONDecodeError:
        logger.warning(f"Error al decodificar JSON de Ollama: {response.text[:100]}...")
        return {"response": "Error al procesar la respuesta", "raw": response.text}

def process_deepseek_response(response: requests.Response) -> Dict[str, Any]:
    """Procesa la respuesta del modelo DeepSeek"""
    try:
        return response.json()
    except json.JSONDecodeError:
        logger.warning(f"Error al decodificar JSON de DeepSeek: {response.text[:100]}...")
        return {"response": "Error al procesar la respuesta", "raw": response.text}

# Función para preparar el payload según el tipo de modelo
def prepare_payload(llm_name: str, item: Item) -> Dict[str, Any]:
    """Prepara el payload según el tipo de modelo"""
    if "gemma3" in llm_name or llm_name == "llama3" or llm_name == "deepseek-coder-v2:latest":  # Añadido deepseek
        # Formato para Ollama
        # Usamos directamente el nombre del modelo de la configuración
        model_name = item.model
        # Solo añadimos el sufijo si no está ya incluido en el nombre del modelo
        if LLM_CONFIG[llm_name]["model_suffix"] and not model_name.endswith(LLM_CONFIG[llm_name]["model_suffix"]):
            model_name += LLM_CONFIG[llm_name]["model_suffix"]
            
        payload = {
            "model": model_name,
            "prompt": item.prompt,
            "stream": False,
            "options": {
                "temperature": item.temperature,
                "top_p": item.top_p,
                "top_k": item.top_k,
                "num_predict": item.max_tokens
            }
        }
        if item.images:  # Solo agregar si hay imágenes
            payload["images"] = item.images
        return payload
    else:
        # Si no hay configuración específica, usar un formato genérico
        return {
            "model": item.model,
            "prompt": item.prompt,
            "max_tokens": item.max_tokens,
            "temperature": item.temperature
        }

# Función para hacer la solicitud al LLM
def query_llm(llm_name: str, item: Item) -> Dict[str, Any]:
    """Realiza la consulta al modelo LLM especificado"""
    # Verificar si el modelo está configurado
    if llm_name not in LLM_CONFIG:
        raise HTTPException(status_code=404, detail=f"Modelo LLM '{llm_name}' no configurado")
    
    config = LLM_CONFIG[llm_name]
    url = config["url"]
    headers = config["headers"]
    
    # Preparar el payload
    payload = prepare_payload(llm_name, item)
    
    try:
        # Realizar la solicitud HTTP
        response = requests.post(
            url=url,
            headers=headers,
            data=json.dumps(payload),
            timeout=60  # 60 segundos de timeout
        )
        
        # Verificar si la solicitud fue exitosa
        if response.status_code != 200:
            logger.error(f"Error al consultar {llm_name}: {response.status_code} - {response.text}")
            return {
                "error": f"Error HTTP {response.status_code}",
                "detail": response.text
            }
        
        # Procesar la respuesta según el tipo de modelo
        processor_name = config["processor"]
        processor_func = globals()[processor_name]
        result = processor_func(response)
        
        return result
    
    except requests.exceptions.RequestException as e:
        logger.error(f"Error de conexión con {llm_name}: {str(e)}")
        return {"error": f"Error de conexión: {str(e)}"}
    except Exception as e:
        logger.error(f"Error inesperado al consultar {llm_name}: {str(e)}", exc_info=True)
        return {"error": f"Error inesperado: {str(e)}"}

# Ruta principal
@app.get("/")
def read_root():
    """Ruta principal que muestra información básica de la API"""
    return {
        "mensaje": "API Multi-LLM en funcionamiento",
        "modelos_disponibles": list(LLM_CONFIG.keys()),
        "endpoints": [
            {"ruta": "/chat/{llm_name}", "método": "POST", "descripción": "Consultar un modelo LLM específico"},
            {"ruta": "/models", "método": "GET", "descripción": "Listar todos los modelos disponibles"}
        ]
    }

# Ruta para listar modelos disponibles
@app.get("/models")
def list_models():
    """Lista todos los modelos LLM disponibles"""
    return {
        "modelos": [
            {
                "nombre": name,
                "url": config["url"],
                "requiere_sufijo": bool(config["model_suffix"])
            }
            for name, config in LLM_CONFIG.items()
        ]
    }

# Ruta para consultar un modelo específico
@app.post("/chat/{llm_name}")
def chat_with_llm(llm_name: str, item: Item):
    """Consulta un modelo LLM específico"""
    # Verificar si el modelo está en la configuración
    if llm_name not in LLM_CONFIG:
        models = list(LLM_CONFIG.keys())
        raise HTTPException(
            status_code=404, 
            detail=f"Modelo '{llm_name}' no encontrado. Modelos disponibles: {models}"
        )
    
    # Realizar la consulta
    result = query_llm(llm_name, item)
    
    # Verificar si hubo un error
    if "error" in result:
        raise HTTPException(status_code=500, detail=result)
    
    return result

# Para ejecutar directamente con uvicorn
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("apiLLM:app", host="0.0.0.0", port=8001, reload=True)


