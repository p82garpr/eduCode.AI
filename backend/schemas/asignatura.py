from pydantic import BaseModel
from typing import Optional, List
from schemas.usuario import UsuarioResponse

class AsignaturaBase(BaseModel):
    nombre: str
    descripcion: Optional[str] = None
    codigo_acceso: str

class AsignaturaCreate(AsignaturaBase):
    codigo_acceso: str

class AsignaturaResponse(AsignaturaBase):
    id: int
    profesor_id: int
    profesor: Optional[UsuarioResponse] = None
    

    class Config:
        from_attributes = True 
        
class AsignaturaInscripcionRequest(BaseModel):
    codigo_acceso: str 