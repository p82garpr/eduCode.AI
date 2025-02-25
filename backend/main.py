from fastapi import FastAPI
from models.usuario import Base
from routers import usuario, auth, asignatura, inscripcion, actividad, entrega
from database import init_db
import asyncio
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Código que se ejecuta al iniciar
    await init_db()
    yield
    # Código que se ejecuta al cerrar (si es necesario)

app = FastAPI(lifespan=lifespan)

app.include_router(auth.router, prefix="/api/v1", tags=["auth"])
app.include_router(usuario.router, prefix="/api/v1", tags=["usuarios"])
app.include_router(asignatura.router, prefix="/api/v1/asignaturas", tags=["asignaturas"])
app.include_router(inscripcion.router, prefix="/api/v1/inscripciones", tags=["inscripciones"])
app.include_router(actividad.router, prefix="/api/v1/actividades", tags=["actividades"])
app.include_router(entrega.router, prefix="/api/v1/entregas", tags=["entregas"])