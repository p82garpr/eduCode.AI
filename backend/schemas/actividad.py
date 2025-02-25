from pydantic import BaseModel, field_validator, ConfigDict
from datetime import datetime
from typing import Optional
from schemas.asignatura import AsignaturaResponse

class ActividadBase(BaseModel):
    titulo: str
    descripcion: Optional[str] = None
    fecha_entrega: datetime

    @field_validator('fecha_entrega')
    @classmethod
    def ensure_naive_datetime(cls, v):
        if v.tzinfo is not None:
            v = v.astimezone().replace(tzinfo=None)
        return v

class ActividadCreate(ActividadBase):
    asignatura_id: int
    lenguaje_programacion: Optional[str] = None
    parametros_evaluacion: Optional[str] = None

class ActividadResponse(ActividadBase):
    id: int
    fecha_creacion: datetime
    asignatura_id: int
    lenguaje_programacion: Optional[str] = None
    parametros_evaluacion: Optional[str] = None
    #asignatura: Optional[AsignaturaResponse] = None

    model_config = ConfigDict(from_attributes=True)

class ActividadUpdate(BaseModel):
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_entrega: Optional[datetime] = None
    lenguaje_programacion: Optional[str] = None
    parametros_evaluacion: Optional[str] = None

    @field_validator('fecha_entrega')
    @classmethod
    def ensure_naive_datetime(cls, v):
        if v and v.tzinfo is not None:
            v = v.astimezone().replace(tzinfo=None)
        return v 