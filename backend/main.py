from fastapi import FastAPI
from models.usuario import Base
from routers import usuario, auth, asignatura, inscripcion, actividad, entrega
from database import init_db
import asyncio
import socket
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import sys
import warnings
from typing import Dict, Any

def custom_exception_handler(loop: asyncio.AbstractEventLoop, context: Dict[str, Any]) -> None:
    # Extraer la excepción del contexto
    exception = context.get('exception')
    
    # Ignorar errores específicos de conexión
    if isinstance(exception, (ConnectionResetError, ConnectionAbortedError)):
        return
    if isinstance(exception, OSError) and exception.winerror in (10054, 10053, 10058):
        return
        
    # Para otros errores, usar el manejador predeterminado
    loop.default_exception_handler(context)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Configurar el manejador de excepciones al inicio
    if sys.platform == "win32":
        loop = asyncio.get_running_loop()
        loop.set_exception_handler(custom_exception_handler)
        
    # Inicializar la base de datos
    await init_db()
    yield

app = FastAPI(lifespan=lifespan) # Inicializa la base de datos

# Configurar CORS para permitir peticiones desde cualquier origen
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todos los orígenes
    allow_credentials=True, # Permitir credenciales
    allow_methods=["*"],  # Permitir todos los métodos
    allow_headers=["*"],  # Permitir todos los headers
)

app.include_router(auth.router, prefix="/api/v1", tags=["auth"])
app.include_router(usuario.router, prefix="/api/v1", tags=["usuarios"])
app.include_router(asignatura.router, prefix="/api/v1/asignaturas", tags=["asignaturas"])
app.include_router(inscripcion.router, prefix="/api/v1/inscripciones", tags=["inscripciones"])
app.include_router(actividad.router, prefix="/api/v1/actividades", tags=["actividades"])
app.include_router(entrega.router, prefix="/api/v1/entregas", tags=["entregas"])

# Configuración específica para Windows
if sys.platform == "win32":
    # Suprimir advertencias específicas
    warnings.filterwarnings("ignore", message=".*socket.shutdown.*")
    warnings.filterwarnings("ignore", message=".*SSL.*")
    
    # Configurar socket para mejor manejo de timeouts
    socket.setdefaulttimeout(30)

# Código para ejecutar el servidor con HTTPS
if __name__ == "__main__":
    # Comprobar si existen los certificados SSL
    if not os.path.exists("cert.pem") or not os.path.exists("key.pem"):
        print("No se encontraron certificados SSL. Por favor, genera los certificados primero.")
        print("Puedes generarlos ejecutando: python generate_cert.py")
        exit(1)
    
    # Configuración de SSL más robusta
    ssl_config = {
        "ssl_keyfile": "key.pem",
        "ssl_certfile": "cert.pem",
        "ssl_version": 2,  # TLS 1.2
        "backlog": 2048,
    }
    
    # Iniciar servidor con HTTPS
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        **ssl_config,
        l="info",
        timeout_keep_alive=30,
        timeout_graceful_shutdown=10,
        access_log=True,
        use_colors=True,
        proxy_headers=True,
        forwarded_allow_ips="*",
        workers=1  # Usar un solo worker para evitar problemas de concurrencia
    )
    
    # uvicorn main:app --host 0.0.0.0 --port 8000 --ssl-keyfile key.pem --ssl-certfile cert.pem --reload