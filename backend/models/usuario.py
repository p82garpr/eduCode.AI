from sqlalchemy import Column, Integer, String, Enum, ForeignKey, DateTime, Index
import enum
import datetime
from database import Base
from sqlalchemy.orm import relationship
from models.entrega import Entrega
from sqlalchemy.types import DateTime as SQLDateTime
from sqlalchemy.sql import func

class TipoUsuario(str, enum.Enum):
    PROFESOR = "Profesor"
    ALUMNO = "Alumno"

class Usuario(Base):
    __tablename__ = "usuarios"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    contrasena = Column(String)
    nombre = Column(String)
    apellidos = Column(String)
    tipo_usuario = Column(String)
    asignaturas = relationship("Asignatura", back_populates="profesor")
    inscripciones = relationship("Inscripcion", back_populates="alumno")
    entregas = relationship("Entrega", back_populates="alumno")
    reset_tokens = relationship("PasswordResetToken", back_populates="usuario", cascade="all, delete-orphan")

class PasswordResetToken(Base):
    """Clase para gestionar los tokens de restablecimiento de contraseña"""
    __tablename__ = "password_reset_tokens"
    
    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"))
    expira = Column(DateTime(timezone=True), index=True)
    utilizado = Column(DateTime(timezone=True), nullable=True)
    
    usuario = relationship("Usuario", back_populates="reset_tokens")