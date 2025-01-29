from datetime import datetime
from pydantic import BaseModel, EmailStr
from typing import Optional
from models.usuario import TipoUsuario

class UsuarioBase(BaseModel):
    email: EmailStr
    nombre: str
    apellidos: str
    tipo_usuario: TipoUsuario

class UsuarioCreate(UsuarioBase):
    password: str

class UsuarioResponse(UsuarioBase):
    id: int

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token : str
    token_type: str
    
class TokenData(BaseModel):
    email: str | None = None