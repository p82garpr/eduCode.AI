from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from schemas.actividad import ActividadResponse
from schemas.usuario import UsuarioResponse
from fastapi import UploadFile

class EntregaBase(BaseModel):
    comentarios: Optional[str] = None
    calificacion: Optional[float] = None
    texto_ocr: Optional[str] = None

class EntregaCreate(EntregaBase):
    pass

class EntregaUpdate(BaseModel):
    calificacion: float
    comentarios: str

class EntregaResponse(EntregaBase):
    id: int
    fecha_entrega: datetime
    calificacion: Optional[float] = None
    actividad_id: int
    alumno_id: int
    nombre_archivo: Optional[str] = None
    tipo_imagen: Optional[str] = None
    texto_ocr: Optional[str] = None
    #actividad: Optional[ActividadResponse] = None
    #alumno: Optional[UsuarioResponse] = None

    class Config:
        from_attributes = True 