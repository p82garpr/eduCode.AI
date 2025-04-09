from fastapi import FastAPI, UploadFile, File, HTTPException
from PIL import Image
import io
import torch
import base64
import requests
import json
from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
from qwen_vl_utils import process_vision_info
from pydantic import BaseModel
import logging
import os

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI()

# Cache para los modelos cargados
loaded_models = {}

# Configuración de los modelos OCR
OCR_CONFIG = {
    "qwen7b": {
        "model_name": "Qwen/Qwen2.5-VL-7B-Instruct",
        "type": "transformers",
        "processor": "process_qwen_response"
    },
    "qwen3b": {
        "model_name": "Qwen/Qwen2.5-VL-3B-Instruct",
        "type": "transformers",
        "processor": "process_qwen_response"
    },
    "gemma3:4b": {
        "url": "http://localhost:11434/api/generate",
        "type": "ollama",
        "processor": "process_ollama_response",
        "headers": {"Content-Type": "application/json"}
    }
}

def load_qwen_model(model_name: str):
    """Carga un modelo Qwen si no está ya cargado"""
    if model_name not in loaded_models:
        model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
            OCR_CONFIG[model_name]["model_name"], 
            torch_dtype="auto", 
            device_map="cuda:0"
        )
        processor = AutoProcessor.from_pretrained(
            OCR_CONFIG[model_name]["model_name"],
            min_pixels=256*28*28,
            max_pixels=1280*28*28
        )
        loaded_models[model_name] = {"model": model, "processor": processor}
    return loaded_models[model_name]

def process_qwen_response(image: Image.Image, model_name: str):
    """Procesa una imagen usando un modelo Qwen"""
    model_data = load_qwen_model(model_name)
    model = model_data["model"]
    processor = model_data["processor"]
    
    max_size = (640, 640)
    image = image.resize(max_size, Image.LANCZOS)
    
    messages = [
        {"role": "user", "content": [
            {"type": "image", "image": image},
            {"type": "text", "text": "transcript the text in the image. Preserve all formatting, indentation, and whitespace exactly as shown in the image. Do not add any explanations or markdown, only output the exact text with its original formatting."}
        ]}
    ]
    
    text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    image_inputs, video_inputs = process_vision_info(messages)
    inputs = processor(
        text=[text], images=image_inputs, videos=video_inputs,
        padding=True, return_tensors="pt"
    ).to("cuda")
    
    generated_ids = model.generate(**inputs, max_new_tokens=1024)  # Aumentado para manejar textos más largos
    generated_ids_trimmed = [out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)]
    output_text = processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True, clean_up_tokenization_spaces=False)
    
    return output_text[0]

def process_ollama_response(image: Image.Image, model_name: str):
    """Procesa una imagen usando Ollama"""
    try:
        # Convertir la imagen a base64
        buffered = io.BytesIO()
        image.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode()
        
        # Configurar la URL de Ollama
        ollama_url = os.getenv("OLLAMA_API_URL", "http://localhost:11434")
        
        payload = {
            "model": "gemma:4b",
            "prompt": "transcript the text in the image. Preserve all formatting, indentation, and whitespace exactly as shown in the image. Do not add any explanations or markdown, only output the exact text with its original formatting.",
            "stream": False,
            "options": {
                "temperature": 0.1,  # Temperatura baja para mantener la precisión
                "num_predict": 1024  # Aumentado para manejar textos más largos
            },
            "images": [img_str]
        }
        
        # Hacer la petición a Ollama
        response = requests.post(
            f"{ollama_url}/api/generate",
            headers={"Content-Type": "application/json"},
            json=payload
        )
        
        if response.status_code != 200:
            logger.error(f"Error de Ollama: Status {response.status_code}, Response: {response.text}")
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Error en la solicitud a Ollama: {response.text}"
            )
        
        response_data = response.json()
        return response_data.get("response", "")
        
    except requests.exceptions.ConnectionError as e:
        logger.error(f"Error de conexión con Ollama: {str(e)}")
        raise HTTPException(
            status_code=503,
            detail=f"No se pudo conectar al servicio Ollama: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error procesando con Ollama: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error al procesar con Ollama: {str(e)}"
        )

@app.get("/models")
def list_models():
    """Lista todos los modelos OCR disponibles"""
    return {
        "modelos": list(OCR_CONFIG.keys())
    }

@app.post("/predict/{model_name}")
async def predict(model_name: str, image: UploadFile = File(...)):
    """Endpoint principal para OCR que soporta múltiples modelos"""
    if model_name not in OCR_CONFIG:
        raise HTTPException(
            status_code=404,
            detail=f"Modelo '{model_name}' no encontrado. Modelos disponibles: {list(OCR_CONFIG.keys())}"
        )
    
    try:
        # Leer y convertir la imagen
        image_data = await image.read()
        image = Image.open(io.BytesIO(image_data)).convert("RGB")
        
        # Procesar según el tipo de modelo
        config = OCR_CONFIG[model_name]
        if config["type"] == "transformers":
            result = process_qwen_response(image, model_name)
        else:  # ollama
            result = process_ollama_response(image, model_name)
        
        return {"prediction": result}
    
    except Exception as e:
        logger.error(f"Error procesando imagen con {model_name}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error procesando imagen: {str(e)}")
