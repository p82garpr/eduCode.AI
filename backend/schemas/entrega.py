from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from schemas.actividad import ActividadResponse
from schemas.usuario import UsuarioResponse

class EntregaBase(BaseModel):
    archivo_entrega: str

class EntregaCreate(EntregaBase):
    actividad_id: int

class EntregaUpdate(BaseModel):
    calificacion: float
    comentarios: str

class EntregaResponse(EntregaBase):
    id: int
    actividad_id: int
    alumno_id: int
    fecha_entrega: datetime
    calificacion: Optional[float] = None
    comentarios: Optional[str] = None
    #actividad: Optional[ActividadResponse] = None
    #alumno: Optional[UsuarioResponse] = None

    class Config:
        from_attributes = True 