from pydantic import BaseModel, field_validator, ConfigDict
from datetime import datetime, UTC
from typing import Optional
from schemas.asignatura import AsignaturaResponse

class ActividadBase(BaseModel):
    titulo: str
    descripcion: Optional[str] = None
    fecha_entrega: datetime

    @field_validator('fecha_entrega')
    @classmethod
    def ensure_utc_timezone(cls, v):
        # Si la fecha no tiene zona horaria, asumimos UTC
        if v.tzinfo is None:
            v = v.replace(tzinfo=UTC)
        return v.astimezone(UTC)

class ActividadCreate(ActividadBase):
    asignatura_id: int
    lenguaje_programacion: Optional[str] = None
    parametros_evaluacion: Optional[str] = None

    @field_validator('fecha_entrega')
    @classmethod
    def validate_fecha_futura(cls, v):
        # Asegurarse de que la fecha tenga zona horaria UTC
        if v.tzinfo is None:
            v = v.replace(tzinfo=UTC)
        v = v.astimezone(UTC)
        # Validar que la fecha sea futura
        if v <= datetime.now(UTC):
            raise ValueError("La fecha de entrega debe ser futura")
        return v

class ActividadResponse(ActividadBase):
    id: int
    fecha_creacion: datetime
    asignatura_id: int
    lenguaje_programacion: Optional[str] = None
    parametros_evaluacion: Optional[str] = None
    #asignatura: Optional[AsignaturaResponse] = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator('fecha_creacion', 'fecha_entrega')
    @classmethod
    def ensure_utc_timezone_response(cls, v):
        if v.tzinfo is None:
            v = v.replace(tzinfo=UTC)
        return v.astimezone(UTC)

class ActividadUpdate(BaseModel):
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_entrega: Optional[datetime] = None
    lenguaje_programacion: Optional[str] = None
    parametros_evaluacion: Optional[str] = None

    @field_validator('fecha_entrega')
    @classmethod
    def validate_fecha_futura(cls, v):
        if v is not None:
            # Asegurarse de que la fecha tenga zona horaria UTC
            if v.tzinfo is None:
                v = v.replace(tzinfo=UTC)
            v = v.astimezone(UTC)
            # Validar que la fecha sea futura
            if v <= datetime.now(UTC):
                raise ValueError("La fecha de entrega debe ser futura")
            return v
        return v 