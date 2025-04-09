# Backend de eduCode.AI

## Estructura del Proyecto

El backend está organizado en una estructura modular:

- `routers/`: Contiene los endpoints de la API REST
- `models/`: Define los modelos de la base de datos
- `schemas/`: Define los esquemas de Pydantic para validación
- `services/`: Implementa la lógica de negocio
- `providers/`: Implementa integraciones con servicios externos
- `backups/`: Scripts para realizar y gestionar copias de seguridad

## Servicios

### Servicios de OCR

El sistema soporta múltiples proveedores de OCR (Reconocimiento Óptico de Caracteres):

- **AzureOCRService**: Utiliza Azure Computer Vision para OCR.
- **QWEN3BOCRService**: Utiliza el modelo QWEN3B de la UCO.
- **OllamaGemma3OCRService**: Utiliza el modelo llava a través de Ollama.

Estos servicios se encuentran en `services/ocr_service.py` y siguen el patrón Factory para 
permitir seleccionar dinámicamente el servicio a utilizar.

### Servicios de Evaluación

El sistema implementa varios modelos de IA para evaluar las entregas:

- **GeminiEvaluador**: Utiliza el modelo Gemini de Google para evaluación.
- **GPTEvaluador**: Utiliza OpenAI GPT para evaluación.
- **OllamaEvaluador**: Utiliza modelos locales a través de Ollama para evaluación.

Estos servicios se encuentran en `services/evaluador_service.py` y siguen el patrón Factory.

## Sistema de Backups

El sistema incluye un mecanismo robusto para realizar copias de seguridad de la base de datos:

- `backup.py`: Script principal para crear, listar y restaurar respaldos.
- `cron.py`: Programador para automatizar respaldos diarios y semanales.

Las copias de seguridad se pueden ejecutar manualmente o programarse para ejecutarse automáticamente.

## Variables de Entorno

El sistema utiliza las siguientes variables de entorno:

- `OCR_SERVICE`: Define el servicio OCR a utilizar (valores: "azure", "qwen3b", "llava")
- `MODEL_IA`: Define el modelo de IA para evaluación (valores: "gemini", "gpt", "ollama")
- `GEMINI_API_KEY`: Clave API para Google Gemini
- `AZURE_API_KEY`: Clave API para Azure Computer Vision
- `OLLAMA_API_URL`: URL para el servidor Ollama
- `OLLAMA_MODEL`: Modelo a utilizar con Ollama

Consulta `.env.example` para ver todas las variables disponibles. 