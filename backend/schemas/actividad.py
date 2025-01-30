from pydantic import BaseModel, validator
from datetime import datetime
from typing import Optional
from schemas.asignatura import AsignaturaResponse

class ActividadBase(BaseModel):
    titulo: str
    descripcion: Optional[str] = None
    fecha_entrega: datetime

    @validator('fecha_entrega')
    def ensure_naive_datetime(cls, v):
        if v.tzinfo is not None:
            # Convertir a UTC y luego quitar la información de zona horaria
            v = v.astimezone().replace(tzinfo=None)
        return v

class ActividadCreate(ActividadBase):
    asignatura_id: int

class ActividadResponse(ActividadBase):
    id: int
    fecha_creacion: datetime
    asignatura_id: int
    asignatura: Optional[AsignaturaResponse] = None

    class Config:
        from_attributes = True

class ActividadUpdate(BaseModel):
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_entrega: Optional[datetime] = None

    @validator('fecha_entrega')
    def ensure_naive_datetime(cls, v):
        if v and v.tzinfo is not None:
            v = v.astimezone().replace(tzinfo=None)
        return v 