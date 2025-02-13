
from pydantic import BaseModel
from typing import List
from schemas.asignatura import AsignaturaResponse

class ProfileResponse(BaseModel):
    id: int
    nombre: str
    apellidos: str
    email: str
    tipo_usuario: str
    asignaturas_impartidas: List[AsignaturaResponse] = []
    asignaturas_inscritas: List[AsignaturaResponse] = []

    class Config:
        from_attributes = True
