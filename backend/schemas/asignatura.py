from pydantic import BaseModel
from typing import Optional, List
from schemas.usuario import UsuarioResponse

class AsignaturaBase(BaseModel):
    nombre: str
    descripcion: Optional[str] = None

class AsignaturaCreate(AsignaturaBase):
    pass

class AsignaturaResponse(AsignaturaBase):
    id: int
    profesor_id: int
    profesor: Optional[UsuarioResponse] = None

    class Config:
        from_attributes = True 