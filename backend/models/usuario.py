from sqlalchemy import Column, Integer, String, Enum
import enum
from database import Base
from sqlalchemy.orm import relationship
from models.entrega import Entrega

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