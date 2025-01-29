from sqlalchemy import Column, Integer, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

class Asignatura(Base):
    __tablename__ = "asignaturas"
    
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(150), nullable=False)
    descripcion = Column(Text)
    profesor_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)

    # Solo mantenemos la relación con el profesor por ahora
    profesor = relationship("Usuario", back_populates="asignaturas")

    # Añadir a la clase Asignatura:
    inscripciones = relationship("Inscripcion", back_populates="asignatura", cascade="all, delete")
    actividades = relationship("Actividad", back_populates="asignatura", cascade="all, delete") 