from sqlalchemy import Column, Integer, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from database import Base

class Inscripcion(Base):
    __tablename__ = "inscripciones"
    
    id = Column(Integer, primary_key=True, index=True)
    alumno_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    asignatura_id = Column(Integer, ForeignKey("asignaturas.id", ondelete="CASCADE"), nullable=False)
    fecha_inscripcion = Column(DateTime, server_default=func.now())

    # Relaciones
    alumno = relationship("Usuario", back_populates="inscripciones")
    asignatura = relationship("Asignatura", back_populates="inscripciones") 