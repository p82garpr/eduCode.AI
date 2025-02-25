from datetime import datetime
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from models.usuario import TipoUsuario

class UsuarioBase(BaseModel):
    email: EmailStr
    nombre: str
    apellidos: str
    tipo_usuario: TipoUsuario

class UsuarioCreate(UsuarioBase):
    password: str = Field(..., min_length=5, description="La contraseña debe tener al menos 5 caracteres")

class UsuarioResponse(UsuarioBase):
    id: int

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token : str
    token_type: str
    
class TokenData(BaseModel):
    email: str | None = None