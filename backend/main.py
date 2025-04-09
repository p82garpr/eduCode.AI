from fastapi import FastAPI
from models.usuario import Base
from routers import usuario, auth, asignatura, inscripcion, actividad, entrega
from database import init_db
import asyncio
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Código que se ejecuta al iniciar
    await init_db()
    yield
    # Código que se ejecuta al cerrar (si es necesario)

app = FastAPI(lifespan=lifespan)

# Configurar CORS para permitir peticiones desde cualquier origen
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todos los orígenes
    allow_credentials=True,
    allow_methods=["*"],  # Permitir todos los métodos
    allow_headers=["*"],  # Permitir todos los headers
)

app.include_router(auth.router, prefix="/api/v1", tags=["auth"])
app.include_router(usuario.router, prefix="/api/v1", tags=["usuarios"])
app.include_router(asignatura.router, prefix="/api/v1/asignaturas", tags=["asignaturas"])
app.include_router(inscripcion.router, prefix="/api/v1/inscripciones", tags=["inscripciones"])
app.include_router(actividad.router, prefix="/api/v1/actividades", tags=["actividades"])
app.include_router(entrega.router, prefix="/api/v1/entregas", tags=["entregas"])

# Código para ejecutar el servidor con HTTPS si este archivo se ejecuta directamente
if __name__ == "__main__":
    # Comprobar si existen los certificados SSL
    if not os.path.exists("cert.pem") or not os.path.exists("key.pem"):
        print("No se encontraron certificados SSL. Por favor, genera los certificados primero.")
        print("Puedes generarlos ejecutando: python generate_cert.py")
        exit(1)
    
    # Iniciar servidor con HTTPS
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        ssl_keyfile="key.pem",
        ssl_certfile="cert.pem",
        reload=True  # Para desarrollo
    )
    
    # uvicorn main:app --host 0.0.0.0 --port 8000 --ssl-keyfile key.pem --ssl-certfile cert.pem --reload