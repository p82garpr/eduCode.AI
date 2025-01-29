from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from database import Base
from models.entrega import Entrega

class Actividad(Base):
    __tablename__ = "actividades"
    
    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(200), nullable=False)
    descripcion = Column(Text)
    fecha_creacion = Column(DateTime, server_default=func.now())
    fecha_entrega = Column(DateTime, nullable=False)
    asignatura_id = Column(Integer, ForeignKey("asignaturas.id", ondelete="CASCADE"), nullable=False)

    # Relaciones
    asignatura = relationship("Asignatura", back_populates="actividades")
    entregas = relationship("Entrega", back_populates="actividad", cascade="all, delete") 