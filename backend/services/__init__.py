"""
Módulo de servicios para la aplicación.
"""

# Exponer los servicios principales
from .password_service import PasswordService
from .ocr_service import OCRServiceFactory, limpiar_texto
from .evaluador_service import EvaluadorFactory, construir_prompt 