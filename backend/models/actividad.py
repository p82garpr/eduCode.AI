from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from datetime import datetime, UTC
from database import Base
from models.entrega import Entrega

class Actividad(Base):
    __tablename__ = "actividades"
    
    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(200), nullable=False)
    descripcion = Column(Text)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False)
    fecha_entrega = Column(DateTime(timezone=True), nullable=False)
    asignatura_id = Column(Integer, ForeignKey("asignaturas.id", ondelete="CASCADE"), nullable=False)
    lenguaje_programacion = Column(String(50), nullable=True)
    parametros_evaluacion = Column(Text, nullable=True)

    # Relaciones
    asignatura = relationship("Asignatura", back_populates="actividades")
    entregas = relationship("Entrega", back_populates="actividad", cascade="all, delete-orphan") 