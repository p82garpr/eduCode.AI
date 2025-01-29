from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Float, Text, func
from sqlalchemy.orm import relationship
from database import Base

class Entrega(Base):
    __tablename__ = "entregas"
    
    id = Column(Integer, primary_key=True, index=True)
    actividad_id = Column(Integer, ForeignKey("actividades.id", ondelete="CASCADE"), nullable=False)
    alumno_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    fecha_entrega = Column(DateTime, server_default=func.now())
    archivo_entrega = Column(String(255), nullable=False)
    calificacion = Column(Float, nullable=True)
    comentarios = Column(Text, nullable=True)

    # Relaciones
    actividad = relationship("Actividad", back_populates="entregas")
    alumno = relationship("Usuario", back_populates="entregas") 