# eduCode.AI

## ¿Qué es eduCode.AI?

Este Trabajo de Fin de Grado tiene como objetivo el desarrollo de una aplicación móvil denominada EduCode, cuyo propósito es aplicar inteligencia artificial en el ámbito educativo para facilitar el trabajo del profesorado y mejorar la experiencia del alumnado.

 El proyecto combina el diseño de una aplicación móvil con la integración de técnicas
de visión artificial. En particular, se implementa un sistema en dos etapas: una primera de reconocimiento óptico de caracteres (OCR) para digitalizar ejercicios escritos, y una segunda basada en modelos de lenguaje para corregir automáticamente las respuestas.

Se han evaluado distintos modelos de OCR y LLM (Large Language Models), selecccionando los más adecuados según criterios de precisión y eficiencia. Asimismo, el sistema ha sido desarrollado con una arquitectura escalable, haciendo uso de buenas prácticas de programación.

EduCode busca contribuir a la modernización del entorno educativo, automatizando procesos repetitivos y demostrando el potencial de la inteligencia artificial como herramienta de apoyo al aprendizaje y la docencia.

## Características Principales

### 🎓 Para Profesores

- **Gestión de Asignaturas**: Cree y administre sus cursos de programación de manera sencilla
- **Evaluación Automatizada**: Las entregas de los estudiantes son evaluadas automáticamente por IA en base a los criterios
- **Seguimiento del Progreso**: Visualice el avance de sus estudiantes en tiempo real
- **Exportación de Calificaciones**: Descargue informes detallados en formato CSV

### 👨‍💻 Para Estudiantes

- **Entrega de Ejercicios**: Suba sus soluciones en imagenes y reciba retroalimentación instantánea
- **Retroalimentación Detallada**: Reciba sugerencias específicas para mejorar su código
- **Seguimiento Personal**: Visualice su progreso y áreas de mejora

### 🤖 Tecnología Inteligente

El sistema utiliza múltiples modelos de IA para:
- Reconocimiento de código en imágenes
- Evaluación automática de ejercicios
- Generación de retroalimentación personalizada
- Detección de errores y sugerencias de mejora

## Seguridad y Respaldos

El sistema cuenta con un robusto sistema de copias de seguridad que garantiza la protección de todos los datos y el trabajo realizado en la plataforma.

## Configuración del Sistema

Para el correcto funcionamiento del sistema, se requieren las siguientes variables de entorno:

- `OCR_SERVICE`: Define el servicio OCR a utilizar (valores: "qwen7b", "qwen3b", "gemma3", "azure")
- `MODEL_IA`: Define el modelo de IA para evaluación (valores: "gemini", "gpt", "ollama")
- `GEMINI_API_KEY`: Clave API para Google Gemini
- `AZURE_API_KEY`: Clave API para Azure Computer Vision
- `OLLAMA_API_URL`: URL para el servidor Ollama
- `OLLAMA_MODEL`: Modelo a utilizar con Ollama en caso de que asi se detalle en MODEL_IA. ("gemma3:12b" y "deepseek-coder-v2:latest")

Consulta `.env.example` para ver todas las variables disponibles y los manuales de código del TFG para desplegar la aplicación. 