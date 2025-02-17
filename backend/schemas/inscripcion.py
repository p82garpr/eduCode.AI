from pydantic import BaseModel
from datetime import datetime
from schemas.asignatura import AsignaturaResponse
from schemas.usuario import UsuarioResponse

class InscripcionBase(BaseModel):
    asignatura_id: int

class InscripcionCreate(InscripcionBase):
    codigo_acceso: str

class InscripcionResponse(InscripcionBase):
    id: int
    alumno_id: int
    fecha_inscripcion: datetime
    asignatura: AsignaturaResponse | None = None
    alumno: UsuarioResponse | None = None

    class Config:
        from_attributes = True 