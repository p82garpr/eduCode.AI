from abc import ABC, abstractmethod
import os
import requests
import google.generativeai as genai
from models.actividad import Actividad
from enum import Enum
import re

class ModeloIA(str, Enum):
    GEMINI = "gemini"
    LLAMA = "llama" 
    GPT = "gpt"

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
            
            # Hacer la petición a la API
            payload = {
                "model": model,
                "prompt": prompt,
                "max_tokens": 4096,
                "temperature": 0.7,
                "top_p": 0.9,
                "top_k": 40
            }
            
            response = requests.post(
                f"{api_url}/chat/{model}",
                json=payload
            )
            
            response.raise_for_status()  # Lanzar excepción si hay error
            
            # Extraer la respuesta del formato
            response_data = response.json()
            if "response" in response_data:
                response_text = response_data["response"]
                nota = self.extraer_nota(response_text)
                return response_text, nota
            else:
                raise Exception("Formato de respuesta inesperado")
            
        except Exception as e:
            print(f"Error en Ollama API: {str(e)}")
            raise

class EvaluadorFactory:
    _evaluadores = {
        "gemini": GeminiEvaluador,
        "gpt": GPTEvaluador,
        "ollama": OllamaEvaluador,
        "llama": OllamaEvaluador  # Alias para facilitar el uso
    }

    @classmethod
    def crear_evaluador(cls) -> EvaluadorIA:
        modelo = os.getenv("MODEL_IA", "gemini").lower()
        print(f"Usando modelo: {modelo}")
        evaluador_class = cls._evaluadores.get(modelo, GeminiEvaluador)
        return evaluador_class()

def construir_prompt(actividad: Actividad, solucion: str) -> str:
    """
    Construye el prompt para la evaluación de una actividad.
    
    Args:
        actividad: La actividad a evaluar
        solucion: La solución proporcionada
        
    Returns:
        El prompt para enviar al modelo de IA
    """
    prompt = (
        f"Eres un evaluador de actividades, evalúa la siguiente solución y proporciona feedback "
        f"constructivo, pero muy breve y quiero que también me des la nota de la entrega en formato: "
        f"Nota: n/10. Es IMPRESCINDIBLE que incluyas exactamente este formato 'Nota: n/10' al final de tu respuesta "
        f"o el sistema no podrá leer la calificación. No uses Markdown, solo texto plano. La actividad es {actividad.titulo} el enunciado es el siguiente: "
        f"{actividad.descripcion}. La solución que se proporciona es: {solucion}. "
        f"Recuerda, sé estricto con la nota, no seas tan generoso si está mal, si hace algo que no se pide, o no se cumple el enunciado indicalo y disminuye la nota, pero si lo hace bien, no disminuyas la nota y ponle un 10, aunque haya algunos aspectos no muy relevantes a mejorar"
    )
    
    if actividad.lenguaje_programacion:
        prompt += f" La solución es un fragmento de código, debe estar en {actividad.lenguaje_programacion}. Cuando me des la corrección, nunca me des el código corregido, solo el feedback. Si el código no compila por errores graves, suspende la nota, si no compila por errores menores, disminuye la nota. (No tengas en cuenta que falten incluir bibliotecas, solo evalúa el código que se proporciona)"
    if actividad.parametros_evaluacion:
        prompt += f" Los criterios que tendrás en cuenta para evaluar la solución son: {actividad.parametros_evaluacion}, si no se cumple el enunciado y los criterios de evaluación indicalo y penaliza la nota"
    
    return prompt 